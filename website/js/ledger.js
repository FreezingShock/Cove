/* Ledger Tiles behavior: staggered reveals, drawn highlights, a live tile field in page heroes,
   a ticker that speeds up with scrolling, and a tile wipe between pages. Nothing here is required
   for content to show; Reduced Motion gets the final state straight away. */
(function () {
  "use strict";
  var reduce = window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches;
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  /* Reveal rows, cards and figures as they scroll in, staggered within their group. */
  var targets = $$(".card, .faq details, .panes li, .fact, .uc-item, .aud, .ms, .proof-item");
  targets.forEach(function (el) {
    var sib = el.parentElement ? Array.prototype.indexOf.call(el.parentElement.children, el) : 0;
    el.style.setProperty("--i", Math.min(sib, 6));
    if (!reduce) el.classList.add("lg-rv");
  });
  var io = "IntersectionObserver" in window && !reduce ? new IntersectionObserver(function (es) {
    es.forEach(function (e) {
      if (!e.isIntersecting) return;
      e.target.classList.add("on");
      e.target.classList.add("is-drawn");
      io.unobserve(e.target);
    });
  }, { threshold: 0.12, rootMargin: "0px 0px -6% 0px" }) : null;
  targets.concat($$(".hl")).forEach(function (el) {
    if (io) io.observe(el); else { el.classList.add("on"); el.classList.add("is-drawn"); }
  });

  /* A tile field under every page hero: dim cells drift, one aqua cell walks, hover lights cells. */
  $$(".page-hero").forEach(function (h) {
    if (h.querySelector(".tile-field")) return;
    var host = h.querySelector(".wrap") || h;
    var f = document.createElement("div");
    f.className = "tile-field";
    f.setAttribute("aria-hidden", "true");
    var cols = innerWidth < 700 ? 8 : 16, rows = innerWidth < 700 ? 2 : 3;
    var cells = [];
    for (var i = 0; i < cols * rows; i++) {
      var c = document.createElement("i");
      var r = Math.random();
      if (r < 0.06) c.className = "ink"; else if (r < 0.36) c.className = "dim";
      f.appendChild(c); cells.push(c);
    }
    host.appendChild(f);
    var last = null;
    function step() {
      if (document.hidden) return;
      if (last) last.classList.remove("lit");
      last = cells[(Math.random() * cells.length) | 0];
      last.classList.add("lit");
    }
    if (reduce) { cells[cols + 3].classList.add("lit"); return; }
    step();
    setInterval(step, 900);
    f.addEventListener("pointermove", function (e) {
      var t = e.target;
      if (t.tagName === "I" && !t.classList.contains("lit")) {
        t.classList.add("lit");
        setTimeout(function () { if (t !== last) t.classList.remove("lit"); }, 160);
      }
    });
  });

  /* The ticker runs faster the harder you scroll, then settles. */
  var track = document.querySelector(".lit-band-track");
  if (track && !reduce && track.getAnimations) {
    var anim = null, speed = 1, lastY = scrollY, lastT = performance.now();
    var loop = function (now) {
      var dy = Math.abs(scrollY - lastY), dt = Math.max(16, now - lastT);
      lastY = scrollY; lastT = now;
      var target = 1 + Math.min(7, (dy / dt) * 4);
      speed += (target - speed) * (target > speed ? 0.25 : 0.04);
      if (!anim) anim = track.getAnimations()[0];
      if (anim) anim.playbackRate = speed;
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  }

  /* Tile wipe between pages. Square cells grow out from the click; the next page clears them. */
  var wipe;
  function build(ox, oy) {
    if (!wipe) { wipe = document.createElement("div"); wipe.id = "lg-wipe"; wipe.setAttribute("aria-hidden", "true"); document.body.appendChild(wipe); }
    var cs = Math.max(56, Math.round(innerWidth / 14));
    var c = Math.ceil(innerWidth / cs), r = Math.ceil(innerHeight / cs), cells = [], max = 1;
    wipe.style.setProperty("--tc", c);
    wipe.style.gridTemplateRows = "repeat(" + r + ", 1fr)";
    wipe.innerHTML = "";
    for (var y = 0; y < r; y++) for (var x = 0; x < c; x++) {
      var i = document.createElement("i");
      var d = Math.hypot(x * cs + cs / 2 - ox, y * cs + cs / 2 - oy);
      i.dataset.d = d; max = Math.max(max, d);
      if ((x * 3 + y) % 7 === 0) i.className = "lit";
      wipe.appendChild(i); cells.push(i);
    }
    cells.forEach(function (i) { i.style.transitionDelay = (i.dataset.d / max) * 220 + "ms"; });
    wipe.style.display = "grid";
    return { cells: cells, max: max };
  }
  if (!reduce) {
    document.addEventListener("click", function (e) {
      var a = e.target.closest && e.target.closest("a[href]");
      if (!a || e.defaultPrevented || e.button || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      if (a.target || a.hasAttribute("download")) return;
      var u = new URL(a.href, location.href);
      if (u.origin !== location.origin || !/\.html?$|\/$/.test(u.pathname) || u.pathname === location.pathname) return;
      e.preventDefault();
      var ox = e.clientX || innerWidth / 2, oy = e.clientY || innerHeight / 2;
      var w = build(ox, oy);
      requestAnimationFrame(function () { requestAnimationFrame(function () { w.cells.forEach(function (i) { i.classList.add("on"); }); }); });
      try { sessionStorage.setItem("lg-wipe", ox + "," + oy); } catch (x) { /* no storage: plain navigation */ }
      setTimeout(function () { location.href = a.href; }, 340);
    });
    var from;
    try { from = sessionStorage.getItem("lg-wipe"); sessionStorage.removeItem("lg-wipe"); } catch (x) { /* none */ }
    if (from) {
      var p = from.split(","), w2 = build(+p[0], +p[1]);
      w2.cells.forEach(function (i) { i.classList.add("on"); i.style.transition = "none"; });
      requestAnimationFrame(function () { requestAnimationFrame(function () {
        w2.cells.forEach(function (i) { i.style.transition = ""; i.style.transitionDelay = ((w2.max - i.dataset.d) / w2.max) * 220 + "ms"; i.classList.remove("on"); });
        setTimeout(function () { wipe.style.display = "none"; }, 560);
      }); });
    }
  }
  window.addEventListener("pageshow", function (e) { if (e.persisted && wipe) wipe.style.display = "none"; });
})();
