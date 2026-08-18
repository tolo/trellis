#!/usr/bin/env bash
#
# Post-release verification: is Trellis SDK <version> fully published everywhere
# the tag workflows publish to? Prints a table, exits 1 if anything is missing.
# Runs as the last job of release-binaries.yml (so a half-published release is
# red in the run, not discovered later) and by hand after a release.
# See dev/guidelines/RELEASE-RUNBOOK.md.
#
set -euo pipefail

usage() {
  cat <<'EOF'
Verify that a Trellis SDK release is fully published.

Usage:
  tool/verify_release.sh <version> [--wait <minutes>] [--no-taps]
  tool/verify_release.sh --help

Checks:
  * pub.dev lists <version> for every publishable package (8)
  * the GitHub Release v<version> is published (not draft) and carries the five
    binaries, their .sha256 sidecars, and SHA256SUMS.txt
  * the Homebrew formula and the Scoop manifest are at <version>
    (--no-taps skips these: release-binaries.yml skips the tap updates when
    TAP_TOKEN is not configured)

--wait <minutes>  re-check failing rows every 30s until all pass or the time is
                  up (publish.yml and release-binaries.yml run in parallel, so
                  pub.dev may lag the binaries by minutes; the tap files are
                  read via raw.githubusercontent.com, cached ~5 min after a tap
                  push). Default: no wait — a FAIL right after a release may
                  just be propagation; re-run with --wait.

Environment: GH_TOKEN / GH_REPO as for `gh` (defaults to the current repo).
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
WAIT_MINUTES=0
CHECK_TAPS=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      shift
      WAIT_MINUTES="${1:?--wait needs a number of minutes}"
      [[ "${WAIT_MINUTES}" =~ ^[0-9]+$ ]] || { echo "verify_release: --wait needs a whole number of minutes, got '${WAIT_MINUTES}'" >&2; exit 1; }
      ;;
    --no-taps) CHECK_TAPS=0 ;;
    *)
      echo "verify_release: unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

for tool_bin in gh curl jq; do
  command -v "${tool_bin}" >/dev/null 2>&1 || { echo "verify_release: '${tool_bin}' not on PATH" >&2; exit 1; }
done

REPO="${GH_REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
export GH_REPO="${REPO}"
TAG="v${VERSION}"
# Keep in sync with tool/version_lockstep.sh PACKAGES and publish.yml's matrix.
PACKAGES=(trellis trellis_shelf trellis_dev trellis_cli trellis_css trellis_site trellis_dart_frog trellis_relic)
# Keep in sync with release-binaries.yml's build matrix + checksums job.
ASSETS=(
  "trellis-${TAG}-macos-arm64.tar.gz" "trellis-${TAG}-macos-arm64.tar.gz.sha256"
  "trellis-${TAG}-macos-x64.tar.gz" "trellis-${TAG}-macos-x64.tar.gz.sha256"
  "trellis-${TAG}-linux-x64.tar.gz" "trellis-${TAG}-linux-x64.tar.gz.sha256"
  "trellis-${TAG}-linux-arm64.tar.gz" "trellis-${TAG}-linux-arm64.tar.gz.sha256"
  "trellis-${TAG}-windows-x64.zip" "trellis-${TAG}-windows-x64.zip.sha256"
  "SHA256SUMS.txt"
)
HOMEBREW_FORMULA_URL="https://raw.githubusercontent.com/tolo/homebrew-trellis/main/Formula/trellis.rb"
SCOOP_MANIFEST_URL="https://raw.githubusercontent.com/tolo/scoop-trellis/main/bucket/trellis.json"

# Each check echoes "PASS <detail>" or "FAIL <detail>". They never exit non-zero
# themselves so one flaky endpoint cannot abort the table.
check_pubdev() {
  local pkg="$1" json
  json="$(curl -fsS --max-time 20 "https://pub.dev/api/packages/${pkg}" 2>/dev/null)" || { echo "FAIL pub.dev API unreachable"; return; }
  if jq -e --arg v "${VERSION}" '.versions[].version | select(. == $v)' <<<"${json}" >/dev/null; then
    echo "PASS latest=$(jq -r .latest.version <<<"${json}")"
  else
    echo "FAIL not on pub.dev (latest=$(jq -r .latest.version <<<"${json}"))"
  fi
}

