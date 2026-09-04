# Release Runbook — Trellis SDK

One release = one lockstep version for all 8 packages (ADR-009), one `chore(release)` commit on `main`, one `vX.Y.Z`
tag. **Pushing the tag is the publish** (pub.dev via OIDC, GitHub Release + binaries, Homebrew/Scoop) and pub.dev
cannot unpublish — so everything before the push is automated and rails-guarded, and the push is the one deliberate
human action. Steps are in execution order; each names the guard that enforces it and what to do if it fails.

## 0. On the feature branch — before asking for a merge

- **Changelogs.** Every `packages/*/CHANGELOG.md` gets a hand-written `## X.Y.Z` section (Added/Changed/Fixed;
  `### Breaking` when it applies). Packages with no functional change get the lockstep note verbatim
  (see `packages/trellis_css/CHANGELOG.md` `## 0.10.1`):
  `Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.`
  Guard: `tool/release.sh` refuses to bump if any package lacks the section.
- **Do not bump versions on the branch.** Pubspecs stay at the previous version until step 4; `melos version` is
  restricted to `main` (root `pubspec.yaml` → `melos.command.version.branch`) and `tool/version_lockstep.sh` throws
  `RestrictedBranchException` and changes nothing anywhere else.
- **Local gate = CI's `check` tier**, from the workspace root. Two prerequisites the Dart toolchain does not pull in:
  - **Node 22** — three JS-driven checks. `ci.yml` installs it.
  - **Chrome** — the theme reflow sweep and the visual baseline comparator drive it headless over the DevTools
    protocol. `ci.yml` only *asserts* it (`google-chrome --version`) because the ubuntu image ships it, so on your
    own machine you have to supply it.

  Both tiers skip silently when their binary is absent; `_requireNodeInCi` / `requireChromeInCi` turn that skip into a
  failure only when `CI=true`, so **locally a missing Node or Chrome means those checks quietly do not run**.
  ```bash
  dart run tool/generate_theme_gallery.dart --check          # CI runs this first; a stale gallery fails the job
  melos run --no-select analyze
  melos run --no-select format:check
  melos exec --dir-exists=test -- dart test --exclude-tags=e2e
  dart test                                                  # root suite: release/distribution contracts, tool/
  dart format --output=none --set-exit-if-changed tool test
  ```
  Root `dart test` alone covers only the root suite; `melos exec` alone skips the root — run both.
  **The root run here is deliberately wider than CI's.** CI runs `dart test --exclude-tags=visual`; the bare `dart test`
  above also runs `test/visual_baseline_test.dart`, the golden-file layout tier — and **this is the only place that
  tier runs.** It is what catches "the page moved", which no stylesheet assertion can see. Its baselines encode font
  metrics, so a recording is only valid on the Chrome build and font set that made it; CI runners drift in both
  (recordings from an `ubuntu:24.04` container on Chrome 152 failed the runner's Chrome 151 for the three themes whose
  stacks end in a system fallback), so chasing them there is permanent maintenance for a check that matters most right
  here. Baselines are named per platform (`test/visual_baselines/<theme>.<platform>.json`) and only macOS is recorded:
  **cut releases on macOS**, or record your platform first — a host without a recording fails naming it rather than
  skipping. An appearance change must be re-recorded before `tool/release.sh` will pass; recipe in
  `test/visual_baseline_test.dart`.
