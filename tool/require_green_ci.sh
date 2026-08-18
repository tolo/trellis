#!/usr/bin/env bash
#
# Release gate: refuse unless the CI workflow concluded `success` for a commit
# that is on the release branch. Shared by .github/workflows/release-gate.yml
# (first job of publish.yml and release-binaries.yml, run against the pushed
# tag) and tool/release.sh (run against main HEAD before the version bump).
#
# Why a script and not "required status checks": main has no branch protection,
# and the tag workflows fire on `push: tags` with no dependency on ci.yml, so
# without this a red build publishes to pub.dev. See dev/guidelines/RELEASE-RUNBOOK.md.
#
set -euo pipefail

usage() {
  cat <<'EOF'
Require a green CI run for a commit before a release may proceed.

Usage:
  tool/require_green_ci.sh <tag|commit-sha>
  tool/require_green_ci.sh --help

Checks, in order (each failure exits 1 with the reason on stderr):
  1. resolves the tag (annotated or lightweight) to its commit
  2. the commit is on the release branch (main) — a tag on a feature branch
     is not a release, however green
  3. the CI workflow (ci.yml) has a run for exactly that commit on main; waits
     for it to appear and to finish (the release commit and its tag are pushed
     together, so CI is usually still running when the tag workflows start)
  4. that run concluded `success`

Environment:
  GH_TOKEN / GH_REPO       as for `gh` (set by the workflow; local runs use the
                           gh login and the current repo)
  CI_WORKFLOW              workflow file to check (default: ci.yml)
  RELEASE_BRANCH           branch the commit must be on (default: main)
  CI_GATE_TIMEOUT_MINUTES  how long to wait for the run to finish (default: 75 —
                           ci.yml's check + e2e tiers may take up to 65 min)
  CI_GATE_APPEAR_MINUTES   how long to wait for the run to exist (default: 10)
  CI_GATE_POLL_SECONDS     poll interval (default: 30)
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

REF="$1"
CI_WORKFLOW="${CI_WORKFLOW:-ci.yml}"
RELEASE_BRANCH="${RELEASE_BRANCH:-main}"
TIMEOUT_MINUTES="${CI_GATE_TIMEOUT_MINUTES:-75}"
APPEAR_MINUTES="${CI_GATE_APPEAR_MINUTES:-10}"
POLL_SECONDS="${CI_GATE_POLL_SECONDS:-30}"

REPO="${GH_REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
export GH_REPO="${REPO}"

fail() {
  echo "release gate: $*" >&2
  exit 1
}

# 1. Resolve to a commit. `commits/<tag>` (bare name, NOT `commits/tags/<tag>`,
#    which 422s on annotated tags) peels annotated tags, so this is the commit
#    the tag points at, not the tag object.
if [[ "${REF}" =~ ^[0-9a-f]{40}$ ]]; then
  SHA="${REF}"
else
  SHA="$(gh api "repos/${REPO}/commits/${REF}" --jq .sha 2>/dev/null)" \
    || fail "cannot resolve tag '${REF}' in ${REPO}"
fi
echo "release gate: ${REF} -> ${SHA}"

# 2. On the release branch? compare/<branch>...<sha> reports the commit's
#    position relative to the branch head: identical|behind = contained.
POSITION="$(gh api "repos/${REPO}/compare/${RELEASE_BRANCH}...${SHA}" --jq .status 2>/dev/null)" \
  || fail "cannot compare ${SHA} against ${RELEASE_BRANCH} (does the branch exist?)"
case "${POSITION}" in
  identical | behind) echo "release gate: ${SHA} is on ${RELEASE_BRANCH} (${POSITION})" ;;
  *) fail "${SHA} is not on ${RELEASE_BRANCH} (compare status: ${POSITION}). Releases are cut from ${RELEASE_BRANCH} only (ADR-009)." ;;
esac

# 3./4. Find the CI run for that exact commit on the release branch and wait
#    for it. Filter on head_branch: a feature-branch push of the same commit
#    only runs the fast tier (ci.yml skips e2e off main) and would not prove
#    what a main run proves. Newest run first; a re-run updates it in place.
find_run() {
  gh api "repos/${REPO}/actions/workflows/${CI_WORKFLOW}/runs?head_sha=${SHA}&per_page=20" \
    --jq "[.workflow_runs[] | select(.head_branch == \"${RELEASE_BRANCH}\")]
          | sort_by(.created_at) | reverse | .[0] // empty
          | \"\(.id) \(.status) \(.conclusion // \"-\") \(.html_url)\""
}

deadline=$(( $(date +%s) + TIMEOUT_MINUTES * 60 ))
appear_deadline=$(( $(date +%s) + APPEAR_MINUTES * 60 ))
# stderr is kept apart from the parsed value: gh may print notices (update
# check, deprecations) on a *successful* call, which must not look like a run.
ERR_FILE="$(mktemp)"
trap 'rm -f "${ERR_FILE}"' EXIT
while :; do
  if ! RUN="$(find_run 2>"${ERR_FILE}")"; then
    ERR="$(cat "${ERR_FILE}")"
    case "${ERR}" in
      *"HTTP 404"*) fail "workflow ${CI_WORKFLOW} not found in ${REPO} — it must exist on the default branch (${ERR})" ;;
      *) fail "querying runs of ${CI_WORKFLOW} failed: ${ERR}" ;;
    esac
  fi

  if [[ -z "${RUN}" ]]; then
    if (( $(date +%s) >= appear_deadline )); then
      fail "no ${CI_WORKFLOW} run for ${SHA} on ${RELEASE_BRANCH} after ${APPEAR_MINUTES} min. Was ${RELEASE_BRANCH} pushed with this commit? Push it, wait for CI, then re-run this workflow (or re-push the tag)."
    fi
    echo "release gate: no ${CI_WORKFLOW} run for ${SHA} yet; waiting ${POLL_SECONDS}s..."
    sleep "${POLL_SECONDS}"
    continue
  fi

  read -r RUN_ID STATUS CONCLUSION URL <<<"${RUN}"
  if [[ "${STATUS}" != "completed" ]]; then
    if (( $(date +%s) >= deadline )); then
      fail "CI run ${RUN_ID} still ${STATUS} after ${TIMEOUT_MINUTES} min: ${URL}. Once it is green, re-run this workflow from the Actions tab (the tag needs no change)."
    fi
    echo "release gate: CI run ${RUN_ID} is ${STATUS}; waiting ${POLL_SECONDS}s... (${URL})"
    sleep "${POLL_SECONDS}"
    continue
  fi
  break
done

if [[ "${CONCLUSION}" != "success" ]]; then
  fail "CI run ${RUN_ID} for ${SHA} concluded '${CONCLUSION}': ${URL}. Fix or re-run CI until green, then re-run this workflow from the Actions tab (the tag needs no change)."
fi
echo "release gate: CI run ${RUN_ID} for ${SHA} is green: ${URL}"
