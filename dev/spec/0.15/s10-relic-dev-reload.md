# Relic dev reload

**Plan**: dev/spec/0.15/plan.json
**Story-ID**: S10

## Feature Overview and Goal

**Intent**: A Relic author can see a CSS or JavaScript edit without refreshing the browser by hand.

**Expected Outcomes**

- [OC01] A newly scaffolded Relic development app refreshes connected pages on static CSS and JS edits.
- [OC02] The Relic scaffold keeps its strict CSP in development and production and exposes reload only in development.

## Required Context

- `dev/spec/0.15/prd.md#fr9-relic-dev-reload-td-058` – scaffold parity and debt outcome. [LEA-41](https://linear.app/leafnode/issue/LEA-41/product-requirements-document-trellis-ui-public-web-components-015)
- `dev/adrs/ADR-002-browser-hot-reload-strategy.md#decision` – uses SSE and the template loader change stream.
- `dev/architecture/system-architecture.md#relic-trellis_relic` – native middleware and Relic response conventions.
- `dev/guidelines/TESTING-STRATEGY.md#e2e` – generated-app boot and loopback proof.
- `dev/PRODUCT.md#proportionality` – keep this within the existing Dart SDK packages and toolchain.

## Acceptance Scenarios

- **S01 [OC01] [runtime] Both CSS and JS edits reload the generated app**
  - **Given** an app created by `trellis create --template relic` runs with `dart run bin/server.dart --dev` on its default `relic_io` adapter. One browser page runs the reload client and a separate same-origin observer holds a browser EventSource open across edits.
  - **When** the author edits `static/styles.css` and then `static/js/csrf.js`, waiting for the browser to reconnect after the first edit.
  - **Then** the observer receives both named reload events, one per edit, on the same connection before stream close. The client page performs two full-page navigations, reconnecting after the first. The server stays up throughout.

- **S02 [OC02] [runtime] Production serves neither reload route nor client**
  - **Given** the same scaffold runs without `--dev` and without `DEV=true`.
  - **When** a user loads `/` and requests `/_dev/reload` and `/_dev/reload.js`.
  - **Then** the page contains no reload client and both requests return 404.

- **S03 [OC01,OC02] [runtime] Reload runs under the strict scaffold policy**
  - **Given** the default self-hosted scaffold serves `/` and `/about` with `script-src 'self'; style-src 'self'`.
  - **When** a browser loads and navigates between them with HTMX and reloads a development page following an asset edit.
  - **Then** the browser reports zero CSP violations in both modes, and the development reload client runs from the same origin.

## Structural Criteria

- **SC01** The Relic package stays free of Shelf and the Shelf-based `trellis_dev` dependency. The scaffold still starts its default Dart I/O adapter and retains the existing distribution model.
- **SC02** Relic author docs show the dev command and middleware wiring, the architecture records the Relic reload path, the affected packages carry 0.15.0 entries, and TD-058 is recorded as resolved after proof.
- **SC03 [runtime]** A native Relic reload stream delivers its handshake before edits and separate events for template, root CSS and nested JS changes before the stream ends. Its watchers and connections close with the development loader.

## Scope & Boundaries

### Work Areas

- Relic reload routes, middleware and watcher lifecycle in `packages/trellis_relic` (TI01).
- Generated Relic server, CLI and E2E fixtures in `packages/trellis_cli` (TI02–TI03).
- Relic dependency boundary (TI04).
- ADR-002, system architecture, Relic integration and CLI guide, package changelogs and TD-058 (TI05).

### What We're NOT Doing

- A shared HTTP adapter extraction or a Shelf bridge. Relic already has a native integration boundary, and FR9 requires parity at the browser and SSE contract.
- Wiring browser reload into existing applications. The scaffold opts in and the package provides wiring for authors.

## Architecture Decision

**Approach**: Extend `trellis_relic` with native matched SSE and script routes plus a full-page injection middleware, using the existing `FileSystemLoader` change stream and the Shelf client’s route and event contract.
**Why this over the floor**: The scaffold’s current dev loader only refreshes template inputs on render. FR9 requires mounted routes and a client that reloads a connected browser.

## Constraints & Gotchas

- Relic middleware runs on matched routes. Register a real GET for each reload endpoint only in dev, and set mime types on the response bodies. Inject before `</body>` in buffered page HTML while preserving CSP headers and passing fragments or streamed bodies through.
- A loopback probe against workspace-pinned Relic 2.0.0 timed out before receiving an ordinary SSE handshake. The Dart I/O adapter flushes after the response stream ends. The same probe streamed the handshake and two reload events when each was sent in one data chunk with an ignored 8 KiB SSE comment.
- Keep the tested padding local to the default I/O adapter's dev stream until it can flush individual writes and the on-wire proof passes without padding. The opt-in `relic_native` adapter delivers small frames but adds a build hook and shared library to the generated application's distribution.
- Match the Shelf convention that `DEV=true` and `--dev` both opt in. The generated app’s file-system loader remains separately owned when `--ui` wraps it in a `CompositeLoader`.

## Implementation Plan

### Implementation Tasks

- **TI01** Relic serves reload streams and a separate script, with a development lifetime for the existing template and recursive CSS/JS change signals.
  - Follow `packages/trellis_dev/lib/src/dev_middleware.dart#_reloadChanges` and `packages/trellis_dev/lib/src/live_reload_handler.dart#liveReloadChangesHandler`. Release subscriptions on teardown. Exercise Relic through a socket because body MIME type and chunk delivery are wire behaviour.
  - **Verify**: `cmd: dart test packages/trellis_relic/test/dev_reload_test.dart` – assert SC03 on the real socket and require `Content-Type: text/event-stream` and the expected event name.
  - **SATISFIES**: SC03

- **TI02** The actual CLI scaffold wires development reload for both start switches and omits it in production.
  - Apply the opt-in pattern from `packages/trellis_cli/lib/src/templates/server_template.dart#serverTemplate` to `packages/trellis_cli/lib/src/templates/relic/relic_server_template.dart#relicServerTemplate`. Keep the normal and `--ui` variants runnable. Use `packages/trellis_cli/test/_e2e_server.dart#bootServer` for ports.
  - **Verify**: `cmd: CI=true dart test packages/trellis_cli/test/relic_e2e_test.dart --plain-name "Relic reload startup modes"` – boot the generated app across the flag, environment and default modes and check the real routes, served HTML and policy, including both 404s with development off.
  - **SATISFIES**: S02

- **TI03** The served development scaffold proves both asset reloads and strict CSP in a real browser.
  - Extend `packages/trellis_cli/test/_csp_browser.dart#expectBrowserReload` to wait on EventSource readiness and observe each navigation independently. Reuse `expectStrictCspApp` for the existing HTMX navigation path.
  - **Verify**: `cmd: CI=true dart test packages/trellis_cli/test/relic_e2e_test.dart` – on the scaffold's actual adapter check the wire MIME type, one observer connection with two separately delivered events before close, and two full reloads of the client page under strict CSP. Include the existing optional UI scaffold checks.
  - **SATISFIES**: S01, S03

- **TI04** The integration ships within the native Relic dependency boundary.
  - **Verify**: `cmd: test -z "$(git grep -E '^[[:space:]]+(shelf|trellis_shelf|trellis_dev):' -- packages/trellis_relic/pubspec.yaml)"` – the Relic pubspec stays independent of Shelf. Inspect the generated pubspec and serve entry and confirm its real browser test used the default I/O adapter.
  - **SATISFIES**: SC01

- **TI05** The development entry point, transport and verified TD-058 outcome are recorded.
  - **Verify**: `inspect: dev/architecture/system-architecture.md:215` – the reload flow and Current through marker agree with ADR-002’s Relic adapter note, Relic CLI and integration guides, affected package 0.15.0 entries, and the resolved TD-058 row.
  - **SATISFIES**: SC02

## Discovered Requirements

- **Title** Coalesce file-watch notifications from one save. **Description** A save must deliver
  one reload on the stable browser connection. **Rationale** One file append emitted multiple
  notifications on the real Relic socket. **Interpretation** Wait for a 50 ms quiet period across
  template and static watches. The browser proof separates saves with a reload and reconnect.
  **Traced from** TI01. **Date** 2026-11-20.

## Implementation Observations

- ASSUMPTION: Use one native registration call, `trellisDevReload(app, loader, staticDirectory: ...)`,
  and the standard root-relative routes. Revisit the API if a Relic application needs to mount
  reload under a path prefix.
- The independent review reproduced HTTP 500 for valid HTML with a document-declared charset
  and no HTTP charset. Script injection now preserves the original bytes in that case. The
  native socket proves the status, body bytes and unchanged Content-Type. Routing: Fix applied.
