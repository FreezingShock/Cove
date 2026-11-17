(function () {
  "use strict";

  var reduceQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  var hasIO = "IntersectionObserver" in window;
  var nav = document.querySelector(".nav");

  /* ---------- Frame loop: one rAF per scroll burst, reads then writes ---------- */
  var queued = false;
  var frameHooks = [];
  function requestFrame() {
    if (queued) return;
    queued = true;
    requestAnimationFrame(function () {
      queued = false;
      for (var i = 0; i < frameHooks.length; i++) frameHooks[i]();
    });
  }
  window.addEventListener("scroll", requestFrame, { passive: true });
  window.addEventListener("resize", function () { layoutScrub(); requestFrame(); });

  /* ---------- Sticky header: a hairline and blur once the page has moved ---------- */
  frameHooks.push(function () {
    if (nav) nav.classList.toggle("is-scrolled", window.scrollY > 8);
  });

  /* ---------- Anchor jumps: move focus to the target so keyboard users land there ---------- */
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest('a[href^="#"]');
    if (!a) return;
    var id = a.getAttribute("href").slice(1);
    var target = id && document.getElementById(id);
    if (!target) return;
    if (!target.hasAttribute("tabindex")) {
      target.setAttribute("tabindex", "-1");
      target.addEventListener("blur", function () { target.removeAttribute("tabindex"); }, { once: true });
    }
    setTimeout(function () { target.focus({ preventScroll: true }); }, 0);
  });

  /* ---------- Scroll-spy: the nav link for the section in view gets aria-current ---------- */
  var links = Array.prototype.slice.call(document.querySelectorAll('.links a[href^="#"]'));
  function currentId() {
    var on = links.filter(function (a) { return a.getAttribute("aria-current") === "true"; })[0];
    return on ? on.getAttribute("href").slice(1) : "";
  }
  function setCurrent(id) {
    links.forEach(function (a) {
      if (a.getAttribute("href") === "#" + id) a.setAttribute("aria-current", "true");
      else a.removeAttribute("aria-current");
    });
  }
  if (hasIO && links.length) {
    var spy = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) setCurrent(en.target.id);
        else if (en.target.id === currentId()) setCurrent("");
      });
    }, { rootMargin: "-45% 0px -50% 0px" });
    links.forEach(function (a) {
      var el = document.getElementById(a.getAttribute("href").slice(1));
      if (el) spy.observe(el);
    });
  }

  /* ---------- Reveal: blocks rise in once when they enter the screen ---------- */
  var REVEAL = ".feature .copy, .feature .stage, .privacy-head, .fact, .get-box, .recipe, .proof-item, .uses-head, .showcase-head, .facts";
  var revealTargets = Array.prototype.slice.call(document.querySelectorAll(REVEAL));
  if (hasIO && !reduceQuery.matches) {
    revealTargets.forEach(function (el, i) {
      el.classList.add("reveal");
      // Facts sit in two columns on desktop, so stagger them by column.
      if (el.classList.contains("fact")) el.style.setProperty("--d", ((i % 2) * 90) + "ms");
    });
    var rio = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        en.target.classList.add("is-in");
        rio.unobserve(en.target);
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -6% 0px" });
    revealTargets.forEach(function (el) { rio.observe(el); });
  }

  /* ---------- Pinned demo: the section sticks and the video scrubs with scroll ---------- */
  var demo = document.getElementById("demoVideo");
  var track = document.querySelector("[data-scrub]");
  var sticky = track && track.querySelector(".scrub-sticky");
  var inner = track && track.querySelector(".scrub-inner");
  var steps = track ? Array.prototype.slice.call(track.querySelectorAll(".scrub-steps li")) : [];
  var bar = track ? track.querySelector(".scrub-bar i") : null;
  var pinned = false;
  var activeStep = -1;

  // The video is 0.7 MB, so it loads only when the demo section gets close to the
  // screen, not on page load. Scrubbing starts once it has loaded.
  var videoArmed = false;
  function loadDemoWhenNear() {
    if (videoArmed) return;
    videoArmed = true;
    function load() {
      demo.preload = "auto";
      if (demo.readyState === 0) demo.load();
    }
    if (!hasIO) { load(); return; }
    var near = new IntersectionObserver(function (entries) {
      if (!entries.some(function (en) { return en.isIntersecting; })) return;
      near.disconnect();
      load();
    }, { rootMargin: "400px 0px" });
    near.observe(track);
  }

  function setPinned(on) {
    if (on === pinned) return;
    pinned = on;
    if (on) {
      demo.dataset.scrub = "on";            // site.js reads this and skips autoplay
      demo.pause();
      loadDemoWhenNear();
    } else {
      delete demo.dataset.scrub;
      activeStep = -1;
    }
  }

  // The sticky block pins just below the header. Its height is the viewport minus the header.
  var navH = 0, stickyH = 0;

  function layoutScrub() {
    if (!track || !demo) return;
    navH = nav ? Math.round(nav.getBoundingClientRect().height) : 0;
    stickyH = window.innerHeight - navH;
    track.style.setProperty("--nav-h", navH + "px");
    track.classList.remove("is-pinned");
    track.style.height = "";
    // Lite and static tiers play the demo as a plain video: no pin, no per-frame seeks.
    if (reduceQuery.matches || document.documentElement.getAttribute("data-motion") === "lite") { track.classList.remove("is-pinned"); setPinned(false); return; }
    // Pin only when the whole sticky block fits below the header, so nothing gets cut off.
    track.classList.add("is-pinned");
    var fits = inner.offsetHeight <= stickyH;
    if (!fits) {
      track.classList.remove("is-pinned");
      setPinned(false);
      return;
    }
    track.style.height = (stickyH + window.innerHeight * 2) + "px"; // sticky block + 2 viewports of scroll
    setPinned(true);
    requestFrame();
  }

  function updateScrub() {
    var r = track.getBoundingClientRect();
    var span = track.offsetHeight - stickyH;
    var p = span > 0 ? Math.min(1, Math.max(0, (navH - r.top) / span)) : 0;

    if (bar) bar.style.transform = "scaleX(" + p.toFixed(4) + ")";

    var idx = p < 0.34 ? 0 : (p < 0.67 ? 1 : 2);
    if (idx !== activeStep) {
      activeStep = idx;
      steps.forEach(function (li, i) {
        li.classList.toggle("is-active", i === idx);
        if (i === idx) li.setAttribute("aria-current", "step");
        else li.removeAttribute("aria-current");
      });
    }

    // Seek only when the last seek has finished, so seeks never pile up.
    if (demo.readyState >= 1 && !demo.seeking && isFinite(demo.duration)) {
      var t = p * Math.max(0, demo.duration - 0.05);
      if (Math.abs(t - demo.currentTime) > 0.016) demo.currentTime = t;
    }
  }

  if (demo && track) {
    // Tier changes (frame probe, Reduce Motion) re-check whether the pin is allowed.
    window.addEventListener("inlet:tier", layoutScrub);
    frameHooks.push(function () { if (pinned) updateScrub(); });
    demo.addEventListener("seeked", function () { if (pinned) requestFrame(); });
    reduceQuery.addEventListener("change", layoutScrub);
    layoutScrub();
  }
})();
