# Changelog

## 0.1.0

### Added

- `renderPage()`, `renderFragment()`, and `renderOobFragments()` for rendering Trellis templates in Relic handlers.
- HTMX request helpers: `isHtmxRequest()`, `htmxTarget()`, `htmxTrigger()`, and `isHtmxBoosted()`.
- `htmlResponse()` for `text/html; charset=utf-8` Relic responses.

### Security

- `trellisSecurityHeaders()` middleware for applying standard response headers in matched Relic routes.
- `CspBuilder` for composing Content-Security-Policy directives in Relic applications.
