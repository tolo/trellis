---
name: trellis-ui-sync
description: Bump the pinned shadcn/ui tag in Trellis UI, compare all component states locally, and produce a triaged sync report for owner review.
---

# Sync Trellis UI

Leave one sync commit with one shadcn vendor tree, reproducible embedded assets, and a report the checker accepts.

Start on the 0.14 feature branch for the first sync, with committed inputs under `packages/trellis_ui/`. Check
`packages/trellis_ui/tool/pins.json` and `dev/ui-gate/manifests/`. You need GitHub and the pinned Tailwind download,
Chrome, Firefox, geckodriver on `PATH` or via `GECKODRIVER`, and the baseline's host OS. See
[UI qualification](../../../dev/guidelines/TESTING-STRATEGY.md#ui-qualification-gate).

1. From the repository root, run `git ls-remote --tags https://github.com/shadcn-ui/ui.git 'refs/tags/shadcn@*'`.
   Select the highest numeric stable `shadcn@X.Y.Z` tag. Stop if it equals the pin. Set `tag` to that value.
   Run `dart run packages/trellis_ui/tool/port.dart sync "$tag"`. The tool uses committed `HEAD` as the old side and
   installs the candidate after it builds. It prints the report path and writes the active upstream inventory to
   `packages/trellis_ui/tool/sync-inventory.json`. Set `report` to the printed path.
2. Run `dart test test/ui_gate_appearance_test.dart --plain-name 'spike regressions'`. The secondary button hover,
   changed light/dark tokens and two overlapping toasts must all be caught before using the appearance gate.
   A state the digest misses needs a same-browser pixel comparison before its verdict can be used.
3. Run `dart run packages/trellis_ui/tool/port.dart parity`, `dart run packages/trellis_ui/tool/port.dart check`,
   `dart run packages/trellis_ui/tool/embed.dart`, and `dart run packages/trellis_ui/tool/embed.dart --check`.
   Update existing provenance paths to the fetched MIT notice when the tag changes. Keep the rest of each recipe.
4. Save the committed baseline and record hashes. Copy the records into scratch so the compare run preserves any
   maintainer-entered manual entries. Run both default browsers over every manifest with
   `dart run tool/ui_gate.dart --serve 'dart run packages/trellis_ui/tool/gallery.dart --port 0' --records .agent_temp/ui-sync/records --captures .agent_temp/ui-sync/captures`.
   Read every difference before triage. Preserve each failing record and capture as evidence, and restart the server
   after regeneration so the browser sees the new embedded bytes. Review screenshots at 390 and 1440 px for Button,
   Dialog, Table and Toast against the differences.
5. Classify all upstream rows and record every nonpassing gate and appearance difference in the report. Fix at the
   hand-layer cause and rerun the affected gates. Keep the recorded failure and stop if it survives two real fixes.
   An existing [ADR-012 release disposition](../../../dev/adrs/ADR-012-trellis-ui-contract.md#optional-component-release-dispositions)
   can account for the same failed items. Keep the raw failure evidence and stop on any new failure.
   Keep release limits, recipes, states, axe rules and comparison tolerances intact. Record a hand-layer JS change
   for the revisit threshold in [ADR-012](../../../dev/adrs/ADR-012-trellis-ui-contract.md#revisit-triggers).
6. Only for a reviewed `expected` appearance change, record the affected components to a separate baseline directory
   with `--record --baselines .agent_temp/ui-sync/baselines` on the same command. Read that diff and retain all
   previous states and unclassified entries. Copy the classified change into the tracked baseline and rerun in
   compare mode. Recording is refused under `CI=true`. Keep a failing item red until the fix or accepted appearance
   change passes in compare mode.
7. Run `dart run packages/trellis_ui/tool/port.dart sync --check-report "$report"`. Run the whole component gate again
   with `dart test test/qualification_gate_test.dart` from `packages/trellis_ui/` and compare the record and baseline
   hashes with the reviewed raw sweep. Check the three separate gzip responses, owned JS, and example CSS against the
   [release limits](../../../dev/guidelines/TESTING-STRATEGY.md#ui-qualification-gate). Commit only the verified
   pin, vendor/generated files, upstream inventory, embed output, explained hand changes, references and report.
   Keep the owner review at `release-prep`.

## Report fields

- Keep every generated `U001` heading and `Kind` in order. The checker matches them against the generated inventory for
  the active pin. Classify an input as `mechanical` or `hand-layer edit`.
  For a new component enter `port`, `defer` or `skip`, with a reason. An independent port belongs in its own change.
- Each gate has a `Result` of `pass`, `fail` or `not-run`. Keep nonpassing evidence even after a passing rerun.
  Use additional `### Gate <name>` rows for failures and leave the baseline pass result visible.
- For each distinct appearance difference add a numbered `### A001 <component / browser / state / selector / property>`
  row and update `Appearance entries`. Name the old and new values in its evidence. Resolve each upstream, appearance
  and nonpassing gate row with `Disposition: expected`, `Disposition: fixed` or `Disposition: deferred` and a `Reason`.
  A passing gate's disposition is blank. A deferral needs a reason and leaves any failed automated item red.
- Count changed template, hand CSS and owned JS lines and config entries against committed `HEAD`. Add ` | reason` after
  a count beyond four template lines, three CSS lines, one config entry or any JS edit.
- Classify every `BREAKING` public class as a rename or removal. After that class has shipped, record the change
  under `### Breaking` in `packages/trellis_ui/CHANGELOG.md`.
