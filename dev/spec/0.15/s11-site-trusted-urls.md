# Site trusted URLs

**Plan**: dev/spec/0.15/plan.json
**Story-ID**: S11

## Feature Overview and Goal

**Intent**: Let a site maintainer publish a deliberate URL that the default scheme check would otherwise replace.

**Expected Outcomes**

- [OC01] A maintainer can declare a front-matter or site-data URL and render it from its existing template context.
- [OC02] The default scheme check continues to protect every value without a declaration for its source and field.
- [OC03] Invalid declarations fail the build with enough information to locate the error.

## Required Context

- `dev/spec/0.15/prd.md#fr10-site-url-scheme-opt-out-td-059` – acceptance and TD-059
- `dev/adrs/ADR-015-url-scheme-blocking.md#static-site-trust-declarations` – declaration format and authority boundary
- `dev/architecture/system-architecture.md#data-cascade-lowest-to-highest-priority` – existing precedence
- `dev/guidelines/TESTING-STRATEGY.md#before-merge-bar` – contract checks

## Acceptance Scenarios

- **S01 [OC01] [runtime] A declaration applies to its exact front-matter or data value**
  - **Given** a site's `trustedUrls` names a front-matter bookmarklet and an SVG data URL in separate sources under configured content and data directories
  - **When** the maintainer runs `trellis build` with its default output and again with an output and path-prefix override
  - **Then** a layout emits the original bookmarklet URL from both the direct field and `page` context, emits the original SVG URL from `data`, and retains ordinary path-prefix treatment of relative links. Compare parsed attributes without opening the URLs.

- **S02 [OC01,OC02] [runtime] Source trust survives copying and stays with its value**
  - **Given** a declared section field, a child that inherits it, another child that overrides it with the same URL bytes, and a different page with the same field name
  - **When** the build renders direct fields and page maps in single pages, list slices and taxonomy listings
  - **Then** the inherited field and projections of the declared field render the original URL. The undeclared fields render `about:invalid#trellis-unsafe-url` even when their names and bytes match. Generated fields retain their precedence.

- **S03 [OC02] [runtime] Only site config grants trust**
  - **Given** no site declaration and an otherwise blocked value with a same-named `trustedUrls` key in front matter, a site data file or a theme data file
  - **When** a layout reads those values in dynamic URL attributes
  - **Then** each renders the invalid URL marker. Adding a declaration for an eligible site data file enables its field alone. Removing that file while a theme file with the same stem exists fails as in S04.

- **S04 [OC03] [runtime] Invalid declarations identify the source and field**
  - **Given** a declaration with an absent source, an absent field, or a null, non-string or non-mapping target where a string field is required
  - **When** the maintainer builds the site
  - **Then** the site build fails with `SiteConfigException` naming the source and field, and `trellis build` exits 1 with the same diagnostic.

- **S05 [OC01,OC02] [runtime] A post-Markdown shortcode follows the same source rule**
  - **Given** a post-Markdown shortcode whose existing context receives front matter through a named source
  - **When** it reads a declared field, or an explicit shortcode argument shadows the field
  - **Then** the declared value renders unchanged and a blocked-scheme argument renders the invalid URL marker.

## Structural Criteria

- **SC01 [runtime]** `SiteConfig.load` accepts the ADR's sequence of source/field pairs, defaults an omitted key to no declarations and rejects malformed entries, including absolute or upward-traversing source names. Declarations select from discovered inputs.
- **SC02 [runtime]** Adding a declaration for a front-matter field also used as metadata leaves search and feed metadata readable as the original string.
- **SC03** The package reference documents the declaration, authority over both config and named input, scope by source and field, and errors.
- **SC04** The architecture's data-cascade description records when trust attaches and how precedence works, and its Current through marker includes the change.
- **SC05** The 0.15.0 package changelog records the opt-out.
- **SC06** TD-059 moves to Resolved with a reference to ADR-015 and the executed CLI proof.

## Scope & Boundaries

### Work Areas

- Site configuration loading, normal CLI config overrides and the existing site build.
- Front-matter and global-data render contexts for layouts, page collections and post-Markdown shortcodes.
- Public site configuration reference, architecture, package changelog and TD-059.

### What We're NOT Doing

