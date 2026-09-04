# Changelog

## 0.11.1

### Added

- `htmxSource()` returns the id of the element that triggered the request on both HTMX 2 (`HX-Trigger` request
  header, bare id) and HTMX 4 (`HX-Source`, `tag#id`).

### Changed

- `htmxTarget()` also returns the target element's id under HTMX 4, extracting it from the `tag#id` value HTMX 4
  sends in `HX-Target`. Unchanged under HTMX 2.

### Deprecated

- `htmxTrigger()` – use `htmxSource()`. HTMX 4 reserves `HX-Trigger` for responses. The old name keeps working
  and reads `HX-Source` as well.

### Fixed

- README install snippet pinned `trellis_dart_frog: ^0.1.0` (and `trellis: ^0.8.0`); no published version of the package
  matches `^0.1.0`, so a copied snippet failed `dart pub get`. Both now track the lockstep version and
  `tool/version_lockstep.sh` keeps them current.

## 0.11.0

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.10.2

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.10.1

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.10.0

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.9.1

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.9.0

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.8.2

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.8.1

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.8.0

### Changed

- Version aligned to the unified Trellis SDK lockstep versioning scheme — all SDK packages now share a single version number and are released together. No functional changes since 0.1.0.

## 0.1.0

### Added

- `trellisProvider()` for exposing a `Trellis` engine through Dart Frog providers.
- `renderPage()`, `renderFragment()`, and `renderOobFragments()` for template rendering from `RequestContext`.
- HTMX request helpers: `isHtmxRequest()`, `htmxTarget()`, `htmxTrigger()`, and `isHtmxBoosted()`.
- `csrfToken()` and `CsrfToken` for reading the current token from request context.

### Security

- `trellisSecurityHeaders()` middleware bridged from `trellis_shelf`.
- `trellisCsrf()` middleware bridging the Shelf double-submit cookie implementation into Dart Frog.
- Re-export of `CspBuilder` so apps can configure CSP without importing `trellis_shelf` directly.
