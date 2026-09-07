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

- README install snippet pinned `trellis_relic: ^0.1.0` (and `trellis: ^0.8.0`); no published version of the package
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

- `renderPage()`, `renderFragment()`, and `renderOobFragments()` for rendering Trellis templates in Relic handlers.
- HTMX request helpers: `isHtmxRequest()`, `htmxTarget()`, `htmxTrigger()`, and `isHtmxBoosted()`.
- `htmlResponse()` for `text/html; charset=utf-8` Relic responses.

### Security

- `trellisSecurityHeaders()` middleware for applying standard response headers in matched Relic routes.
- `CspBuilder` for composing Content-Security-Policy directives in Relic applications.