- A scheme toggle, template directive, wildcard or content-level marker would broaden the ADR-015 authority boundary.
- FR10 covers values routed through dynamic URL attributes. Markdown URLs and literal template attributes use separate paths.

## Architecture Decision

**Approach**: Extend the existing source loaders and use the core `TrustedUrl` type on render projections, preserving source identity through each existing merge.

## Constraints & Gotchas

- `packages/trellis_cli/lib/src/commands/build_command.dart#overrideSiteBuildConfig` reconstructs the config. Both CLI overrides and the dev preview use that path.
- `packages/trellis_site/lib/src/shortcode_processor.dart#processPostMarkdown` has its own renderer. The builder only supplies front matter to it where that context already exists.
- `pageToMap` is used by the taxonomy collector as well as by `PageGenerator`. Global data loading merges theme and site data by file stem.

## Implementation Plan

### Implementation Tasks

- **TI01** The site's config recognizes the declaration schema.
  - **Verify**: `cmd: cd packages/trellis_site && dart test test/site_config_test.dart --plain-name trustedUrls` – literal field names (including a name containing a dot), omission and malformed entries including absolute and upward-traversing sources.
  - **SATISFIES**: SC01

- **TI02** Declared page and data values carry source-scoped trust into emitted HTML through normal and override builds. Invalid declarations reach the builder and CLI error paths.
  - **Verify**: `cmd: cd packages/trellis_cli && dart test test/build_command_test.dart --plain-name trustedUrls` – emitted attributes exercise S01–S03. The fixture invokes the public builder for the typed exception and the build command for the matching error and exit code in S04. Use a data mapping containing both a top-level literal key `brand.logo` and a nested `brand` → `logo` with the same bytes. Only the literal key is trusted; removing it must fail even while the nested key exists. A file outside the configured sources cannot satisfy a declaration. Search JSON and feed metadata read from the same declared front-matter source remain strings.
  - **SATISFIES**: S01, S02, S03, S04, SC01, SC02

- **TI03** Post-Markdown shortcodes retain the declaration and override semantics where they already receive front matter.
  - **Verify**: `cmd: cd packages/trellis_site && dart test test/site_sources_test.dart --plain-name trustedUrls` – composed site output distinguishes the declared value from an explicit override under the existing loader path.
  - **SATISFIES**: S05

- **TI04** The package reference shows a maintainer how to declare and diagnose one URL.
  - **Verify**: `inspect: site/content/docs/packages/trellis_site.md:90` – config key, exact mapping, direct field and data usage, authority, and error cases match ADR-015 and the build proof.
  - **SATISFIES**: SC03

- **TI05** The architecture records the render-stage change.
  - **Verify**: `inspect: dev/architecture/system-architecture.md:425` – trust attaches to the source value before cascade precedence applies, including distinct theme and site data. Check Current through.
  - **SATISFIES**: SC04

- **TI06** The package changelog records the site opt-out for 0.15.0.
  - **Verify**: `inspect: packages/trellis_site/CHANGELOG.md:3` – the 0.15.0 entry identifies the source-scoped declaration.
  - **SATISFIES**: SC05

- **TI07** The backlog records TD-059's resolution.
  - **Verify**: `inspect: dev/state/TECH-DEBT-BACKLOG.md:34` – TD-059 appears under Resolved with its ADR and resulting test evidence.
  - **SATISFIES**: SC06

## Final Validation Checklist

- Serve the built package reference using `dev/guidelines/VISUAL-VALIDATION.md#serving`, read the captures of its declaration example at the specified widths, and check the route under the strict policy.

## Implementation Observations

- ASSUMPTION: Use the named file's real site-relative path for trust. A symlink alias can still
  load ordinary data, but cannot qualify as the declared source. Revisit only if the authority
  model explicitly permits aliases.
- Code review found that stringified keys could hide an absent literal key or shadow a declared one.
  Field matching now uses original YAML keys and rejects shadowed declarations. Review also fixed
  declared site-data parse errors so the builder and CLI include the pair. Routing: Fix applied.
- External implementations of the public `Page` interface continue to work. Trust metadata follows
  the discovered page's identity in a weak side table. A separate regression confirms the same
  source boundary for `SiteConfig` constructed from Dart.
- The Lattice guide's strict-route capture recorded only the existing TD-023 inline theme script.
