#!/usr/bin/env bash
#
# Lockstep release for the Trellis SDK — see usage() below and ADR-009.
#
# Melos has no native lockstep mode, so this script enforces it by handing
# `melos version` an explicit version for every package at once.
#
set -euo pipefail

usage() {
  cat <<'EOF'
Lockstep release for the Trellis SDK (ADR-009).

Usage:
  tool/version_lockstep.sh <version> [extra melos flags...]
  tool/version_lockstep.sh --check-refs <version>   # read-only; exit 1 listing stale pins
  tool/version_lockstep.sh --list-ref-files          # files holding a tolo/trellis --ref pin
  tool/version_lockstep.sh --help

Bumps EVERY publishable package to the same version in a single `melos version`
pass. Melos also rewrites the inter-package dependency constraints (e.g. the
`trellis: ^x.y.z` in each satellite) to match, in the same run. The script then
syncs the hardcoded version constants, README download examples, the install-snippet
`trellis*: ^x.y.z` constraints in READMEs and docs pages, every
`https://github.com/tolo/trellis ... --ref v<semver>` theme-install pin repo-wide (CHANGELOGs,
dev/state/LEARNINGS.md and third-party URLs excluded), and the docs-site hero in
site/trellis_site.yaml. tool/release.sh uses --check-refs after the bump and --list-ref-files
to permit those files in the release commit.

The flags a real release needs are built in — run it with just the version:
  --no-changelog           packages keep hand-written CHANGELOG.md files; melos
                           would otherwise stack generated entries on top
  --no-git-commit-version  the release is one hand-made
                           `chore(release): trellis SDK <version>` commit plus a
                           single `vX.Y.Z` tag (ADR-009). Melos would instead make
                           its own commit and per-package tags, which fire
                           publish.yml / release-binaries.yml once pushed.
                           Implies --no-git-tag-version.
  --yes                    skip melos's Y/n prompt, which hangs non-interactive runs

Extra flags are passed to `melos version` after the built-ins, so `--changelog`
or `--git-commit-version` re-enable melos's own defaults (last flag wins).

Examples:
  tool/version_lockstep.sh 0.11.0              # cut the 0.11.0 lockstep bump
  tool/version_lockstep.sh 0.11.0 --changelog  # ...letting melos write changelogs
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

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

# `trellis theme add https://github.com/tolo/trellis --theme x --ref v<semver>` pins in docs and
# READMEs name the release that ships the theme, so they move with every bump. They live
# wherever a theme is documented (docs/, site/content/, packages/*/README.md, themes/*/README.md),
# so the scan is repo-wide over tracked and untracked-but-not-ignored files, minus history and
# narrative: CHANGELOGs, dev/state/LEARNINGS.md and the gitignored .agent_temp/. Only the exact
# repo URL counts - third-party themes (`yourname/trellis-theme-orchard --ref v1.0.0`) keep
# their own versions, even later on the same line, because the match stops at the next URL. The rewrite, --list-ref-files and --check-refs all share this regex, so
# what the bump rewrites is exactly what release.sh then verifies and permits in the release commit.
REF_PIN_RE='github\.com/tolo/trellis(?:\.git)?(?![\w./-])(?:(?!https?://)[^\n])*?--ref v'
# The version a pin names: semver with an optional pre-release, never a trailing full stop.
REF_VERSION_RE='[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]*[0-9A-Za-z])?'
export REF_PIN_RE REF_VERSION_RE

ref_candidates() {
  local path
  git -C "${ROOT}" ls-files -z --cached --others --exclude-standard | while IFS= read -r -d '' path; do
    case "${path}" in
      .agent_temp/* | */.agent_temp/* | dev/state/LEARNINGS.md | CHANGELOG* | */CHANGELOG*) continue ;;
    esac
    if [[ -f "${ROOT}/${path}" && ! -L "${ROOT}/${path}" ]]; then
      printf '%s\0' "${path}"
    fi
  done
}

