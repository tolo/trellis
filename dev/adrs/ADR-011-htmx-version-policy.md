# ADR-011: HTMX Version Policy and Hypermedia Coupling Boundary

## Status
Accepted (2026-07-26). Records a previously unrecorded, de-facto decision: HTMX has
been the load-bearing interactivity story since v0.3 without an ADR. Defers the
HTMX 4 migration; supersedes nothing. Amended 2026-09-04 after the HTMX 4.0.0 release:
adapters and scaffolds made version-agnostic, pin unchanged (see Amendment).

## Context

HTMX is named as Trellis's interactivity story across the README, the SDK vision
doc, the roadmap, and dozens of PRDs/FIS specs. Three SDK packages are explicitly
scoped as "HTMX helpers" packages. Yet no ADR records *what* Trellis depends on,
*how tightly*, or *which HTMX version* it targets. That gap surfaced when HTMX 4
was published at [four.htmx.org](https://four.htmx.org) and the upgrade question
had no recorded policy to answer it against.

### What Trellis actually couples to

An inventory of both repos (2026-07-26) found the coupling is shallower than the
positioning implies:

- **Core `package:trellis` — zero HTMX awareness.** `renderFragments`
  ([`engine.dart`](../../packages/trellis/lib/src/engine.dart)) is generic fragment
  concatenation. Foreign `hx-*` attributes pass through untouched, pinned by a test
  (`engine_test.dart`, "HTMX OOB attributes preserved"). The engine would work
  identically against Turbo, Unpoly, or hand-written `fetch()`.
- **Runtime coupling — five request headers, read never written.** `HX-Request`,
  `HX-Target`, `HX-Trigger`, `HX-Boosted`, and `HX-Source` (added by the 2026-09-04
  amendment), in three near-identical ~20-line
  `htmx_helpers.dart` files (`trellis_shelf`, `trellis_dart_frog`,
  `trellis_relic`), plus one `isHtmxRequest()` branch per package in
  `response_helpers.dart` selecting fragment vs. full page.
- **Asset coupling — one CDN pin**, no vendoring, no npm/pub dependency. HTMX is a
  `<script>` tag in scaffolded layouts and example templates.
- **Attribute surface — a dozen standard attributes** (`hx-get/post/put/delete`,
  `hx-target`, `hx-swap`, `hx-swap-oob`, `hx-trigger`, `hx-vals`, `hx-include`,
  `hx-confirm`, `hx-push-url`). None of the attributes HTMX 4 removes are used.
  `hx-boost` is not used anywhere.
- **SSG themes and `trellis_dev` are HTMX-free.**

### HTMX 4 status (verified 2026-07-26)

- Current release is **`4.0.0-beta6`** — the 14th pre-release since 2025-11-03.
- npm dist-tags: **`latest: 2.0.10`, `next: 4.0.0-beta6`**. HTMX 4 is opt-in.
- Breaking changes are still landing *between betas*: beta6 (2026-07-23) renamed
  `htmx:swap:finally` → `htmx:finally:swap`, flagged Breaking in its own notes.
- The maintainer's published timeline — production "early-to-mid 2026", `latest`
  tag "early-2027ish" ([the fetchening](https://four.htmx.org/essays/the-fetchening/))
  — has slipped, with no revised date published.
- **HTMX 2 is committed to be "supported in perpetuity."** There is no forced
  migration and no deadline.
- Version 4 rather than 3 is a deliberate joke: the maintainer had promised there
  would never be a backwards-incompatible htmx 3.
- **Update 2026-09-04:** 4.0.0 final shipped 2026-08-28. npm dist-tags are
  `latest: 2.0.10`, `next: 4.0.0`; the release announcement keeps 4.x on `next` until
  early 2027 and states HTMX 2 "will continue to be supported indefinitely".

### What HTMX 4 would cost Trellis

Verified against the [HTMX 4 migration guide](https://four.htmx.org/docs#migration)
and attribute reference:

| Helper | HTMX 4 status |
|---|---|
| `isHtmxRequest()` | unchanged — `HX-Request` still sent |
| `isHtmxBoosted()` | unchanged — `HX-Boosted` still sent |
| `htmxTarget()` | header present, **value reformatted to `tag#id`** |
| `htmxTrigger()` | **broken** — request `HX-Trigger` → `HX-Source` |

Also relevant at migration time, though not currently depended on: out-of-band swap
ordering reverses (main content swaps first), and the new `<hx-partial>` element
provides explicit per-fragment `hx-target`/`hx-swap` — arguably a *better* fit for
Trellis's named-fragment model than `hx-swap-oob`. The biggest HTMX 4 semantic break,
inheritance flipping from implicit to explicit, barely touches Trellis because the
scaffolds do not rely on inherited attributes.

Net: one broken function across three files, plus documentation. The engine needs
no change.

## Decision Drivers

- **Scaffolded output is a user contract.** `trellis create` output is what users
  build on for months. A pin shipped there propagates churn we do not control.
- **Trellis being pre-1.0 licenses breaking *our* API, not *users'* apps.** Our
  alpha status is not a reason to hand users a dependency the upstream maintainer
  has not blessed as default.
- **Keep the engine hypermedia-agnostic.** The core's value does not depend on HTMX
  and must not grow to.
- **Migration cost should stay near-zero**, so version decisions are driven by merit
  rather than by sunk effort.
- **Supply-chain hygiene** — pinned versions with Subresource Integrity.

## Decision

**1. Track the HTMX `latest` dist-tag. Currently the 2.x line; pinned at 2.0.10.**

Trellis does not ship pre-release dependencies in scaffolded projects or examples.
HTMX 4 adoption is deferred until the trigger below fires.

**2. The core engine stays hypermedia-agnostic.**

`package:trellis` gains no HTMX awareness — no header logic, no `hx-*`
interpretation, no HTMX-specific attributes. Fragment rendering stays generic. The
existing pass-through test is the guard.

**3. All HTMX version coupling lives behind one constant.**

[`htmx_asset.dart`](../../packages/trellis_cli/lib/src/templates/htmx_asset.dart)
holds `htmxVersion`, `htmxSriHash`, `htmxCdnUrl`, and `htmxScriptTag()`. Scaffolded
layouts must not hard-code a version. Example templates are plain HTML and cannot
import the constant, so `htmx_asset_test.dart` asserts they agree with it.

**4. HTMX protocol coupling stays confined to the adapter packages.**

`trellis_shelf`, `trellis_dart_frog`, `trellis_relic` are the only packages that may
read `HX-*` headers. These are optional integration packages — a user can consume
`package:trellis` with any hypermedia library or none.

**5. Scaffolded HTMX script tags are SRI-pinned.**

All three generated layouts now carry `integrity` + `crossorigin`. Regenerate the
hash on every bump; the command is documented in `htmx_asset.dart`.

### Revisit trigger

Schedule the HTMX 4 migration when **either**:

- the npm `htmx.org` dist-tag `latest` moves to a 4.x release — the maintainer's own
  readiness signal; or
- 4.0.0 final ships and a Trellis-relevant capability justifies moving early
  (`<hx-partial>` for fragment targeting is the current candidate).

Not before. HTMX 2's in-perpetuity support means there is no deadline pressure.

When the trigger fires, the migration is scoped as: rename `htmxTrigger()` →
`htmxSource()` and repoint it at `HX-Source` (×3 packages), document `htmxTarget()`'s
`tag#id` value format, bump `htmxVersion` + SRI hash, re-verify the OOB ordering
assumptions in `renderOobFragments`, and update the framework-integration guide.
Run `npx htmx.org@<version> upgrade-check` against `examples/` for a concrete diff.

## Consequences

### Positive
- The upgrade question now has a recorded answer and an objective trigger, rather
  than being re-litigated whenever upstream ships a release.
- A version bump is one constant plus the example templates, guarded by a test that
  fails with an actionable message.
- Scaffolded projects gain SRI coverage that was previously missing in the Relic
  layout.
- The agnostic-core boundary is explicit, so swapping or adding a hypermedia library
  later is an adapter-package concern.

### Negative / accepted trade-offs
- Trellis ships a nominally older HTMX than the newest published release. Accepted:
  `latest` is 2.x, so this is the mainstream choice, not a laggard one.
- `htmxTrigger()` stays exported as a deprecated alias of `htmxSource()` (amendment
  2026-09-04) rather than being removed; removal waits for the migration.
- Example templates duplicate the version string. Unavoidable — they are plain HTML.
  Mitigated by the drift test rather than by a build step.
- Historical phase specs in the private repo still cite the 2.0.8 pin. Deliberately
  not rewritten: they are records of what was built at the time. This ADR is the
  current authority.

## Alternatives Considered

**Adopt HTMX 4 beta now.** Rejected. It buys no capability Trellis currently needs,
costs documentation and template churn twice (now and again at GA), and pushes
pre-release churn into user projects via scaffolding. The "we're alpha too" argument
does not transfer: our pre-1.0 status licenses breaking our own API deliberately, not
breaking users' apps through a transitive pin whose release cadence we do not control.

**Adopt HTMX 4 with the `htmx-2-compat` extension.** Rejected. The shim covers
inheritance, event names, and error-swapping only — not the transport change,
extension API rewrite, header renames, `hx-swap` modifier syntax, OOB ordering, or
history caching. It buys compatibility, not the modern semantics, at the cost of an
extra asset.

**Vendor HTMX into scaffolded projects instead of CDN.** Out of scope here, but noted
as a live question — it would align with ADR-010's "self-contained / vendored-over-CDN"
asset preference order for *themes*. Scaffolded dynamic apps are a different context
(they already require a server); revisit separately rather than bundling it into a
version-policy decision.

**Abstract the hypermedia layer behind a Trellis-owned interface.** Rejected as
speculative. Coupling is already four header reads in optional packages; an
abstraction would add indirection without removing anything.

## References
- HTMX 4 docs and migration guide: https://four.htmx.org/docs#migration
- HTMX 4 attribute/header reference: https://four.htmx.org/reference/
- Rationale, version numbering, HTMX 2 support commitment: https://four.htmx.org/essays/the-fetchening/
- HTMX releases: https://github.com/bigskysoftware/htmx/releases
- Pin + SRI constant: [`htmx_asset.dart`](../../packages/trellis_cli/lib/src/templates/htmx_asset.dart)
- Drift guard: [`htmx_asset_test.dart`](../../packages/trellis_cli/test/htmx_asset_test.dart)
- Adapter coupling: [`trellis_shelf/htmx_helpers.dart`](../../packages/trellis_shelf/lib/src/htmx_helpers.dart), [`trellis_dart_frog/htmx_helpers.dart`](../../packages/trellis_dart_frog/lib/src/htmx_helpers.dart), [`trellis_relic/htmx_helpers.dart`](../../packages/trellis_relic/lib/src/htmx_helpers.dart)
- Related: [ADR-005](ADR-005-server-integration-strategy.md) (server integration — cites the HTMX-first architecture as a decision driver), [ADR-010](ADR-010-syntax-highlighting.md) (asset preference order)

## Amendment (2026-09-04): version-agnostic adapters, pin unchanged

HTMX 4.0.0 shipped 2026-08-28 on the `next` dist-tag. Neither revisit-trigger arm has
fired (`latest` is still 2.0.10; `<hx-partial>` is not yet needed), so decision 1
stands. The part of the migration scope that needs no pin change was done now, so a
project can run HTMX 4 against unchanged packages and a fresh scaffold:

- `htmxSource()` added to the three adapters: reads `HX-Source` (HTMX 4, `tag#id`,
  id extracted) and falls back to the `HX-Trigger` request header (HTMX 2).
  `htmxTrigger()` is a deprecated alias of it.
- `htmxTarget()` extracts the id from HTMX 4's `tag#id`. The presence of `HX-Source`,
  which HTMX 4 always sends, is the version discriminator; a value without `#` under
  HTMX 4 means the target has no id and yields `null`. Unchanged for HTMX 2.
- The Shelf and Dart Frog scaffold layouts (and the mirrored example layouts) register
  the CSRF listener for both `htmx:configRequest` (`evt.detail.headers`) and
  `htmx:config:request` (`evt.detail.ctx.request.headers`).
- Verified against the published 4.0.0 source rather than the docs: `HX-Request: true`,
  `HX-Boosted`, `hx-swap-oob` are unchanged; `HX-Target` and `HX-Source` are built as
  `` `${tag}${id ? '#' + encodeURI(id) : ''}` ``; DELETE parameters travel in the query
  string on both versions.

Still behind the trigger: the `htmxVersion` + SRI bump, `<hx-partial>` adoption, and the
`includeIndicatorStyles` → `includeIndicatorCSS` rename noted in TD-018. TD-012 is
resolved by this amendment.
