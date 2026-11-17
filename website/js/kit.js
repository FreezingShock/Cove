(function () {
  "use strict";

  /* Inlet motion kit (style E, Ledger Tiles). One small layer shared by every page:
       - scroll velocity, smoothed, as InletKit.vel (0 to 1) and the --vel custom property
       - a tile field: square cells on hairlines, seeded dim flips, a walking aqua tile,
         a load sequence, a faster reload shuffle, all speeding up with scroll
       - a tile wipe between pages, spreading from the clicked link
       - a ticker whose speed and direction follow the scroll
       - staggered reveals that tighten up when you scroll fast
     Tiers come from motion.js (html[data-motion]): full runs everything, lite draws
     the tile field once and steps its lit tile on a slow timer (no frame loop, no
     wipe), static draws one still frame. Durations come from tokens.css. */

  var doc = document.documentElement;
  var DPR_CAP = 2;
  var kit = window.InletKit = { vel: 0, speed: 1, tier: tierNow() };

  function tierNow() { return doc.getAttribute("data-motion") || "full"; }
  window.addEventListener("inlet:tier", function () { kit.tier = tierNow(); refreshAll(); });

  /* ---------- Small helpers ---------- */
  function mulberry(seed) {
    var a = seed >>> 0;
    return function () {
      a = (a + 0x6D2B79F5) >>> 0;
      var t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  function hash(s) {
    var h = 2166136261;
    for (var i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
    return h >>> 0;
  }
  function cssMs(name, fallback) {
    var v = parseFloat(getComputedStyle(doc).getPropertyValue(name));
    return (isNaN(v) ? fallback : v) * 1000;
  }
  function isDark() {
    var t = doc.getAttribute("data-theme");
    if (t) return t === "dark";
    return window.matchMedia("(prefers-color-scheme: dark)").matches;
  }
  function colors() {
    var cs = getComputedStyle(doc);
    var g = function (n, f) { return cs.getPropertyValue(n).trim() || f; };
    var dark = isDark();
    return {
      dark: dark,
      accent: g("--accent", "#46E6D6"),
      ink: g("--text", dark ? "#F4EFE6" : "#17150F"),
      tile: dark ? "#1B201E" : "#17150F",
      hair: g("--hair", "rgba(60,45,20,.13)")
    };
  }
  var DPR = Math.min(window.devicePixelRatio || 1, DPR_CAP);

  /* ---------- One frame loop for everything that animates ---------- */
  var jobs = [], rafId = 0, lastT = 0;
  function addJob(fn) { if (jobs.indexOf(fn) < 0) jobs.push(fn); wake(); }
  function dropJob(fn) { var i = jobs.indexOf(fn); if (i >= 0) jobs.splice(i, 1); }
  function wake() { if (!rafId && jobs.length && !document.hidden) { lastT = 0; rafId = requestAnimationFrame(frame); } }
  function frame(t) {
    rafId = 0;
    var dt = lastT ? Math.min(64, t - lastT) : 16;
    lastT = t;
    for (var i = jobs.length - 1; i >= 0; i--) {
      if (jobs[i](dt, t) === false) jobs.splice(i, 1);
    }
    if (jobs.length) rafId = requestAnimationFrame(frame);
  }
  document.addEventListener("visibilitychange", function () { if (!document.hidden) wake(); });

  /* ---------- Scroll velocity: px per ms, smoothed, capped to 0..1 ---------- */
  var lastY = window.scrollY, lastYT = performance.now(), rawV = 0, dir = 1;
  window.addEventListener("scroll", function () {
    var now = performance.now(), y = window.scrollY, dt = Math.max(1, now - lastYT);
    var v = (y - lastY) / dt;
    lastY = y; lastYT = now;
    if (Math.abs(v) > 0.01) dir = v > 0 ? 1 : -1;
    rawV = Math.min(1, Math.abs(v) / 2.5);
    addJob(velJob);
  }, { passive: true });
  function velJob(dt) {
    rawV *= Math.pow(0.5, dt / 140);            // the push fades out
    kit.vel += (rawV - kit.vel) * (rawV > kit.vel ? 0.4 : 0.08);
    if (kit.vel < 0.004 && rawV < 0.004) { kit.vel = 0; kit.speed = 1; doc.style.setProperty("--vel", "0"); return false; }
    kit.speed = 1 + kit.vel * 5;
    doc.style.setProperty("--vel", kit.vel.toFixed(3));
    return true;
  }
  kit.dir = function () { return dir; };

  /* ==========================================================================
     Tile field
     ========================================================================== */
  var fields = [];
  var reloaded = (function () {
    try { var n = performance.getEntriesByType("navigation")[0]; return !!n && n.type === "reload"; } catch (e) { return false; }
  })();
  var booted = false;

  function Field(host, idx) {
    this.host = host;
    this.canvas = document.createElement("canvas");
    this.canvas.className = "kit-tiles";
    this.canvas.setAttribute("aria-hidden", "true");
    host.insertBefore(this.canvas, host.firstChild);
    host.classList.add("kit-host");
    this.ctx = this.canvas.getContext("2d");
    this.seed = hash(location.pathname + "#" + idx);
    this.rand = mulberry((Math.random() * 4294967296) >>> 0);   // runtime randomness
    this.visible = false;
    this.clock = 0; this.nextFlip = 400; this.nextStep = 900;
    this.dirty = true;
    this.mode = host.getAttribute("data-tiles") || "";
    this.size();
    var self = this;
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (es) {
        self.visible = es[es.length - 1].isIntersecting;
        if (self.visible) self.start();
      }, { rootMargin: "80px" }).observe(host);
    } else { this.visible = true; }
    this.step = function (dt) { return self.tick(dt); };
  }

  Field.prototype.size = function () {
    var r = this.host.getBoundingClientRect();
    var w = Math.max(1, Math.round(r.width)), h = Math.max(1, Math.round(r.height));
    var cs = w < 700 ? 40 : 56;
    this.cs = cs;
    this.cols = Math.ceil(w / cs); this.rows = Math.ceil(h / cs);
    this.canvas.width = Math.round(w * DPR); this.canvas.height = Math.round(h * DPR);
    this.w = w; this.h = h;
    var n = this.cols * this.rows, srnd = mulberry(this.seed);
    this.v = new Float32Array(n); this.t = new Float32Array(n);
    this.delay = new Float32Array(n);
    this.dimmed = new Uint8Array(n);
    for (var i = 0; i < n; i++) {
      this.dimmed[i] = srnd() < 0.34 ? 1 : 0;
      var x = i % this.cols, y = (i / this.cols) | 0;
      this.delay[i] = reloaded ? srnd() * 520 : (x + y) * 38 + srnd() * 90;   // load: diagonal sweep. reload: shuffle
      this.t[i] = this.dimmed[i];
    }
    this.hair = 0;
    this.walker = (this.cols * 2 + Math.min(this.cols - 1, 3)) % n;
    this.trail = new Float32Array(n);
    this.loadT = 0;
    this.col = colors();
    this.dirty = true;
  };

  Field.prototype.start = function () {
    if (kit.tier === "full") addJob(this.step);
    else this.still();
  };

  Field.prototype.neighbor = function () {
    var c = this.cols, n = this.v.length, i = this.walker, x = i % c, y = (i / c) | 0;
    var opts = [];
    if (x > 0) opts.push(i - 1);
    if (x < c - 1) opts.push(i + 1);
    if (y > 0) opts.push(i - c);
    if (y < this.rows - 1) opts.push(i + c);
    return opts.length ? opts[(this.rand() * opts.length) | 0] : i;
  };

  Field.prototype.tick = function (dt) {
    if (!this.visible || kit.tier !== "full") { return false; }
    var sp = kit.speed, r = this.rand, n = this.v.length, i;
    this.clock += dt; this.loadT += dt;
    // events fire faster the faster you scroll
    this.nextFlip -= dt * sp; this.nextStep -= dt * sp;
    if (this.loadT > 700) {
      while (this.nextFlip <= 0) {
        var k = (r() * n) | 0;
        this.t[k] = this.t[k] > 0.5 ? (this.dimmed[k] ? 0 : 0) : 1;
        this.nextFlip += 160 + r() * 380;
      }
      if (this.nextStep <= 0) {
        this.walker = this.neighbor();
        this.trail[this.walker] = 1;
        this.nextStep += 1100 + r() * 700;
      }
    }
    var ease = 1 - Math.exp(-dt * 0.006 * sp);
    var changed = false;
    for (i = 0; i < n; i++) {
      var tgt = this.loadT > this.delay[i] ? this.t[i] : 0;
      var d = tgt - this.v[i];
      if (d > 0.002 || d < -0.002) { this.v[i] += d * ease; changed = true; }
      if (this.trail[i] > 0.002) { this.trail[i] *= Math.exp(-dt * 0.0018 * sp); changed = true; }
    }
    var hairT = this.loadT > 120 ? 1 : 0;
    if (this.hair < hairT - 0.01) { this.hair += (hairT - this.hair) * ease; changed = true; }
    if (changed || this.dirty) this.draw();
    return true;
  };

  Field.prototype.draw = function () {
    var ctx = this.ctx, cs = this.cs, c = this.cols, col = this.col;
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.clearRect(0, 0, this.w, this.h);
    var dimA = col.dark ? 0.05 : 0.04, litA = col.dark ? 0.32 : 0.9;
    ctx.fillStyle = col.ink;
    ctx.globalAlpha = dimA;
    var i, n = this.v.length;
    for (i = 0; i < n; i++) {
      var v = this.v[i];
      if (v > 0.01) {
        ctx.globalAlpha = dimA * v;
        ctx.fillRect((i % c) * cs + 1, ((i / c) | 0) * cs + 1, cs - 1, cs - 1);
      }
    }
    // hairlines
    ctx.globalAlpha = this.hair * (col.dark ? 0.12 : 0.13);
    ctx.fillStyle = col.ink;
    for (var x = 0; x <= c; x++) ctx.fillRect(x * cs, 0, 1, this.h);
    for (var y = 0; y <= this.rows; y++) ctx.fillRect(0, y * cs, this.w, 1);
    // walking aqua tile and its fading trail
    ctx.fillStyle = col.accent;
    for (i = 0; i < n; i++) {
      var a = i === this.walker ? 1 : this.trail[i];
      if (i === this.walker && this.loadT < 700) a = this.loadT / 700;
      if (a > 0.01) {
        ctx.globalAlpha = a * litA;
        ctx.fillRect((i % c) * cs + 1, ((i / c) | 0) * cs + 1, cs - 1, cs - 1);
      }
    }
    ctx.globalAlpha = 1;
    this.dirty = false;
  };

  /* Lite and static: no frame loop. Draw once with everything in place; lite also
     steps the aqua tile on a slow timer so the page still feels alive. */
  Field.prototype.still = function () {
    var i, n = this.v.length;
    for (i = 0; i < n; i++) this.v[i] = this.t[i];
    this.hair = 1; this.loadT = 9999;
    this.draw();
    if (kit.tier === "lite" && !this.timer) {
      var self = this;
      this.timer = setInterval(function () {
        if (!self.visible || document.hidden || kit.tier !== "lite") return;
        self.trail[self.walker] = 0;
        self.walker = self.neighbor();
        self.draw();
      }, 1800);
    }
  };

  function selectHosts() {
    var list = [];
    document.querySelectorAll("[data-tiles]").forEach(function (el) { list.push(el); });
    ["main .hero", "footer.foot"].forEach(function (s) {
      var el = document.querySelector(s);
      if (el && list.indexOf(el) < 0 && !el.hasAttribute("data-tiles-off")) list.push(el);
    });
    return list;
  }
  function refreshAll() {
    fields.forEach(function (f) {
      f.col = colors();
      if (kit.tier === "full") { if (f.visible) addJob(f.step); f.dirty = true; if (f.timer) { clearInterval(f.timer); f.timer = 0; } }
      else if (f.visible) f.still();
    });
  }
  var resizeT = 0;
  window.addEventListener("resize", function () {
    clearTimeout(resizeT);
    resizeT = setTimeout(function () {
      fields.forEach(function (f) { f.size(); if (kit.tier !== "full") f.still(); else { f.loadT = 9999; } });
      wake();
    }, 160);
  });
  new MutationObserver(function () { fields.forEach(function (f) { f.col = colors(); f.dirty = true; if (kit.tier !== "full") f.still(); }); wake(); })
    .observe(doc, { attributes: true, attributeFilter: ["data-theme"] });
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", function () {
    fields.forEach(function (f) { f.col = colors(); f.dirty = true; if (kit.tier !== "full") f.still(); });
  });

  selectHosts().forEach(function (h, i) { fields.push(new Field(h, i)); });
  booted = true;

  /* ==========================================================================
     Tile wipe between pages
     ========================================================================== */
  var wipeCanvas = null;
  function wipeCells(ox, oy) {
    var w = innerWidth, h = innerHeight;
    var cs = Math.max(56, Math.round(w / 14));
    var c = Math.ceil(w / cs), r = Math.ceil(h / cs), cells = [], maxD = 1;
    var rnd = mulberry(hash(location.pathname) ^ 0x9e3779b9);
    for (var y = 0; y < r; y++) for (var x = 0; x < c; x++) {
      var d = Math.hypot(x * cs + cs / 2 - ox, y * cs + cs / 2 - oy);
      if (d > maxD) maxD = d;
      cells.push({ x: x * cs, y: y * cs, d: d, j: rnd(), lit: rnd() < 0.09 });
    }
    return { cs: cs, cells: cells, maxD: maxD, w: w, h: h };
  }
  /* dir "in": tiles grow to cover. "out": tiles shrink away. Both radiate from the origin. */
  function runWipe(mode, ox, oy, done) {
    var span = cssMs("--dur-medium", 0.36) * 0.9;        // spread of the wave
    var life = cssMs("--dur-base", 0.26) * 0.8;          // each tile's own grow time
    var g = wipeCells(ox, oy), col = colors();
    if (!wipeCanvas) {
      wipeCanvas = document.createElement("canvas");
      wipeCanvas.className = "kit-wipe";
      wipeCanvas.setAttribute("aria-hidden", "true");
      document.body.appendChild(wipeCanvas);
    }
    var cv = wipeCanvas, ctx = cv.getContext("2d");
    cv.width = Math.round(g.w * DPR); cv.height = Math.round(g.h * DPR);
    cv.style.display = "block";
    var t0 = 0, total = span + life + 40;
    function draw(t) {
      if (!t0) t0 = t;
      var el = t - t0, i, cell, p;
      ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
      ctx.clearRect(0, 0, g.w, g.h);
      for (i = 0; i < g.cells.length; i++) {
        cell = g.cells[i];
        var delay = (cell.d / g.maxD) * span + cell.j * 50;
        p = Math.max(0, Math.min(1, (el - delay) / life));
        p = 1 - Math.pow(1 - p, 3);
        if (mode === "out") p = 1 - p;
        if (p <= 0.004) continue;
        ctx.fillStyle = cell.lit ? col.accent : col.tile;
        var s = g.cs * p, o = (g.cs - s) / 2;
        ctx.fillRect(cell.x + o - (p >= 1 ? 0.5 : 0), cell.y + o - (p >= 1 ? 0.5 : 0), s + (p >= 1 ? 1 : 0), s + (p >= 1 ? 1 : 0));
      }
      if (el < total + 60) requestAnimationFrame(draw);
      else { if (mode === "out") cv.style.display = "none"; done && done(); }
    }
    requestAnimationFrame(draw);
  }

  var leaving = false;
  function samePage(url) {
    function norm(p) { return p.replace(/index\.html$/, ""); }
    return norm(url.pathname) === norm(location.pathname) && url.search === location.search;
  }
  document.addEventListener("click", function (e) {
    if (kit.tier !== "full" || leaving) return;
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    var a = e.target.closest && e.target.closest("a[href]");
    if (!a || a.hasAttribute("download") || (a.target && a.target !== "_self")) return;
    if (a.getAttribute("href").charAt(0) === "#") return;
    var url;
    try { url = new URL(a.href); } catch (err) { return; }
    if (url.origin !== location.origin || samePage(url)) return;
    if (/\.(dmg|zip|pdf|json|xml|txt|png|jpe?g|svg|mp4)$/i.test(url.pathname)) return;
    var ox = e.clientX, oy = e.clientY;
    if (!e.detail || (!ox && !oy)) { var r = a.getBoundingClientRect(); ox = r.left + r.width / 2; oy = r.top + r.height / 2; }
    e.preventDefault();
    leaving = true;
    try { sessionStorage.setItem("inlet-wipe", (ox / innerWidth).toFixed(3) + "," + (oy / innerHeight).toFixed(3)); } catch (err) { /* no storage: the next page just loads without the reveal */ }
    runWipe("in", ox, oy, function () { location.href = url.href; });
  }, true);

  /* Arrival: the page is held under a plain cover by CSS until now, then the tiles clear. */
  (function arrive() {
    var raw = null;
    try { raw = sessionStorage.getItem("inlet-wipe"); sessionStorage.removeItem("inlet-wipe"); } catch (e) { /* ignore */ }
    if (!doc.classList.contains("wipe-arrive")) return;
    if (kit.tier !== "full" || !raw) { doc.classList.remove("wipe-arrive"); return; }
    var p = raw.split(",");
    var ox = parseFloat(p[0]) * innerWidth, oy = parseFloat(p[1]) * innerHeight;
    if (isNaN(ox) || isNaN(oy)) { ox = innerWidth / 2; oy = innerHeight / 3; }
    // paint the tiles at full cover first, then drop the plain cover and clear
    var col = colors(), g = wipeCells(ox, oy);
    wipeCanvas = document.createElement("canvas");
    wipeCanvas.className = "kit-wipe";
    wipeCanvas.setAttribute("aria-hidden", "true");
    wipeCanvas.width = Math.round(g.w * DPR); wipeCanvas.height = Math.round(g.h * DPR);
    document.body.appendChild(wipeCanvas);
    var ctx = wipeCanvas.getContext("2d");
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    g.cells.forEach(function (c) { ctx.fillStyle = c.lit ? col.accent : col.tile; ctx.fillRect(c.x - 0.5, c.y - 0.5, g.cs + 1, g.cs + 1); });
    requestAnimationFrame(function () {
      doc.classList.remove("wipe-arrive");
      runWipe("out", ox, oy);
    });
  })();
  window.addEventListener("pageshow", function (e) {
    if (e.persisted) { leaving = false; doc.classList.remove("wipe-arrive"); if (wipeCanvas) wipeCanvas.style.display = "none"; }
  });

  /* ==========================================================================
     Ticker: a loop of text whose speed and direction follow the scroll
     ========================================================================== */
  document.querySelectorAll("[data-ticker]").forEach(function (el) {
    var track = el.querySelector(".ticker-track");
    if (!track) return;
    if (kit.tier === "static" || !track.animate) return;
    track.innerHTML = track.innerHTML + track.innerHTML;
    var anim = track.animate([{ transform: "translateX(0)" }, { transform: "translateX(-50%)" }],
      { duration: 38000, iterations: Infinity, easing: "linear" });
    var vis = true;
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (es) { vis = es[es.length - 1].isIntersecting; if (vis) wake(); }).observe(el);
    }
    var rate = 1;
    addJob(function () {
      if (!vis) { anim.playbackRate = 0; return true; }
      if (kit.tier !== "full") { anim.playbackRate = 0.5; return true; }
      var target = dir * (1 + kit.vel * 9);
      rate += (target - rate) * 0.08;
      anim.playbackRate = rate;
      return true;
    });
  });

  /* ==========================================================================
     Staggered reveals: children of [data-stagger] come in one after another.
     The gap tightens when the page is scrolled fast. Uses scroll.js's .reveal.
     ========================================================================== */
  if (kit.tier !== "static" && "IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (en) {
        if (!en.isIntersecting) return;
        io.unobserve(en.target);
        var step = 70 * (1 - Math.min(0.85, kit.vel));
        Array.prototype.forEach.call(en.target.children, function (c, i) {
          c.style.setProperty("--d", Math.round(i * step) + "ms");
          c.classList.add("is-in");
        });
      });
    }, { threshold: 0.15, rootMargin: "0px 0px -6% 0px" });
    document.querySelectorAll("[data-stagger]").forEach(function (el) {
      Array.prototype.forEach.call(el.children, function (c) { c.classList.add("reveal"); });
      io.observe(el);
    });
  }
})();
