(function () {
  "use strict";

  /* Motion system: tier, first-visit intro, page changes, and pointer feel.
     Everything here adds motion on top of a page that already works. The head
     script sets the first tier and the intro mode before paint; this file refines
     them (frame probe, live Reduce Motion changes) and runs the animations.
     Animated properties: opacity, translate, scale, rotate. Nothing reflows. */

  var doc = document.documentElement;
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
  var fine = window.matchMedia("(hover: hover) and (pointer: fine)");
  var conn = navigator.connection || {};
  var canLinear = !!(window.CSS && CSS.supports && CSS.supports("transition-timing-function", "linear(0, 1)"));

  /* ---------- Tier: full, lite (fewer effects) or static (none) ---------- */
  var slow = false;
  function lowPower() {
    return !!conn.saveData
      || (typeof navigator.deviceMemory === "number" && navigator.deviceMemory <= 2)
      || (typeof navigator.hardwareConcurrency === "number" && navigator.hardwareConcurrency <= 2);
  }
  function tierNow() {
    if (reduce.matches) return "static";
    return slow || lowPower() ? "lite" : "full";
  }
  var tier = "full";
  function setTier(t) {
    if (t === tier && doc.getAttribute("data-motion") === t) return;
    tier = t;
    doc.setAttribute("data-motion", t);
    window.dispatchEvent(new Event("inlet:tier"));
  }
  setTier(tierNow());
  reduce.addEventListener("change", function () { setTier(tierNow()); });

  /* Frame probe: 24 frames after load. A median frame over 24 ms (under about 40 fps)
     drops the page to lite. Probes only run when the tier is full. */
  function probeFrames() {
    if (tier !== "full") return;
    var last = 0, deltas = [], n = 0;
    function tick(t) {
      if (last) deltas.push(t - last);
      last = t;
      if (++n <= 24) { requestAnimationFrame(tick); return; }
      deltas.sort(function (a, b) { return a - b; });
      slow = deltas[deltas.length >> 1] > 24;
      if (slow) setTier(tierNow());
    }
    requestAnimationFrame(tick);
  }

  /* ---------- Tokens: read from tokens.css, which is generated from design/tokens.json ---------- */
  function token(name, fallback) {
    var v = getComputedStyle(doc).getPropertyValue(name).trim();
    return v || fallback;
  }
  function ms(name, fallback) { return parseFloat(token(name, fallback)) * 1000; }
  var EASE = token("--ease-standard", "cubic-bezier(0.2, 0.8, 0.2, 1)");
  var SPRING_OPEN = canLinear ? token("--spring-open", EASE) : EASE;
  var SPRING_OPEN_MS = canLinear ? ms("--spring-open-dur", "0.593s") : ms("--dur-slow", "0.5s");
  var SPRING_RISE = canLinear ? token("--spring-rise", EASE) : EASE;
  var SPRING_RISE_MS = canLinear ? ms("--spring-rise-dur", "0.825s") : ms("--dur-slower", "0.8s");

  /* ---------- Intro: first visit plays the full sequence, later loads in the tab play a soft fade ---------- */
  var heroTitle = document.querySelector(".hero-title");

  function splitWords(el) {
    var words = [];
    (function walk(node) {
      Array.prototype.slice.call(node.childNodes).forEach(function (c) {
        if (c.nodeType === 3) {
          var frag = document.createDocumentFragment();
          c.textContent.split(/(\s+)/).forEach(function (part) {
            if (!part) return;
            if (/^\s+$/.test(part)) { frag.appendChild(document.createTextNode(" ")); return; }
            var s = document.createElement("span");
            s.className = "w";
            s.textContent = part;
            frag.appendChild(s);
            words.push(s);
          });
          node.replaceChild(frag, c);
        } else if (c.nodeType === 1 && c.tagName !== "BR") {
          walk(c);
        }
      });
    })(el);
    return words;
  }

  // fill "backwards" only: the from-state holds during the delay, and the element's own CSS takes over at the end.
  function anim(el, frames, opts) {
    if (!el || !el.animate) return null;
    opts.fill = "backwards";
    return el.animate(frames, opts);
  }

  function playIntro(mode) {
    var q = function (s) { return document.querySelector(s); };
    var nav = q(".nav"), icon = q(".hero-icon"), lede = q(".hero-lede");
    var cta = q(".hero-cta"), note = q(".hero-note"), wrap = q(".hero-stage-wrap");
    var words = mode === "full" && heroTitle ? splitWords(heroTitle) : [];

    try { sessionStorage.setItem("inlet-intro", "1"); } catch (e) { /* storage blocked: the next load plays the full intro again */ }

    if (mode === "full") {
      anim(nav, [{ opacity: 0, translate: "0 -14px" }, { opacity: 1, translate: "0 0" }],
        { duration: 600, easing: EASE, delay: 0 });
      anim(icon, [{ opacity: 0, scale: "0.5", rotate: "-14deg" }, { opacity: 1, scale: "1", rotate: "0deg" }],
        { duration: SPRING_OPEN_MS, easing: SPRING_OPEN, delay: 60 });
      words.forEach(function (w, i) {
        anim(w, [{ opacity: 0, translate: "0 0.45em" }, { opacity: 1, translate: "0 0" }],
          { duration: 640, easing: EASE, delay: 260 + i * 42 });
      });
      var after = 260 + words.length * 42 - 140;
      [lede, cta, note].forEach(function (el, i) {
        anim(el, [{ opacity: 0, translate: "0 14px" }, { opacity: 1, translate: "0 0" }],
          { duration: 620, easing: EASE, delay: after + i * 110 });
      });
      anim(wrap, [{ opacity: 0, translate: "0 56px", scale: "0.97" }, { opacity: 1, translate: "0 0", scale: "1" }],
        { duration: SPRING_RISE_MS, easing: SPRING_RISE, delay: 420 });
    } else {
      [nav, icon, heroTitle, lede, cta, note, wrap].forEach(function (el, i) {
        anim(el, [{ opacity: 0, translate: "0 6px" }, { opacity: 1, translate: "0 0" }],
          { duration: 360, easing: EASE, delay: i * 20 });
      });
    }
    // Hidden only until the animations exist. With backwards fill they hold the from-state, so nothing flashes.
    doc.classList.remove("intro-pending");
    doc.removeAttribute("data-intro");
  }

  var introMode = doc.getAttribute("data-intro");
  if (doc.classList.contains("intro-pending")) {
    if (!heroTitle || tier === "static") {
      doc.classList.remove("intro-pending");
    } else {
      playIntro(tier === "lite" ? "soft" : introMode === "soft" ? "soft" : "full");
    }
  }

  /* ---------- Page changes: View Transitions where they exist, a short fade elsewhere ----------
     Cross-document transitions are declared in motion.css (@view-transition). Browsers
     without them get a fade out before a same-site link, and a fade in on arrival. */
  var hasVT = "startViewTransition" in document;
  if (!hasVT && tier !== "static") doc.classList.add("page-enter");
  function samePage(url) {
    function norm(p) { return p.replace(/index\.html$/, ""); }
    return norm(url.pathname) === norm(location.pathname) && url.search === location.search;
  }
  document.addEventListener("click", function (e) {
    if (hasVT || tier === "static") return;
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    var a = e.target.closest && e.target.closest("a[href]");
    if (!a || a.hasAttribute("download") || (a.target && a.target !== "_self")) return;
    if (a.getAttribute("href").charAt(0) === "#") return;
    var url;
    try { url = new URL(a.href); } catch (err) { return; }
    if (url.origin !== location.origin || samePage(url)) return;
    e.preventDefault();
    doc.classList.add("is-leaving");
    setTimeout(function () { location.href = url.href; }, 190);
  });
  window.addEventListener("pageshow", function (e) {
    if (e.persisted) doc.classList.remove("is-leaving", "page-enter");
  });

  /* ---------- Pointer feel: magnetic buttons and a light that follows the cursor on panels ---------- */
  var magnets = [], spots = [];
  function bindPointer() {
    if (!fine.matches || tier !== "full") return;
    magnets = Array.prototype.slice.call(document.querySelectorAll("main .btn-primary"));
    magnets.forEach(function (el) {
      el.classList.add("magnet");
      el.addEventListener("pointerleave", function () { el.style.translate = ""; });
    });
    spots = Array.prototype.slice.call(document.querySelectorAll(".mcard, .get-box, .recipe-ui, .stage"));
    spots.forEach(function (el) { el.classList.add("spot"); });

    var raf = 0, last = null;
    document.addEventListener("pointermove", function (e) {
      if (tier !== "full") return;
      last = e;
      if (raf) return;
      raf = requestAnimationFrame(function () {
        raf = 0;
        var ev = last;
        var spot = ev.target.closest && ev.target.closest(".spot");
        if (spot) {
          var r = spot.getBoundingClientRect();
          spot.style.setProperty("--sx", (ev.clientX - r.left).toFixed(1) + "px");
          spot.style.setProperty("--sy", (ev.clientY - r.top).toFixed(1) + "px");
        }
        var mag = ev.target.closest && ev.target.closest(".magnet");
        if (mag) {
          var m = mag.getBoundingClientRect();
          var dx = (ev.clientX - (m.left + m.width / 2)) * 0.2;
          var dy = (ev.clientY - (m.top + m.height / 2)) * 0.2;
          mag.style.translate = dx.toFixed(1) + "px " + dy.toFixed(1) + "px";
        }
      });
    }, { passive: true });
  }

  /* ---------- Scroll progress: a 2 px bar under the header, drawn by a scroll timeline in motion.css ---------- */
  function addProgress() {
    if (tier !== "full" || !(window.CSS && CSS.supports && CSS.supports("animation-timeline", "scroll()"))) return;
    var bar = document.createElement("div");
    bar.className = "progress";
    bar.setAttribute("aria-hidden", "true");
    document.body.appendChild(bar);
  }

  /* Tier changes can come from the probe or from Reduce Motion, so re-check the pointer features then too. */
  window.addEventListener("inlet:tier", function () {
    if (tier !== "full") {
      magnets.forEach(function (el) { el.style.translate = ""; });
    }
  });

  bindPointer();
  addProgress();
  probeFrames();
})();
