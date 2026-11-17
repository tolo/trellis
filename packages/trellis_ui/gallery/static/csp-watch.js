window.trellisCspViolations = [];
document.addEventListener('securitypolicyviolation', function (event) {
  window.trellisCspViolations.push({directive: event.violatedDirective, blockedURI: event.blockedURI});
});