# Repo-relative paths of files holding at least one pin (relative: release.sh matches them
# against `git status --porcelain`). Every scan runs from ROOT, so the paths resolve.
ref_pin_files() {
  (
    cd "${ROOT}"
    # shellcheck disable=SC2016  # perl source, not shell expansion
    ref_candidates | xargs -0 perl -ne \
      'BEGIN { $pin = $ENV{REF_PIN_RE}; $re = qr/${pin}[0-9]/ } if (/$re/) { print "$ARGV\n"; close ARGV }'
  )
}

# One `file:line: --ref vX (expected vY)` line per pin that is not on $1.
ref_pin_mismatches() {
  (
    cd "${ROOT}"
    # shellcheck disable=SC2016
    ref_candidates | WANT="$1" xargs -0 perl -ne \
      'BEGIN { $re = qr/($ENV{REF_PIN_RE})($ENV{REF_VERSION_RE})/ }
       while (/$re/g) { print "$ARGV:$.: --ref v$2 (expected v$ENV{WANT})\n" if $2 ne $ENV{WANT} }
       close ARGV if eof'
  )
}

case "${1:-}" in
  --list-ref-files)
    ref_pin_files
    exit 0
    ;;
  --check-refs)
    [[ -n "${2:-}" ]] || {
      usage >&2
      exit 1
    }
    mismatches="$(ref_pin_mismatches "$2")"
    if [[ -n "${mismatches}" ]]; then
      echo "version_lockstep: tolo/trellis --ref pins not on v$2:" >&2
      echo "${mismatches}" >&2
      exit 1
    fi
    exit 0
    ;;
esac

VERSION="$1"
shift

# Every publishable package. Keep in sync with the `workspace:` list in
# pubspec.yaml (the examples/ entries are publish_to: none and excluded).
PACKAGES=(
  trellis
  trellis_shelf
  trellis_dev
  trellis_cli
  trellis_css
  trellis_site
  trellis_dart_frog
  trellis_relic
)

# Dart source files holding a hardcoded version constant that must track the
# package version. Melos only bumps pubspec.yaml, so without this these drift
# (as they did at 0.8.1, where trellis_cli --version reported a stale 0.8.0).
# The `version_test.dart` guard in each package fails CI if this list is wrong.
VERSION_CONSTANT_FILES=(
  "${ROOT}/packages/trellis_cli/lib/src/version.dart"
  "${ROOT}/packages/trellis_site/lib/src/version.dart"
)

ARGS=()
for pkg in "${PACKAGES[@]}"; do
  ARGS+=("--manual-version" "${pkg}:${VERSION}")
done

# Flags every real release needs (see usage()). They come before "$@" so callers
# can still override the negatable ones — package:args takes the last occurrence.
RELEASE_FLAGS=(--no-changelog --no-git-commit-version --yes)

CMD=(dart run melos version "${RELEASE_FLAGS[@]}" "${ARGS[@]}" "$@")
echo "Releasing Trellis SDK ${VERSION} (lockstep) across ${#PACKAGES[@]} packages..."
# Echoed because --yes removes melos's confirmation prompt: this is the operator's
# last look at what actually runs.
echo "+ ${CMD[*]}"
"${CMD[@]}"

echo "Syncing version.dart constants to ${VERSION}..."
for file in "${VERSION_CONSTANT_FILES[@]}"; do
  [[ -f "${file}" ]] || continue
  # Rewrite `const String fooVersion = '...';` in place; perl is present on
  # macOS and the Linux CI runners, sidestepping GNU/BSD sed -i differences.
  perl -pi -e "s/(const String \w+Version = ')[^']*(';)/\${1}${VERSION}\${2}/" "${file}"
  git add "${file}" 2>/dev/null || true
done

