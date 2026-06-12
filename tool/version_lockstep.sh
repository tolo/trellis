#!/usr/bin/env bash
#
# Lockstep release for the Trellis SDK.
#
# Bumps EVERY publishable package to the same version in a single `melos version`
# pass. Melos also rewrites the inter-package dependency constraints (e.g. the
# `trellis: ^x.y.z` in each satellite) to match, in the same run.
#
# Trellis versions all SDK packages in lockstep — see ADR-009. Melos has no
# native lockstep mode, so this script enforces it by handing `melos version` an
# explicit version for every package at once.
#
# Usage:
#   tool/version_lockstep.sh <version> [extra melos flags...]
#
# Examples:
#   tool/version_lockstep.sh 0.9.0                      # bump all packages to 0.9.0
#   tool/version_lockstep.sh 0.9.0 --no-git-tag-version # ...without git tags
#
set -euo pipefail

VERSION="${1:?Usage: tool/version_lockstep.sh <version> [extra melos flags...]}"
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

ARGS=()
for pkg in "${PACKAGES[@]}"; do
  ARGS+=("--manual-version" "${pkg}:${VERSION}")
done

echo "Releasing Trellis SDK ${VERSION} (lockstep) across ${#PACKAGES[@]} packages..."
exec dart run melos version "${ARGS[@]}" "$@"