- **Font provenance is a second, independently red-able check** — its own workflow (`font-provenance.yml`, every push
  to every branch), not part of the `check` tier and easy to miss locally:
  ```bash
  # Python 3.14 too: tool/subset_fonts.py's TOOLING constant declares "fonttools 4.63.0, brotli 1.2.0, python 3.14"
  # as the tooling contract, and nothing asserts the interpreter - a different python3 gives spurious DRIFT or a
  # false ok.
  python3 -m venv .venv && .venv/bin/pip install 'fonttools==4.63.0' 'brotli==1.2.0'   # pinned, as the workflow does
  .venv/bin/python tool/subset_fonts.py --verify              # every vendored WOFF2 reproduces from its pinned upstream
  ```
  It needs network access to fetch each pinned upstream face — which is why it is no longer a job inside `ci.yml`
  (TD-044): the release gate keys on `ci.yml`, so an upstream outage there blocked a release tag over something the
  commit never touched. **A red `font-provenance` run therefore does not block a tag — but it still means the vendored
  fonts do not reproduce from their pinned upstream. Fix it; do not release past it.**
- Push the branch: `ci.yml` runs the `check` job on every branch (E2E on `main` only), and `font-provenance.yml` runs
  beside it.
- `dart pub publish --dry-run` in every package whose public API changed (0 warnings).

## 1. Fresh-context adversarial review — not optional

Review `git diff main...<branch>` in a fresh context (`andthen:review`, adversarial/critic mode; route review agents to
Opus). Address every finding, commit, re-run the local gate. Guard: discipline only — nothing automates this. Why:
the 0.9.1 hotfix shipped unreviewed with 4 real issues (`dev/state/LEARNINGS.md` § Release & Publishing).

## 2. Squash-merge to `main` and push

```bash
git switch main && git pull --ff-only
git merge --squash <branch> && git commit          # one commit, one-line subject, e.g. "0.10.1: <summary>"
git push origin main
```
Guard: `CLAUDE.md` Workflow Rules (squash only). `ci.yml` starts on the push (`check` + `e2e` on `main`), and
`font-provenance.yml` beside it. Only `ci.yml` gates the tag.

## 3. Wait for CI green on `main`

```bash
gh run watch          # or: gh run list --workflow=ci.yml --branch=main --limit 1
```
Guard: `tool/release.sh` (step 4) calls `tool/require_green_ci.sh` for `origin/main` HEAD and refuses to bump unless
that run is `success` (it waits while the run is in flight). If CI is red: fix on a branch, back to step 1.

## 4. Prepare the release on `main` — `tool/release.sh`

The script requires both `melos` and `gh` on `PATH`, and `gh` must already be authenticated. Install/authenticate them
before starting this step; `release.sh` fails before the bump if either prerequisite is missing.

```bash
tool/release.sh X.Y.Z --dry-run   # rehearsal: same checks + bump + gate + a temporary commit, then unwinds everything
tool/release.sh X.Y.Z
```
It refuses unless: on `main`, tree clean, `HEAD == origin/main`, every changelog has `## X.Y.Z`, CI green for HEAD.
Then: `tool/version_lockstep.sh X.Y.Z` (one `melos version` pass: 8 pubspecs + inter-package constraints, 2
`version.dart` constants, 2 README download examples, every `trellis*: ^x.y.z` install-snippet line in `README.md`,
`packages/*/README.md`, `docs/`, `site/content/`, and the docs-site hero version) → asserts **only** those files
changed → local gate (step 0's five repeated local commands; gallery freshness is supplied by the required green CI
run) → commit `chore(release): trellis SDK X.Y.Z` → `dart pub publish --dry-run` ×8 (commit is undone if one fails)
→ `git tag vX.Y.Z` → prints the push command. **Nothing is pushed.**

Check the commit: `git show --stat HEAD` — 13 fixed files (8 `pubspec.yaml`, 2 `lib/src/version.dart`, `README.md`,
`packages/trellis_cli/README.md`, `site/trellis_site.yaml`) plus every README/docs page holding an install snippet
(13 at 0.11.1: 6 package READMEs, 6 `site/content/docs/packages/` pages, `docs/guides/framework-integration.md`). The
committed root `pubspec.lock` is not rewritten by the bump; release-binary jobs consume it with
`dart pub get --enforce-lockfile`.

