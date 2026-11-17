/* Download flow helpers. Plain script, no dependencies, no network requests.
   Copy buttons put the disk image link on the clipboard. If the clipboard is not
   available (an old browser, or a page not served over HTTPS), the button says so and
   the link is still visible on the page. */
(function () {
  "use strict";

  var RESET_MS = 2000;

  function copyText(text) {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        return navigator.clipboard.writeText(text).then(
          function () { return true; },
          function () { return false; }
        );
      }
    } catch (err) {
      return Promise.resolve(false);
    }
    return Promise.resolve(false);
  }

  function setLabel(button, label) {
    button.textContent = label;
  }

  var buttons = document.querySelectorAll("[data-copy]");
  Array.prototype.forEach.call(buttons, function (button) {
    var original = button.textContent;
    var timer = null;

    button.addEventListener("click", function () {
      var value = button.getAttribute("data-copy");
      copyText(value).then(function (ok) {
        setLabel(button, ok ? "Link copied" : "Copy not available");
        if (timer) { clearTimeout(timer); }
        timer = setTimeout(function () {
          setLabel(button, original);
        }, RESET_MS);
      });
    });
  });
})();
