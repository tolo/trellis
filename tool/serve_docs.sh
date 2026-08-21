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

cd "${REPO_ROOT}/site"
dart run "${CLI}" build --path-prefix '' --output output-root
exec dart run "${CLI}" serve --output output-root --port "${DOCS_PORT}"
