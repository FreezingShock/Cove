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

  // Release details come from release.json. The Website workflow adds it beside the page
  // when it deploys. If the file is missing (for example, the page opened from disk),
  // the built-in version stays and the size stays hidden.
  function megabytes(bytes) {
    return (bytes / 1048576).toFixed(1) + " MB";
  }

  function showRelease(info) {
    if (!info) { return; }
    if (typeof info.version === "string" && /^[0-9][0-9.]*$/.test(info.version)) {
      Array.prototype.forEach.call(document.querySelectorAll('[data-release="version"]'), function (el) {
        el.textContent = "Version " + info.version;
      });
    }
    if (typeof info.dmg_bytes === "number" && info.dmg_bytes > 0) {
      Array.prototype.forEach.call(document.querySelectorAll('[data-release="size"]'), function (el) {
        el.textContent = megabytes(info.dmg_bytes);
        el.hidden = false;
      });
    }
  }

  try {
    fetch("release.json", { cache: "no-cache" })
      .then(function (res) { return res.ok ? res.json() : null; })
      .then(showRelease)
      .catch(function () { /* keep the built-in text */ });
  } catch (err) {
    /* fetch is unavailable: keep the built-in text */
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
