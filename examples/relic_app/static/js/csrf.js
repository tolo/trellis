// Copies the csrf-token meta tag into the X-CSRF-Token header of every HTMX
// request (htmx 2 and htmx 4 event shapes). A file, not inline, for the CSP.
(function () {
  function setCsrfHeader(headers) {
    if (!headers) return;
    var token = document.querySelector('meta[name="csrf-token"]').content;
    if (token) headers['X-CSRF-Token'] = token;
  }
  document.addEventListener('htmx:configRequest', function(evt) { setCsrfHeader(evt.detail.headers); });
  document.addEventListener('htmx:config:request', function(evt) {
    setCsrfHeader(evt.detail.ctx.request.headers);
  });
})();
