# Changelog

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
