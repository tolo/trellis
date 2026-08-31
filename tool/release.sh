#!/usr/bin/env bash
#
# Prepare a Trellis SDK release on main: lockstep bump, local gate, release
# commit, local tag — then STOP and print the one push command. Nothing is
# pushed from here; pushing the tag is the single deliberate human action that
# publishes (pub.dev cannot unpublish). See dev/guidelines/RELEASE-RUNBOOK.md.
#
set -euo pipefail

usage() {
  cat <<'EOF'
Prepare a Trellis SDK lockstep release (ADR-009) — everything up to the push.

Usage:
  tool/release.sh <version> [--dry-run]
  tool/release.sh --help

Preconditions (each checked; the script refuses otherwise):
  * on main, working tree clean, HEAD == origin/main (squash-merge first, push,
    let CI run — melos refuses to version off main anyway)
  * CI (ci.yml) is green for HEAD — waits if it is still running
  * every packages/*/CHANGELOG.md has a `## <version>` section
  * <version> is X.Y.Z (the tag pattern the release workflows trigger on)

Then:
  1. tool/version_lockstep.sh <version>   (pubspecs, constraints, version.dart, READMEs,
                                           site/trellis_site.yaml)
  2. asserts only those files changed
  3. local gate = ci.yml's check tier: melos analyze + format:check + unit
     tests, root tests + root format
  4. commit `chore(release): trellis SDK <version>`, then `dart pub publish
     --dry-run` per package (a dirty tree would warn; the commit is undone if
     the dry-run fails), then tag `v<version>` (local)
  5. prints `git push --atomic origin main v<version>` — run it yourself, once CI on the
     release commit is what you want to ship (the tag workflows wait for it and
     refuse if it is red: release-gate.yml)

Re-runnable: if the release commit and/or tag already exist for <version> it
reports that and prints the push command again instead of bumping twice.

--dry-run  runs every check and the bump + gate, makes the release commit so the
           publish dry-run sees a clean tree, prints it, then unwinds the commit
           and restores the working tree; nothing tagged, nothing left behind.

Environment: CI_WORKFLOW / CI_GATE_* pass through to tool/require_green_ci.sh.
EOF
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  '')
    usage >&2
    exit 1
    ;;
esac

VERSION="$1"
shift
DRY_RUN=0
for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=1 ;;
    *)
      echo "release: unknown argument '${arg}'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

fail() {
  echo "release: $*" >&2
  exit 1
}
step() { echo; echo "==> $*"; }

[[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || fail "version '${VERSION}' is not X.Y.Z — publish.yml/release-binaries.yml only trigger on v[0-9]+.[0-9]+.[0-9]+ tags"

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "${ROOT}"

TAG="v${VERSION}"
MSG="chore(release): trellis SDK ${VERSION}"
RELEASE_BRANCH=main
# Keep in sync with tool/version_lockstep.sh PACKAGES.
PACKAGES=(trellis trellis_shelf trellis_dev trellis_cli trellis_css trellis_site trellis_dart_frog trellis_relic)

print_push() {
  cat <<EOF

Release ${VERSION} is prepared locally: commit $(git rev-parse --short HEAD) "${MSG}", tag ${TAG}. Nothing has been pushed.

  Review:   git show --stat HEAD
  Publish:  git push --atomic origin ${RELEASE_BRANCH} ${TAG}

Pushing the tag publishes to pub.dev (irreversible: no unpublish, only a 7-day retract on pub.dev's Admin tab)
and cuts the GitHub Release + Homebrew/Scoop updates. --atomic: if main was pushed by someone else meanwhile, the
tag is rejected too, instead of landing on a commit that is not on origin/main. The tag workflows wait for CI on
that commit and refuse if it is red — watch with: gh run watch
EOF
}

head_subject() { git log -1 --pretty=%s; }
pubspec_version() { sed -n 's/^version:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "packages/$1/pubspec.yaml"; }

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ "${CURRENT_BRANCH}" == "${RELEASE_BRANCH}" ]] \
  || fail "on '${CURRENT_BRANCH}', releases are cut on ${RELEASE_BRANCH} (squash-merge there first; melos version is restricted to ${RELEASE_BRANCH})"

# --- Re-run states -----------------------------------------------------------
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  TAG_SHA="$(git rev-list -n1 "${TAG}")"
  if [[ "${TAG_SHA}" == "$(git rev-parse HEAD)" && "$(head_subject)" == "${MSG}" ]]; then
    echo "release: ${TAG} already exists at HEAD (release commit present)."
    print_push
    exit 0
  fi
  fail "tag ${TAG} already exists at ${TAG_SHA} but HEAD is $(git rev-parse HEAD) ('$(head_subject)'). Inspect before continuing; delete the local tag only if you are sure it was never pushed (git tag -d ${TAG})."
fi

if [[ "$(head_subject)" == "${MSG}" ]]; then
  [[ -z "$(git status --porcelain)" ]] || fail "HEAD is the release commit but the tree is dirty — commit or discard first."
  for pkg in "${PACKAGES[@]}"; do
    [[ "$(pubspec_version "${pkg}")" == "${VERSION}" ]] || fail "HEAD is titled '${MSG}' but ${pkg} is at $(pubspec_version "${pkg}")."
  done
  if (( DRY_RUN )); then
    echo "release (dry-run): release commit already at HEAD; would tag ${TAG}."
    exit 0
  fi
  step "Release commit already at HEAD; tagging ${TAG}"
  git tag "${TAG}"
  print_push
  exit 0
fi

# --- Preconditions -----------------------------------------------------------
step "Checking preconditions"
[[ -z "$(git status --porcelain)" ]] \
  || fail "working tree is not clean (git status). Commit, stash, or discard first — the bump must be the only change in the release commit."

git fetch --quiet origin "${RELEASE_BRANCH}"
LOCAL_SHA="$(git rev-parse HEAD)"
REMOTE_SHA="$(git rev-parse "origin/${RELEASE_BRANCH}")"
if [[ "${LOCAL_SHA}" != "${REMOTE_SHA}" ]]; then
  if git merge-base --is-ancestor "${REMOTE_SHA}" "${LOCAL_SHA}"; then
    fail "local ${RELEASE_BRANCH} is ahead of origin/${RELEASE_BRANCH}. Push it first and let CI run — the release commit must sit on a commit CI has seen."
  else
    fail "local ${RELEASE_BRANCH} is behind (or diverged from) origin/${RELEASE_BRANCH}. Pull first."
  fi
fi

for pkg in "${PACKAGES[@]}"; do
  [[ "$(pubspec_version "${pkg}")" != "${VERSION}" ]] \
    || fail "${pkg} is already at ${VERSION} but HEAD is not the release commit — inspect before continuing."
done

MISSING=()
for pkg in "${PACKAGES[@]}"; do
  grep -q "^## ${VERSION}\$" "packages/${pkg}/CHANGELOG.md" || MISSING+=("${pkg}")
done
(( ${#MISSING[@]} == 0 )) \
  || fail "no '## ${VERSION}' section in CHANGELOG.md of: ${MISSING[*]}. Changelogs are hand-written on the feature branch before merging (unchanged packages get the lockstep-alignment note)."

for tool_bin in gh melos; do
  command -v "${tool_bin}" >/dev/null 2>&1 || fail "'${tool_bin}' not on PATH (melos: dart pub global activate melos; gh: brew install gh && gh auth login)"
done
gh auth status >/dev/null 2>&1 || fail "gh is not authenticated (gh auth login) — needed to check CI for HEAD"

step "Requiring green CI for ${LOCAL_SHA} (origin/${RELEASE_BRANCH})"
tool/require_green_ci.sh "${LOCAL_SHA}"

# --- Bump --------------------------------------------------------------------
step "Lockstep bump to ${VERSION}"
tool/version_lockstep.sh "${VERSION}"
dart pub get

step "Asserting only version files changed"
# The bump may touch exactly these; anything else means the script or melos did
# something new and a human should look before it becomes the release commit.
#
# Read `--porcelain -z`, not `--porcelain` split on whitespace. Two reasons, both
# demonstrated against real `git status` output rather than reasoned about:
#   * `--porcelain` C-quotes any path with a space or a non-ASCII byte, so
#     `awk '{print $NF}'` handed the allow-list `README.md"` for `Project
#     README.md` — a name no case pattern matches and no maintainer can act on.
#     It failed safe, but it failed on a path that does not exist.
#   * a rename is `R  <orig> -> <new>`, so `$NF` was the destination only: a file
#     renamed *into* an allow-listed path (`R "anything" -> packages/x/pubspec.yaml`)
#     passed with nothing reported. That is the permissive hole, and it is the one
#     that matters for an assertion guarding an irreversible publish.
# `-z` emits raw NUL-delimited paths with no quoting, and splits a rename or copy
# into `XY <new>` followed by the bare source — so the source is read back and held
# to the same allow-list.
UNEXPECTED=()
EXPECTED_CHANGED=()
PENDING_SOURCE=0
while IFS= read -r -d '' entry; do
  if (( PENDING_SOURCE )); then
    PENDING_SOURCE=0
    UNEXPECTED+=("${entry} (rename/copy source)")
    continue
  else
    case "${entry:0:2}" in *[RC]*) PENDING_SOURCE=1 ;; esac
    changed="${entry:3}"
  fi
  # A lockstep bump only modifies existing tracked files. A deletion, addition,
  # rename or copy of an allow-listed path is still an unexpected release change.
  case "${entry:0:2}" in
    " M" | "M ") ;;
    *)
      UNEXPECTED+=("${changed} (status ${entry:0:2})")
      continue
      ;;
  esac
  case "${changed}" in
    packages/*/pubspec.yaml | packages/*/lib/src/version.dart | README.md | packages/trellis_cli/README.md | site/trellis_site.yaml) EXPECTED_CHANGED+=("${changed}") ;;
    *) UNEXPECTED+=("${changed}") ;;
  esac
done < <(git status --porcelain -z)
if (( ${#UNEXPECTED[@]} > 0 )); then
  # Bracketed per path: a list joined by spaces is unreadable the moment one of
  # the paths contains a space, which is the case this parser exists to report.
  fail "unexpected changes after the bump: $(printf '[%s] ' "${UNEXPECTED[@]}")- bump left in the working tree for inspection; discard it (= ALL uncommitted changes; the tree was clean before the bump) with: git restore --staged --worktree ."
fi
git status --short

# Font bytes live in repository themes rather than published packages, so this
# reproducibility check is advisory rather than a publish blocker.
python3 tool/subset_fonts.py --verify \
  || echo "release: advisory: font provenance was not verified; run 'python3 tool/subset_fonts.py --verify' before changing vendored fonts." >&2

# --- Local gate (ci.yml check tier + publish dry-run) -------------------------
gate_failed() {
  fail "local gate failed. Bump left in the working tree; fix on a branch (reviewed), or discard it (= ALL uncommitted changes; the tree was clean before the bump) with: git restore --staged --worktree ."
}
step "Local gate: analyze"
melos run --no-select analyze || gate_failed
step "Local gate: format:check"
melos run --no-select format:check || gate_failed
step "Local gate: unit tests (packages)"
melos exec --dir-exists=test -- dart test --exclude-tags=e2e || gate_failed
step "Local gate: root tests + root format"
# Bare `dart test` — deliberately WIDER than ci.yml, which runs
# `--exclude-tags=visual`. This is the only place the visual baseline tier runs, and
# that is the point: it is a golden-file layout check whose baselines encode font
# metrics, so it is only meaningful on the machine that recorded them. CI runners
# drift in Chrome version and font set and cannot hold it stable. The tier is what
# catches "the page moved" — 0.11 shipped a hero with 205px of dead space, a mobile
# panel pushing content off the fold and a marker band clipping its own text, all
# with a green suite. So the release gate is where it belongs, and a release must be
# cut on a host that has a recording for its OS: no recording, this fails naming the
# platform rather than passing a check that never ran.
CI=true dart test || gate_failed
dart format --output=none --set-exit-if-changed tool test || gate_failed

# --- Commit, then publish dry-run against the committed tree ------------------
# `dart pub publish --dry-run` warns (non-zero) on a dirty checkout, and the
# uncommitted bump is exactly that — so commit first and undo the commit if the
# dry-run finds a problem (the bump is then back in the working tree, as above).
step "Committing release"
git add -- "${EXPECTED_CHANGED[@]}"
git commit --quiet -m "${MSG}"
undo_commit() { git reset --quiet --soft HEAD~1; }
# Interrupted between commit and tag would leave a tagless release commit on
# main that looks like success to `git status`; unwind it instead.
trap 'undo_commit; echo "release: interrupted; release commit undone, bump left in the working tree." >&2; exit 130' INT TERM

step "Local gate: dart pub publish --dry-run per package"
for pkg in "${PACKAGES[@]}"; do
  echo "--- ${pkg}"
  (cd "packages/${pkg}" && dart pub publish --dry-run) || { undo_commit; gate_failed; }
done

# --- Tag ---------------------------------------------------------------------
if (( DRY_RUN )); then
  step "Dry run: this would have been the release commit (tag ${TAG})"
  git --no-pager show --stat --oneline HEAD
  undo_commit
  trap - INT TERM
  git restore --staged --worktree .
  echo "release (dry-run): commit undone, working tree restored; nothing tagged."
  exit 0
fi

git tag "${TAG}"
trap - INT TERM
print_push
