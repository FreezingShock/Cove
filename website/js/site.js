(function () {
  "use strict";

  /* ---------- Data: sample apps drawn in original glyphs, and sample files ---------- */
  var GLYPH = {
    note: '<path d="M13.4 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7.4" /><path d="M2 6h4" /><path d="M2 10h4" /><path d="M2 14h4" /><path d="M2 18h4" /><path d="M21.378 5.626a1 1 0 1 0-3.004-3.004l-5.01 5.012a2 2 0 0 0-.506.854l-.837 2.87a.5.5 0 0 0 .62.62l2.87-.837a2 2 0 0 0 .854-.506z" />',
    calendar: '<path d="M8 2v3" /><path d="M16 2v3" /><rect x="3" y="3" width="18" height="18" rx="2" /><path d="M3 9h18" />',
    music: '<path d="M21 16V3a1 1 0 0 0-1.28-.96l-10 2.917a1 1 0 0 0-.72.96V19" /><circle cx="18" cy="16" r="3" /><circle cx="6" cy="19" r="3" />',
    photos: '<rect width="18" height="18" x="3" y="3" rx="2" ry="2" /><circle cx="9" cy="9" r="2" /><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21" />',
    terminal: '<path d="M12 19h8" /><path d="m4 17 6-6-6-6" />',
    mail: '<path d="m22 7-8.991 5.727a2 2 0 0 1-2.009 0L2 7" /><rect x="2" y="4" width="20" height="16" rx="2" />',
    maps: '<path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0" /><circle cx="12" cy="10" r="3" />',
    weather: '<path d="M12 2v2" /><path d="m4.93 4.93 1.41 1.41" /><path d="M20 12h2" /><path d="m19.07 4.93-1.41 1.41" /><path d="M15.947 12.65a4 4 0 0 0-5.925-4.128" /><path d="M13 22H7a5 5 0 1 1 4.9-6H13a3 3 0 0 1 0 6Z" />',
    books: '<path d="M12 5v16" /><path d="M20.001 19A2 2 0 0022 17V5a2 2 0 00-1.999-2L16 3.002A5 5 0 0012 5a5 5 0 00-4-2H4a2 2 0 00-2 2v12a2 2 0 001.999 2H8a5 5 0 014 2 5 5 0 014-2z" />',
    reminders: '<path d="M13 5h8" /><path d="M13 12h8" /><path d="M13 19h8" /><path d="m3 17 2 2 4-4" /><path d="m3 7 2 2 4-4" />',
    files: '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z" />',
    chart: '<path d="M3 3v16a2 2 0 0 0 2 2h16" /><path d="M18 17V9" /><path d="M13 17V5" /><path d="M8 17v-3" />',
    code: '<path d="m16 18 6-6-6-6" /><path d="m8 6-6 6 6 6" />',
    messages: '<path d="M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719" />',
    lens: '<circle cx="12" cy="12" r="10" /><path d="m14.31 8 5.74 9.94" /><path d="M9.69 8h11.48" /><path d="m7.38 12 5.74-9.94" /><path d="M9.69 16 3.95 6.06" /><path d="M14.31 16H2.83" /><path d="m16.62 12-5.74 9.94" />',
    journal: '<path d="M2 6h4" /><path d="M2 10h4" /><path d="M2 14h4" /><path d="M2 18h4" /><rect width="16" height="20" x="4" y="2" rx="2" /><path d="M16 2v20" />'
  };
  var APPS = [
    { n: "Notes", g: "note", a: "#FFD36E", b: "#F0A020" },
    { n: "Calendar", g: "calendar", a: "#FF8F84", b: "#E0443E" },
    { n: "Music", g: "music", a: "#FF8DBB", b: "#D23D7F" },
    { n: "Photos", g: "photos", a: "#9BE8A6", b: "#2C9E5C" },
    { n: "Terminal", g: "terminal", a: "#5A6275", b: "#1A1F29" },
    { n: "Mail", g: "mail", a: "#8CC8FF", b: "#2F6FE0" },
    { n: "Maps", g: "maps", a: "#A8E9B4", b: "#1E8C6E" },
    { n: "Weather", g: "weather", a: "#9ED8FF", b: "#2D7FD8" },
    { n: "Books", g: "books", a: "#FFC79A", b: "#E0662C" },
    { n: "Reminders", g: "reminders", a: "#BCAEFF", b: "#5B45D6" },
    { n: "Files", g: "files", a: "#84DDFF", b: "#0A7FCF" },
    { n: "Charts", g: "chart", a: "#CDF58F", b: "#4E9A1F" },
    { n: "Code", g: "code", a: "#8E98FF", b: "#3340A8" },
    { n: "Messages", g: "messages", a: "#83EEA2", b: "#1FA34A" },
    { n: "Lens", g: "lens", a: "#6A707D", b: "#22252C" },
    { n: "Journal", g: "journal", a: "#FFB9CC", b: "#C4456B" }
  ];
  var FILES = [
    { n: "Notes from Tuesday.txt", p: "Documents" },
    { n: "Lab notes, week 3.txt", p: "Documents / Classes" },
    { n: "Packing list.md", p: "Desktop" },
    { n: "Cover letter final.pdf", p: "Downloads" },
    { n: "Budget 2026.csv", p: "Documents / Money" },
    { n: "Trip photos, May.pdf", p: "Downloads" }
  ];
  var DOC_GLYPH = '<path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z" /><path d="M14 2v5a1 1 0 0 0 1 1h5" />';
  /* Shared with home.js (folders and edit mode demo). */
  window.InletSamples = { APPS: APPS, GLYPH: GLYPH };

  /* ---------- Springs: the spec's tokens, stiffness = (2π/d)², damping = 4π(1−bounce)/d ---------- */
  var SPR = {
    snap: [0.24, 0], press: [0.26, 0.42], open: [0.46, 0.24], morph: [0.52, 0.3],
    rise: [0.5, 0.32], settle: [0.6, 0.18], dismiss: [0.26, 0]
  };
  var reduceQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  function sp(name) {
    var d = SPR[name][0], b = SPR[name][1];
    return { k: Math.pow(2 * Math.PI / d, 2), c: 4 * Math.PI * (1 - b) / d };
  }
  function spring(from, to, s, step) {
    if (reduceQuery.matches) { step(to); return Promise.resolve(); }
    return new Promise(function (resolve) {
      var x = from, v = 0, last = null, frames = 0;
      function tick(now) {
        if (last === null) last = now;
        var dt = Math.min((now - last) / 1000, 1 / 30);
        last = now;
        var n = Math.max(1, Math.ceil(dt * 480)), h = dt / n;
        for (var i = 0; i < n; i++) {
          v += (-s.k * (x - to) - s.c * v) * h;
          x += v * h;
        }
        frames++;
        if ((Math.abs(x - to) < 0.0005 && Math.abs(v) < 0.0005) || frames > 900) {
          step(to);
          resolve();
        } else {
          step(x);
          requestAnimationFrame(tick);
        }
      }
      requestAnimationFrame(tick);
    });
  }
  // Runs one spring per (element, channel). A newer call on the same channel wins.
  function animate(el, key, from, to, name, apply, delay) {
    return new Promise(function (resolve) {
      el.__g = el.__g || {};
      var g = el.__g[key] = (el.__g[key] || 0) + 1;
      function go() {
        if (el.__g[key] !== g) { resolve(); return; }
        spring(from, to, sp(name), function (v) {
          if (el.__g[key] === g) apply(v);
        }).then(resolve);
      }
      if (delay) setTimeout(go, delay); else go();
    });
  }

  /* ---------- Markup builders ---------- */
  function icon(app) {
    return '<span class="ico" style="--a:' + app.a + ';--b:' + app.b + '"><svg viewBox="0 0 24 24" aria-hidden="true">' + GLYPH[app.g] + '</svg></span>';
  }
  function cellHTML(app, withName) {
    return '<button class="cell" type="button" data-name="' + app.n + '" aria-label="' + app.n + '">' +
      icon(app) + (withName ? '<span class="name">' + app.n + '</span>' : '') + '</button>';
  }
  function fillGrid(el, apps, withName) {
    if (!el) return;
    el.innerHTML = apps.map(function (a) { return cellHTML(a, withName); }).join("");
  }
  function $(sel) { return document.querySelector(sel); }

  /* ---------- Cell state: open ripple (p), press (ps), search reflow (dx, dy, fs) ---------- */
  function st(c) {
    return c.__st || (c.__st = { ox: 0, oy: 0, p: 1, ps: 1, dx: 0, dy: 0, fs: 1 });
  }
  function cellRender(c) {
    var s = st(c);
    var x = s.ox * (1 - s.p) + s.dx;
    var y = s.oy * (1 - s.p) + s.dy;
    var k = (0.78 + 0.22 * s.p) * s.ps * s.fs;
    c.style.transform = "translate3d(" + x.toFixed(2) + "px," + y.toFixed(2) + "px,0) scale(" + k.toFixed(4) + ")";
  }

  /* ---------- Appearance: Auto follows the system, Light and Dark set the page ---------- */
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

  if (document.getElementById("qp")) {
  /* ---------- Hero grid: opens from the center, ripple outward ---------- */
  var heroGrid = $("#heroGrid");
  fillGrid(heroGrid, APPS, true);
  function openHero() {
    var cells = heroGrid.querySelectorAll(".cell");
    var cx = heroGrid.clientWidth / 2, cy = heroGrid.clientHeight / 2;
    Array.prototype.forEach.call(cells, function (c) {
      var x = c.offsetLeft + c.offsetWidth / 2, y = c.offsetTop + c.offsetHeight / 2;
      var s = st(c);
      s.ox = (cx - x) * 0.22;
      s.oy = (cy - y) * 0.22;
      s.p = 0;
      cellRender(c);
      var delay = Math.min(Math.hypot(cx - x, cy - y) * 0.6, 520); // 0.6 ms per point from center, capped at 520 ms
      animate(c, "open", 0, 1, "open", function (v) { s.p = v; cellRender(c); }, delay);
    });
  }
  $("#replayBtn").addEventListener("click", openHero);
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      if (entries[0].isIntersecting) { io.disconnect(); openHero(); }
    }, { threshold: 0.35 });
    io.observe($("#heroStage"));
  }

  /* ---------- Press feedback: snap down, spring back ---------- */
  var pressed = null;
  document.addEventListener("pointerdown", function (e) {
    var c = e.target.closest && e.target.closest(".cell");
    if (!c) return;
    pressed = c;
    var s = st(c);
    animate(c, "press", s.ps, 0.9, "snap", function (v) { s.ps = v; cellRender(c); });
  });
  function release() {
    if (!pressed) return;
    var c = pressed; pressed = null;
    var s = st(c);
    animate(c, "press", s.ps, 1, "press", function (v) { s.ps = v; cellRender(c); });
  }
  document.addEventListener("pointerup", release);
  document.addEventListener("pointercancel", release);
  document.addEventListener("click", function (e) {
    // Keyboard activation (detail 0) gets the same press bounce as a tap.
    var c = e.target.closest && e.target.closest(".cell");
    if (!c || e.detail !== 0) return;
    var s = st(c);
    animate(c, "press", 0.9, 1, "press", function (v) { s.ps = v; cellRender(c); });
  });

  /* ---------- Search: filter with a reflow, top hit, files ---------- */
  function filterGrid(grid, test, withTop) {
    var cells = Array.prototype.slice.call(grid.querySelectorAll(".cell"));
    var before = new Map();
    cells.forEach(function (c) {
      if (!c.hidden) before.set(c, { x: c.offsetLeft, y: c.offsetTop });
    });
    cells.forEach(function (c) {
      c.hidden = !test(c);
      c.classList.remove("is-top");
    });
    var vis = cells.filter(function (c) { return !c.hidden; });
    if (withTop && vis[0]) vis[0].classList.add("is-top");
    vis.forEach(function (c) {
      var s = st(c);
      var old = before.get(c);
      if (old) {
        var dx = old.x - c.offsetLeft, dy = old.y - c.offsetTop;
        if (Math.abs(dx) < 1 && Math.abs(dy) < 1) return;
        s.dx = dx; s.dy = dy; s.fs = 1;
        cellRender(c);
        animate(c, "flip", 1, 0, "settle", function (v) {
          s.dx = dx * v; s.dy = dy * v; cellRender(c);
        });
      } else {
        s.dx = 0; s.dy = 0; s.fs = 0.6;
        cellRender(c);
        animate(c, "flip", 1, 0, "open", function (v) { s.fs = 1 - 0.4 * v; cellRender(c); });
      }
    });
  }

  var searchGrid = $("#searchGrid");
  var qInput = $("#q");
  var filesPanel = $("#filesPanel");
  var fileRows = $("#fileRows");
  var emptyMsg = $("#emptyMsg");
  fillGrid(searchGrid, APPS, true);

  function applySearch() {
    var q = qInput.value.trim().toLowerCase();
    filterGrid(searchGrid, function (c) {
      return !q || c.dataset.name.toLowerCase().indexOf(q) !== -1;
    }, !!q);
    var hits = searchGrid.querySelectorAll(".cell:not([hidden])").length;
    var files = q ? FILES.filter(function (f) { return f.n.toLowerCase().indexOf(q) !== -1; }).slice(0, 4) : [];
    fileRows.innerHTML = files.map(function (f) {
      return '<li><span class="fi"><svg viewBox="0 0 24 24" aria-hidden="true">' + DOC_GLYPH + '</svg></span><span><b>' + f.n + '</b><small>' + f.p + '</small></span></li>';
    }).join("");
    filesPanel.hidden = files.length === 0;
    emptyMsg.hidden = !(q && hits === 0 && files.length === 0);
  }
  qInput.addEventListener("input", applySearch);
  qInput.addEventListener("keydown", function (e) {
    if (e.key === "Enter") {
      var top = searchGrid.querySelector(".cell.is-top");
      if (top) top.click();
    }
  });
  Array.prototype.forEach.call(document.querySelectorAll("[data-q]"), function (b) {
    b.addEventListener("click", function () {
      qInput.value = b.dataset.q;
      applySearch();
      qInput.focus();
    });
  });

  /* ---------- Quick panel: rises from the Dock icon, closes with no bounce ---------- */
  var qp = $("#qp"), qpWrap = $("#qpWrap"), dockInlet = $("#dockInlet");
  fillGrid($("#qpApps"), APPS.slice(0, 8), true);
  if ($("#qpFiles")) $("#qpFiles").innerHTML = FILES.slice(0, 3).map(function (f) {
    return '<li><span class="fi"><svg viewBox="0 0 24 24" aria-hidden="true">' + DOC_GLYPH + '</svg></span><span><b>' + f.n + '</b><small>' + f.p + '</small></span></li>';
  }).join("");
  // Dock sample icons (static, no interaction)
  if ($("#dockApps")) $("#dockApps").innerHTML = APPS.slice(0, 5).map(function (a) {
    return '<span class="dock-btn" aria-hidden="true" style="pointer-events:none"><span class="ico" style="--tile:44px;--a:' + a.a + ';--b:' + a.b + '"><svg viewBox="0 0 24 24">' + GLYPH[a.g] + '</svg></span><span class="ind"></span></span>';
  }).join("");

  function setPanel(v) {
    qp.__v = v;
    var s = Math.max(0, 0.32 + 0.68 * v), t = Math.max(0, 0.18 + 0.82 * v);
    qp.style.transform = "translate3d(0," + ((1 - v) * 60).toFixed(2) + "px,0) scale(" + s.toFixed(4) + "," + t.toFixed(4) + ")";
    qp.style.opacity = Math.min(1, Math.max(0, v)).toFixed(3);
  }
  var panelOpen = true;
  setPanel(1);
  dockInlet.addEventListener("click", function () {
    panelOpen = !panelOpen;
    dockInlet.setAttribute("aria-expanded", String(panelOpen));
    if (panelOpen) {
      qpWrap.hidden = false;
      var from = qp.__v == null ? 0 : qp.__v;
      setPanel(from);
      animate(qp, "panel", from, 1, "rise", setPanel);
    } else {
      animate(qp, "panel", qp.__v == null ? 1 : qp.__v, 0, "dismiss", setPanel).then(function () {
        if (!panelOpen) qpWrap.hidden = true;
      });
    }
  });

  /* ---------- Settings: columns and the grid preview ---------- */
  var cols = $("#cols"), colsOut = $("#colsOut"), miniGrid = $("#miniGrid");
  fillGrid(miniGrid, APPS, false);
  cols.addEventListener("input", function () {
    miniGrid.style.setProperty("--cols", cols.value);
    colsOut.textContent = cols.value;
  });

  /* ---------- Motion demo: each card plays its own token ---------- */
  Array.prototype.forEach.call(document.querySelectorAll(".mcard"), function (card) {
    var name = card.dataset.spring;
    var from = Number(card.dataset.from), to = Number(card.dataset.to);
    var track = card.querySelector(".mtrack"), dot = card.querySelector(".mdot"), btn = card.querySelector(".play");
    function place(v) {
      var span = Math.max(0, track.clientWidth - 26);
      dot.style.transform = "translate3d(" + (v * span).toFixed(2) + "px,0,0)";
    }
    place(from);
    btn.addEventListener("click", function () {
      place(from);
      animate(card, "play", from, to, name, place);
    });
  });

  /* ---------- Demo video: plays while on screen, pauses off screen, starts paused for Reduce Motion ---------- */
  var demo = $("#demoVideo"), demoBtn = $("#demoToggle");
  if (demo && demoBtn) {
    var userPaused = reduceQuery.matches;
    function showDemoState() {
      var playing = !demo.paused;
      demoBtn.textContent = playing ? "Pause" : "Play";
      demoBtn.setAttribute("aria-label", playing ? "Pause demo" : "Play demo");
    }
    function playDemo() {
      if (userPaused || demo.dataset.scrub === "on") return; // pinned demo: scroll drives the video, see scroll.js
      var p = demo.play();
      if (p && p.catch) p.catch(function () { /* autoplay blocked: the poster stays and Play still works */ });
    }
    demoBtn.addEventListener("click", function () {
      if (demo.paused) { userPaused = false; playDemo(); }
      else { userPaused = true; demo.pause(); }
      showDemoState();
    });
    demo.addEventListener("play", showDemoState);
    demo.addEventListener("pause", showDemoState);
    showDemoState();
    if ("IntersectionObserver" in window) {
      var demoIO = new IntersectionObserver(function (entries) {
        entries.forEach(function (en) {
          if (en.isIntersecting) playDemo(); else demo.pause();
        });
      }, { threshold: 0.4 });
      demoIO.observe(demo);
    }
  }
  }
})();