If it fails: the message says which check; the bump stays in the working tree for inspection — discard it with
`git restore --staged --worktree .` (discards **all** uncommitted changes; the tree was clean before the bump, so only
the bump is lost) and fix on a branch (step 1). An interrupt between commit and tag unwinds the commit. Re-running is
safe: an existing release commit and/or tag for X.Y.Z is detected and the push command is printed again instead of
bumping twice.

## 5. Push — the one deliberate action

```bash
git push --atomic origin main vX.Y.Z
```
`--atomic`: if someone pushed `main` meanwhile, the tag is rejected together with `main` instead of landing on a commit
that is not on `origin/main`. This publishes. It fires `ci.yml` (release commit), `publish.yml` (pub.dev, one job per
package) and `release-binaries.yml` (binaries → GitHub Release → Homebrew/Scoop). Watch with `gh run watch` /
`gh run list`.

Guards after the push:
- **Release gate** (`release-gate.yml`, first job of both tag workflows): waits for `ci.yml` on the tagged commit and
  refuses to run unless it concluded `success` **and** the commit is on `main`. A red build cannot publish. It looks up
  the `ci.yml` workflow file by name (`tool/require_green_ci.sh`, `CI_WORKFLOW`), so `font-provenance.yml` is outside
  this gate by construction (TD-044) — check it yourself before step 5.
- **Version cross-check** (`release-binaries.yml` → `version` job, `tool/read_version.dart`): tag == pubspec ==
  `cliVersion`, or nothing is built.
- Publish jobs are independent (`fail-fast: false`); pub.dev refuses to re-publish an existing version, so re-running
  a failed job is safe.

## 6. Verify

```bash
tool/verify_release.sh X.Y.Z --wait 20
```
pub.dev ×8, GitHub Release published with 11 assets (5 binaries + 5 `.sha256` + `SHA256SUMS.txt`), Homebrew formula,
Scoop manifest. The same script runs as the last job (`verify`) of `release-binaries.yml`, so a half-published release
is red in the run. Then update `dev/state/STATE.md` (Published Versions).

## 7. If something is red after the push

| Symptom | Do |
|---|---|
| Release gate failed: CI red on the release commit | Nothing was published. Fix on a branch (step 1), squash-merge, wait for CI green; then move the tag by hand to the fixed commit: `git tag -f vX.Y.Z && git push -f origin vX.Y.Z` (versions are already bumped, so `tool/release.sh` refuses; ADR-009: the tag points at the actual release HEAD, not necessarily the bump commit). |
| Release gate failed: CI still running / flaky job / `cancelled` | A queued (not yet started) `main` run is cancelled by GitHub when two more pushes to `main` queue behind it. Re-run that CI run (or the flaky job) until green, then **re-run the failed release workflow from the Actions tab** — the tag needs no change. |
| One `publish.yml` package job failed | Actions tab → Re-run failed jobs. Check the package's pub.dev Admin tab has automated publishing enabled (`tolo/trellis`, `v{{version}}`). |
| `release-binaries.yml` partial | Re-run failed jobs: release creation and asset upload (`--clobber`) are idempotent. Tap jobs skip silently without `TAP_TOKEN`. |

## 8. Rollback reality

- **pub.dev has no unpublish and no delete.** Within **7 days** of publishing, a version can be **retracted** on the
  package's pub.dev **Admin tab** (web only — no CLI): existing `pubspec.lock`s keep resolving it, new resolutions
  skip it. After 7 days: nothing. Either way the remedy is a new patch release through this runbook.
- The GitHub Release and the tag can be deleted, but that does not touch pub.dev — do not look for a delete button.
- Retracting or deleting does not undo the Homebrew/Scoop updates; those move on the next release.

## Not enabled: platform-level protection

`main` has no branch protection. Enabling *Require status checks to pass* with `CI / Analyze, format, unit tests` on
`main` (GitHub → Settings → Branches → Add rule) would make step 3 unskippable at the platform level; the release gate
above works without it and remains the rail for the tag workflows either way.