check_release() {
  local json
  json="$(gh release view "${TAG}" --json isDraft,assets 2>/dev/null)" || { echo "FAIL release ${TAG} not found"; return; }
  if [[ "$(jq -r .isDraft <<<"${json}")" == "true" ]]; then
    echo "FAIL release ${TAG} is still a draft"
    return
  fi
  local missing=()
  for asset in "${ASSETS[@]}"; do
    jq -e --arg a "${asset}" '.assets[] | select(.name == $a)' <<<"${json}" >/dev/null || missing+=("${asset}")
  done
  if (( ${#missing[@]} == 0 )); then
    echo "PASS published, ${#ASSETS[@]} assets"
  else
    echo "FAIL missing assets: ${missing[*]}"
  fi
}

check_homebrew() {
  local formula
  formula="$(curl -fsS --max-time 20 "${HOMEBREW_FORMULA_URL}" 2>/dev/null)" || { echo "FAIL formula unreachable"; return; }
  if grep -q "^  version \"${VERSION}\"" <<<"${formula}"; then
    echo "PASS Formula/trellis.rb version ${VERSION}"
  else
    echo "FAIL formula is at $(sed -n 's/^  version "\(.*\)"/\1/p' <<<"${formula}")"
  fi
}

check_scoop() {
  local manifest current
  manifest="$(curl -fsS --max-time 20 "${SCOOP_MANIFEST_URL}" 2>/dev/null)" || { echo "FAIL manifest unreachable"; return; }
  current="$(jq -r .version <<<"${manifest}")"
  if [[ "${current}" == "${VERSION}" ]]; then
    echo "PASS bucket/trellis.json version ${VERSION}"
  else
    echo "FAIL manifest is at ${current}"
  fi
}

# Parallel arrays (macOS ships bash 3.2: no associative arrays).
LABELS=()
CHECKS=()
RESULTS=()
for pkg in "${PACKAGES[@]}"; do
  LABELS+=("pub.dev ${pkg}")
  CHECKS+=("check_pubdev ${pkg}")
done
LABELS+=("GitHub Release ${TAG}")
CHECKS+=("check_release")
if (( CHECK_TAPS )); then
  LABELS+=("Homebrew tap" "Scoop bucket")
  CHECKS+=("check_homebrew" "check_scoop")
fi
for _ in "${LABELS[@]}"; do RESULTS+=(""); done

deadline=$(( $(date +%s) + WAIT_MINUTES * 60 ))
while :; do
  failing=0
  for i in "${!CHECKS[@]}"; do
    # Only re-run rows that have not passed yet.
    [[ "${RESULTS[$i]}" == PASS* ]] && continue
    # shellcheck disable=SC2086 # intentional word split: "check_fn arg"
    RESULTS[i]="$(${CHECKS[i]})"
    [[ "${RESULTS[$i]}" == PASS* ]] || failing=$((failing + 1))
  done
  if (( failing == 0 )) || (( $(date +%s) >= deadline )); then break; fi
  echo "verify_release: ${failing} check(s) not yet passing; re-checking in 30s ($(( (deadline - $(date +%s)) / 60 )) min left)..."
  sleep 30
done

echo
printf '%-32s %-5s %s\n' "CHECK (Trellis SDK ${VERSION})" "" "DETAIL"
printf '%-32s %-5s %s\n' "-------------------------------" "-----" "------"
for i in "${!LABELS[@]}"; do
  printf '%-32s %-5s %s\n' "${LABELS[$i]}" "${RESULTS[$i]%% *}" "${RESULTS[$i]#* }"
done
echo
if (( failing > 0 )); then
  echo "verify_release: ${failing} check(s) FAILED for ${VERSION}." >&2
  exit 1
fi
echo "verify_release: ${VERSION} is fully published."
