(function () {
  "use strict";

  /* Page-wide movement, loaded on every page (home and the content pages) so they all behave the same:
     - the reading progress bar under the header,
     - eased jumps for in-page links, landing just under the sticky header,
     - focus moves to the target after a jump, so keyboard users land there too,
     - back and forward put the reader back where they were.
     Reduce Motion gets the browser's own instant jump. */

  var reduceQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  var root = document.documentElement;

  /* ---------- Reading progress: one write per frame, from one scroll listener ---------- */
  var bar = document.querySelector(".progress");
  var maxScroll = 1;
  var queued = false;
  function measure() {
    maxScroll = Math.max(1, root.scrollHeight - window.innerHeight);
  }
  function paint() {
    queued = false;
    if (!bar) return;
    var p = Math.min(1, Math.max(0, window.scrollY / maxScroll));
    bar.style.transform = "scaleX(" + p.toFixed(4) + ")";
  }
  function queue() {
    if (queued) return;
    queued = true;
    requestAnimationFrame(paint);
  }
  measure();
  queue();
  window.addEventListener("scroll", queue, { passive: true });
  window.addEventListener("resize", function () { measure(); queue(); });
  window.addEventListener("load", function () { measure(); queue(); });

  /* ---------- Back and forward: the reader lands where they left the page ----------
     The browser's own restore runs as a smooth scroll here (html is smooth-scrolling) and can
     stop short while images load. So the page takes over: it remembers the offset when the page
     is left, and sets it back instantly on a back or forward visit. A link to a #section wins. */
  var SAVED = "inlet-y:" + location.pathname;
  var nav0 = performance.getEntriesByType ? performance.getEntriesByType("navigation")[0] : null;
  var backVisit = !!nav0 && nav0.type === "back_forward" && !location.hash;
  try { if ("scrollRestoration" in history) history.scrollRestoration = "manual"; } catch (err) { /* older browsers keep their own restore */ }
  function restoreOffset() {
    var y = 0;
    try { y = Number(sessionStorage.getItem(SAVED)) || 0; } catch (err) { y = 0; }
    if (y <= 0 || window.scrollY > 0) return;
    root.style.scrollBehavior = "auto";
    window.scrollTo(0, y);
    root.style.scrollBehavior = "";
  }
  window.addEventListener("pagehide", function () {
    try { sessionStorage.setItem(SAVED, String(window.scrollY)); } catch (err) { /* storage blocked: back starts at the top */ }
  });
  if (backVisit) {
    restoreOffset();
    window.addEventListener("load", restoreOffset, { once: true });
  }

  /* ---------- Anchor jumps ----------
     The landing point is the page's scroll-padding-top (set in motion.css), so the target's top edge
     sits one gap below the header. The glide is ease-in-out cubic, 480 to 980 ms by distance.
     Any wheel, touch, key or pointer input stops it and hands control back to the reader. */
  var glide = null;
  ["wheel", "touchstart", "keydown", "pointerdown"].forEach(function (type) {
    window.addEventListener(type, function () { glide = null; }, { passive: true });
  });

  function landingY(target) {
    var pad = parseFloat(getComputedStyle(root).scrollPaddingTop) || 0;
    var y = target.getBoundingClientRect().top + window.scrollY - pad;
    return Math.max(0, Math.min(y, root.scrollHeight - window.innerHeight));
  }

  function glideTo(y) {
    var from = window.scrollY, dist = y - from;
    if (Math.abs(dist) < 2) { window.scrollTo(0, y); return; }
    var dur = Math.min(980, Math.max(480, 420 + Math.abs(dist) * 0.3));
    var token = glide = {};
    var prev = root.style.scrollBehavior;
    var t0 = null;
    root.style.scrollBehavior = "auto"; // the CSS smooth scroll would fight every frame of this glide
    function step(now) {
      if (glide !== token) { root.style.scrollBehavior = prev; return; }
      if (t0 === null) t0 = now;
      var t = Math.min(1, (now - t0) / dur);
      var e = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
      window.scrollTo(0, from + dist * e);
      if (t < 1) { requestAnimationFrame(step); return; }
      glide = null;
      root.style.scrollBehavior = prev;
    }
    requestAnimationFrame(step);
  }

  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest('a[href^="#"]');
    if (!a || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    var id = a.getAttribute("href").slice(1);
    var target = id && document.getElementById(id);
    if (!target) return;
    if (!reduceQuery.matches) {
      e.preventDefault();
      history.pushState(null, "", "#" + id);
      glideTo(landingY(target));
    }
    if (!target.hasAttribute("tabindex")) {
      target.setAttribute("tabindex", "-1");
      target.addEventListener("blur", function () { target.removeAttribute("tabindex"); }, { once: true });
    }
    setTimeout(function () { target.focus({ preventScroll: true }); }, 0);
  });
})();
