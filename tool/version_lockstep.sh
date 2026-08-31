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
  tool/version_lockstep.sh --help

Bumps EVERY publishable package to the same version in a single `melos version`
pass. Melos also rewrites the inter-package dependency constraints (e.g. the
`trellis: ^x.y.z` in each satellite) to match, in the same run. The script then
syncs the hardcoded version constants, README download examples, and the docs-site
hero in site/trellis_site.yaml.

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
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
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

# The docs-site hero includes the released SDK version in its terminal card.
# Keep it on the same lockstep rail as package versions and README examples.
SITE_CONFIG="${ROOT}/site/trellis_site.yaml"
echo "Syncing docs-site hero version to ${VERSION}..."
VERSION="${VERSION}" perl -pi -e \
  'BEGIN { $updated = 0 }
   $updated += s/^(\s*text:\s*)(["\x27]?)(trellis )[0-9][0-9A-Za-z.+-]*( — one dependency)\2\s*$/$1$2$3$ENV{VERSION}$4$2/;
   END { exit 1 unless $updated == 1 }' "${SITE_CONFIG}"
git add "${SITE_CONFIG}" 2>/dev/null || true