# READMEs holding a hardcoded example version in the manual-download snippets.
# Melos only bumps pubspec.yaml, so without this the install instructions ship a
# stale release number (e.g. a 0.10.0 README telling users to download 0.9.1).
# The root contract test asserts these stay current; ci.yml and tool/release.sh
# both run it (root `dart test`) — see dev/guidelines/RELEASE-RUNBOOK.md.
README_EXAMPLE_FILES=(
  "${ROOT}/README.md"
  "${ROOT}/packages/trellis_cli/README.md"
)
echo "Syncing README manual-download example versions to ${VERSION}..."
for file in "${README_EXAMPLE_FILES[@]}"; do
  [[ -f "${file}" ]] || continue
  # Anchored to the exact snippet line shapes `VERSION=<semver>` (shell) and
  # `$Version = "<semver>"` (PowerShell) so no other prose is touched. VERSION is
  # passed via the environment so the single-quoted perl program can keep the
  # literal `$Version` unescaped (perl reads `$ENV{VERSION}`, not a shell var).
  VERSION="${VERSION}" perl -pi -e \
    's/^VERSION=[0-9][0-9A-Za-z.+-]*$/VERSION=$ENV{VERSION}/;
     s/(\$Version = ")[0-9][0-9A-Za-z.+-]*(")/$1$ENV{VERSION}$2/' "${file}"
  git add "${file}" 2>/dev/null || true
done

# Install snippets in READMEs and docs pages carry pubspec lines like
# `  trellis_shelf: ^x.y.z`. Melos rewrites only the real pubspecs, so these sat
# at `^0.1.0` until 0.11.1 — a range no published satellite matches (they start
# at 0.8.1), so a copied snippet failed `dart pub get`. The root contract test
# asserts every such line is `^<version>`; this file set, the test's, and the
# allow-list in tool/release.sh must stay identical.
snippet_files() {
  local path
  for path in "${ROOT}/README.md" "${ROOT}"/packages/*/README.md; do
    [[ -f "${path}" ]] && echo "${path}"
  done
  for path in "${ROOT}/docs" "${ROOT}/site/content"; do
    [[ -d "${path}" ]] && find "${path}" -name '*.md'
  done
}
echo "Syncing install-snippet pubspec constraints to ${VERSION}..."
while IFS= read -r file; do
  grep -qE '^[[:space:]]+trellis[A-Za-z0-9_]*: \^' "${file}" || continue
  # Anchored to an indented `trellis<_pkg>: ^<semver>` dependency line, the shape
  # a pubspec snippet has inside a yaml code block, so prose that mentions a
  # constraint inline is left alone.
  VERSION="${VERSION}" perl -pi -e \
    's/^([ \t]+trellis\w*: \^)[0-9][0-9A-Za-z.+-]*$/$1$ENV{VERSION}/' "${file}"
  git add "${file}" 2>/dev/null || true
done < <(snippet_files)

# Theme-install pins (`... github.com/tolo/trellis --theme x --ref v<semver>`): see REF_PIN_RE.
echo "Syncing tolo/trellis --ref pins to v${VERSION}..."
while IFS= read -r file; do
  (cd "${ROOT}" && VERSION="${VERSION}" perl -pi -e \
    'BEGIN { $re = qr/($ENV{REF_PIN_RE})$ENV{REF_VERSION_RE}/ } s/$re/$1$ENV{VERSION}/g' "${file}")
  git -C "${ROOT}" add -- "${file}" 2>/dev/null || true
done < <(ref_pin_files)

# The docs-site hero includes the released SDK version in its terminal card.
# Keep it on the same lockstep rail as package versions and README examples.
SITE_CONFIG="${ROOT}/site/trellis_site.yaml"
echo "Syncing docs-site hero version to ${VERSION}..."
VERSION="${VERSION}" perl -pi -e \
  'BEGIN { $updated = 0 }
   $updated += s/^([ \t]*text:[ \t]*)(["\x27]?)(trellis )[0-9][0-9A-Za-z.+-]*( — one dependency)\2[ \t]*$/$1$2$3$ENV{VERSION}$4$2/;
   END { exit 1 unless $updated == 1 }' "${SITE_CONFIG}"
git add "${SITE_CONFIG}" 2>/dev/null || true
