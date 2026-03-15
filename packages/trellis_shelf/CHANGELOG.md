# Changelog

# Changelog

## 0.1.0

- Added `trellisEngine()` middleware for injecting a Trellis engine into Shelf request context.
- Added `getEngine()` helper to retrieve the engine from request context.
- Added `trellisSecurityHeaders()` middleware with configurable X-Content-Type-Options, X-Frame-Options, Referrer-Policy, X-XSS-Protection, and Content-Security-Policy headers.
- Added `CspBuilder` for composable Content-Security-Policy configuration with sensible defaults.
- Added HTMX request helpers: `isHtmxRequest()`, `htmxTarget()`, `htmxTrigger()`, `isHtmxBoosted()`.
- Added `htmlResponse()` utility for `text/html; charset=utf-8` responses.
- Added `trellisCsrf()` middleware with HMAC-SHA256 double-submit cookie CSRF protection.
- Added `csrfToken()` helper to retrieve the CSRF token from request context.
- Added `renderPage()`, `renderFragment()`, `renderOobFragments()` response helpers with automatic CSRF token merging.
- Added `package:crypto` dependency for HMAC-SHA256 signing.
