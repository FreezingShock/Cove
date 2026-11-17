(function () {
  "use strict";

  /* Content pages: Features, Download, Changelog, FAQ, Privacy, Support.
     Same theme key and rules as js/site.js, so a choice made on one page holds on the others.
     Kept separate from site.js because the home page demos need elements these pages do not have. */
  var KEY = "inlet-page-theme";

  /* ---------- Appearance control ---------- */
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

  /* ---------- Header: a hairline once the page has moved ---------- */
  var nav = document.querySelector(".nav");
  var ticking = false;
  function onScroll() {
    ticking = false;
    if (nav) nav.classList.toggle("is-scrolled", window.scrollY > 8);
  }
  window.addEventListener("scroll", function () {
    if (!ticking) { ticking = true; requestAnimationFrame(onScroll); }
  }, { passive: true });
  onScroll();

  /* ---------- On-page jump list: mark the section in view ---------- */
  var jumps = Array.prototype.slice.call(document.querySelectorAll(".on-page a[href^='#']"));
  if (jumps.length && "IntersectionObserver" in window) {
    var spy = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        jumps.forEach(function (a) {
          if (a.getAttribute("href") === "#" + en.target.id) a.setAttribute("aria-current", "true");
          else a.removeAttribute("aria-current");
        });
      });
    }, { rootMargin: "-40% 0px -55% 0px" });
    jumps.forEach(function (a) {
      var t = document.getElementById(a.getAttribute("href").slice(1));
      if (t) spy.observe(t);
    });
  }

  /* ---------- FAQ search: filters questions and answers as you type ---------- */
  var filter = document.getElementById("faqFilter");
  if (filter) {
    var items = Array.prototype.slice.call(document.querySelectorAll(".faq details"));
    var groups = Array.prototype.slice.call(document.querySelectorAll(".faq-group"));
    var empty = document.getElementById("faqEmpty");
    var count = document.getElementById("faqCount");
    filter.addEventListener("input", function () {
      var q = filter.value.trim().toLowerCase();
      var shown = 0;
      items.forEach(function (d) {
        var hit = !q || d.textContent.toLowerCase().indexOf(q) !== -1;
        d.hidden = !hit;
        if (hit) shown++;
        if (q && hit) d.open = true;
      });
      groups.forEach(function (g) {
        var any = g.querySelector("details:not([hidden])");
        g.hidden = !any;
      });
      if (empty) empty.hidden = shown !== 0;
      // Live count under the field: "Showing 3 of 24 questions", so the reader sees the filter work.
      if (count) {
        count.hidden = !q;
        count.textContent = "Showing " + shown + " of " + items.length + (shown === 1 ? " question" : " questions");
      }
    });
  }
})();
