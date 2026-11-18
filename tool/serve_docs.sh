#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: tool/serve_docs.sh [port]"
}

if (( $# > 1 )); then
  usage >&2
  exit 2
fi

if (( $# == 1 )); then
  DOCS_PORT="$1"
  if [[ ! "${DOCS_PORT}" =~ ^[0-9]{1,5}$ ]] \
    || (( 10#${DOCS_PORT} < 1 || 10#${DOCS_PORT} > 65535 )); then
    echo "serve_docs: port must be an integer between 1 and 65535" >&2
    usage >&2
    exit 2
  fi
else
  DOCS_PORT=8765
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="../packages/trellis_cli/bin/trellis.dart"

# The site reads the generated inventories, so regenerate them before previewing source changes.
cd "${REPO_ROOT}"
dart run tool/generate_theme_gallery.dart
dart run tool/generate_ui_reference.dart

# `dev` builds root-served into a temp directory, then rebuilds and reloads the browser on every source change.
cd "${REPO_ROOT}/site"
exec dart run "${CLI}" dev --port "${DOCS_PORT}"
