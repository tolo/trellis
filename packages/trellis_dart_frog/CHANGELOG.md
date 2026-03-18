# Changelog

## 0.1.0

- `trellisProvider()` — Dart Frog middleware for Trellis engine injection via `context.read<Trellis>()`
- `renderPage()`, `renderFragment()`, `renderOobFragments()` — template rendering helpers accepting `RequestContext`
- `isHtmxRequest()`, `htmxTarget()`, `htmxTrigger()`, `isHtmxBoosted()` — HTMX request detection from Dart Frog request headers
- `trellisSecurityHeaders()` — security headers middleware (X-Content-Type-Options, X-Frame-Options, Referrer-Policy, X-XSS-Protection, Content-Security-Policy) bridged from `trellis_shelf`
- `trellisCsrf()` — CSRF protection middleware with HMAC-SHA256 double-submit cookie pattern; token available in template context as `csrfToken`
- `csrfToken()` — CSRF token extraction from request context
- `CspBuilder` — re-exported from `trellis_shelf` for CSP configuration without a direct `trellis_shelf` dependency
