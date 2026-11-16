(function () {
  "use strict";

  /* Appearance control for the content pages (Features, Download, Changelog, FAQ, Privacy, Support).
     Same key and rules as js/site.js, so a choice made on one page holds on the others.
     Kept separate from site.js because the home page demos need elements these pages do not have. */
  var KEY = "inlet-page-theme";

  function setTheme(choice) {
    if (choice === "auto") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.setAttribute("data-theme", choice);
    Array.prototype.forEach.call(document.querySelectorAll("[data-theme-choice]"), function (b) {
      b.setAttribute("aria-pressed", String(b.dataset.themeChoice === choice));
    });
    try { localStorage.setItem(KEY, choice); } catch (err) { /* private window or blocked storage */ }
  }

  Array.prototype.forEach.call(document.querySelectorAll("[data-theme-choice]"), function (b) {
    b.addEventListener("click", function () { setTheme(b.dataset.themeChoice); });
  });

  var saved = "auto";
  try { saved = localStorage.getItem(KEY) || "auto"; } catch (err) { saved = "auto"; }
  setTheme(saved);
})();
