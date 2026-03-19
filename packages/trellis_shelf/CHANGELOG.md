# Changelog

## 0.1.0

### Added

- `trellisEngine()` middleware for injecting a `Trellis` engine into the Shelf request context.
- `getEngine()` for retrieving the engine from request context inside handlers and utilities.
- `renderPage()`, `renderFragment()`, and `renderOobFragments()` response helpers that merge request-scoped values like `csrfToken`.
- HTMX request helpers: `isHtmxRequest()`, `htmxTarget()`, `htmxTrigger()`, and `isHtmxBoosted()`.
- `htmlResponse()` for `text/html; charset=utf-8` responses.

### Security

- `trellisSecurityHeaders()` middleware with configurable `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `X-XSS-Protection`, and `Content-Security-Policy`.
- `CspBuilder` for composing Content-Security-Policy directives with sensible defaults.
- `trellisCsrf()` middleware implementing HMAC-SHA256 double-submit cookie CSRF protection.
- `csrfToken()` for reading the current request token in handlers or templates.
