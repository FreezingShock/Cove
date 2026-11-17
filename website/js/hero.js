(function () {
  "use strict";

  /* Hero window: a small, real sample of Inlet. Visitors can type to search, open the
     Create folder, and move between pages by dragging, with a trackpad, with the arrow
     keys, or with the page dots. Until a visitor takes the window, it runs a short search
     loop on its own. With Reduce Motion on, nothing moves by itself and the animations
     are off, but every control still works. Motion uses only WAAPI on `translate` and
     `scale` (and opacity), and the track moves with `transform`, so nothing fights
     site.js, which sets `transform` on pressed cells. */

  var samples = window.InletSamples;
  var win = document.getElementById("heroWin");
  var view = document.getElementById("heroView");
  var track = document.getElementById("heroTrack");
  var input = document.getElementById("heroQ");
  var tape = document.getElementById("heroTape");
  var status = document.getElementById("heroStatus");
  var enter = win && win.querySelector(".win-enter");
  var glintEl = win && win.querySelector(".glint");
  var pager = document.getElementById("heroPager");
  var sheet = document.getElementById("heroSheet");
  var sheetPanel = document.getElementById("heroSheetPanel");
  var sheetGrid = document.getElementById("heroSheetGrid");
  var sheetTitle = document.getElementById("heroSheetTitle");
  var sheetClose = document.getElementById("heroSheetClose");
  var sheetScrim = document.getElementById("heroSheetScrim");
  var replay = document.getElementById("replayBtn");
  if (!samples || !win || !view || !track || !input || !tape || !status || !enter || !glintEl ||
      !pager || !sheet || !sheetPanel || !sheetGrid || !sheetTitle || !sheetClose || !sheetScrim || !replay) return;

  var APPS = samples.APPS, GLYPH = samples.GLYPH;
  var BY_NAME = {};
  APPS.forEach(function (a) { BY_NAME[a.n] = a; });
  var TOTAL = APPS.length;
  var WORD = "photos";

  /* The sample layout. A folder is an item on a page that holds its own apps. */
  var CREATE = { folder: true, n: "Create", apps: ["Code", "Charts", "Lens", "Journal"] };
  var FOLDERS = { Create: CREATE };
  var LAYOUT = [
    ["Notes", "Calendar", "Music", "Photos", "Terminal", "Mail", "Maps", CREATE],
    ["Weather", "Books", "Reminders", "Files", "Messages"]
  ];
  var PAGES = LAYOUT.length;

  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)");

  /* Motion tokens come from tokens.css (generated from design/tokens.json), so the demo
     moves on the same curves as the app. Fallbacks match the token values. */
  function token(name, fallback) {
    try {
      var v = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
      return v || fallback;
    } catch (e) { return fallback; }
  }
  function ms(name, fallback) { return parseFloat(token(name, fallback)) * 1000; }
  var canLinear = !!(window.CSS && CSS.supports && CSS.supports("animation-timing-function", "linear(0, 1)"));
  var EASE = token("--ease-standard", "cubic-bezier(0.2, 0.8, 0.2, 1)");
  var SETTLE = canLinear ? token("--spring-settle", EASE) : EASE;
  var SETTLE_MS = canLinear ? ms("--spring-settle-dur", "0.82s") : ms("--dur-medium", "0.36s");
  var OPEN = canLinear ? token("--spring-open", EASE) : EASE;
  var OPEN_MS = canLinear ? ms("--spring-open-dur", "0.46s") : ms("--dur-medium", "0.36s");

  var state = { page: 0, query: "", hits: [], folder: null, origin: null };
  var running = false, stopped = false, runId = 0;
  var locked = false, lockTimer = 0;
  var drag = null, justDragged = false, wheelLast = 0;

  function sleep(t) { return new Promise(function (r) { setTimeout(r, t); }); }
  function alive(id) { return running && id === runId; }
  function anim(el, frames, opts) {
    if (!el || !el.animate || reduce.matches) return;
    el.animate(frames, opts);
  }

  /* ---------- Markup ---------- */
  function iconHTML(app) {
    return '<span class="ico" style="--a:' + app.a + ';--b:' + app.b + '"><svg viewBox="0 0 24 24" aria-hidden="true">' +
      GLYPH[app.g] + '</svg></span>';
  }
  function appCell(app) {
    var b = document.createElement("button");
    b.type = "button";
    b.className = "cell";
    b.dataset.name = app.n;
    b.setAttribute("aria-label", app.n);
    b.innerHTML = iconHTML(app) + '<span class="name"></span>';
    b.querySelector(".name").textContent = app.n;
    return b;
  }
  function folderCell(folder) {
    var b = document.createElement("button");
    b.type = "button";
    b.className = "cell folder";
    b.dataset.name = folder.n;
    b.dataset.folder = "1";
    b.setAttribute("aria-haspopup", "dialog");
    b.setAttribute("aria-label", folder.n + " folder, " + folder.apps.length + " apps");
    var mini = folder.apps.slice(0, 4).map(function (n) {
      var a = BY_NAME[n];
      return '<i style="--a:' + a.a + ';--b:' + a.b + '"></i>';
    }).join("");
    b.innerHTML = '<span class="ico folder-ico" aria-hidden="true">' + mini + '</span><span class="name"></span>';
    b.querySelector(".name").textContent = folder.n;
    return b;
  }
  function buildPage(index, items) {
    var pg = document.createElement("div");
    pg.className = "page";
    pg.setAttribute("role", "group");
    pg.setAttribute("aria-label", "Page " + (index + 1) + " of " + PAGES);
    var grid = document.createElement("div");
    grid.className = "grid";
    items.forEach(function (item) {
      grid.appendChild(typeof item === "string" ? appCell(BY_NAME[item]) : folderCell(item));
    });
    pg.appendChild(grid);
    return pg;
  }
  function allApps() {
    var list = [];
    LAYOUT.forEach(function (items) {
      items.forEach(function (item) {
        if (typeof item === "string") list.push(BY_NAME[item]);
        else item.apps.forEach(function (n) { list.push(BY_NAME[n]); });
      });
    });
    return list;
  }

  /* Paint the pages, showing the current one. Pages off screen are inert. */
  function paint() {
    track.textContent = "";
    LAYOUT.forEach(function (items, i) {
      var pg = buildPage(i, items);
      if (i !== state.page) pg.inert = true;
      track.appendChild(pg);
    });
    track.style.transform = "translate3d(" + (-state.page * 100) + "%,0,0)";
    renderPager();
  }

  function renderPager() {
    pager.textContent = "";
    for (var i = 0; i < PAGES; i++) {
      var b = document.createElement("button");
      b.type = "button";
      b.className = "pg";
      b.dataset.page = String(i);
      b.setAttribute("aria-label", "Page " + (i + 1) + " of " + PAGES);
      if (i === state.page) b.setAttribute("aria-current", "page");
      pager.appendChild(b);
    }
  }

  /* ---------- Motion helpers ---------- */
  function visibleCells() {
    return Array.prototype.filter.call(track.querySelectorAll(".cell"), function (c) {
      return !c.closest(".page").inert;
    });
  }
  function measure() {
    var m = {};
    visibleCells().forEach(function (c) { m[c.dataset.name] = c.getBoundingClientRect(); });
    return m;
  }
  /* Cells that stay glide from their old spot; new cells spring in from a smaller scale. */
  function flip(before) {
    if (reduce.matches) return;
    visibleCells().forEach(function (c) {
      var n = c.getBoundingClientRect();
      var o = before[c.dataset.name];
      if (o) {
        var dx = o.left - n.left, dy = o.top - n.top;
        if (Math.abs(dx) > 0.5 || Math.abs(dy) > 0.5) {
          anim(c, [{ translate: dx + "px " + dy + "px" }, { translate: "0px 0px" }],
            { duration: SETTLE_MS, easing: SETTLE });
        }
      } else {
        anim(c, [{ opacity: 0, scale: "0.6" }, { opacity: 1, scale: "1" }],
          { duration: SETTLE_MS, easing: SETTLE });
      }
    });
  }
  /* Intro: the grid opens from the center and ripples outward. */
  function ripple() {
    if (reduce.matches || !win.animate) return;
    var box = track.getBoundingClientRect();
    var cx = box.left + box.width / 2, cy = box.top + box.height / 2;
    visibleCells().forEach(function (c) {
      var r = c.getBoundingClientRect();
      var x = r.left + r.width / 2, y = r.top + r.height / 2;
      var dist = Math.hypot(cx - x, cy - y);
      c.animate([
        { translate: ((cx - x) * 0.22) + "px " + ((cy - y) * 0.22) + "px", opacity: 0, scale: "0.78" },
        { translate: "0px 0px", opacity: 1, scale: "1" }
      ], { duration: OPEN_MS, delay: Math.min(dist * 0.6, 520), easing: OPEN, fill: "backwards" });
    });
  }

  /* ---------- Search ---------- */
  function showResults(q) {
    var before = measure();
    var hits = allApps().filter(function (a) { return a.n.toLowerCase().indexOf(q) !== -1; });
    state.hits = hits;
    track.textContent = "";
    var pg = document.createElement("div");
    pg.className = "page";
    pg.setAttribute("role", "group");
    pg.setAttribute("aria-label", "Search results");
    var grid = document.createElement("div");
    grid.className = "grid";
    hits.forEach(function (a) { grid.appendChild(appCell(a)); });
    pg.appendChild(grid);
    track.appendChild(pg);
    track.style.transform = "translate3d(0,0,0)";
    if (grid.firstChild) grid.firstChild.classList.add("is-top");
    flip(before);
  }

  function setQuery(raw) {
    var q = raw.trim().toLowerCase();
    if (q === state.query) return;
    state.query = q;
    if (q) showResults(q);
    else { state.hits = []; paint(); }
    enter.classList.toggle("is-ready", !!(q && state.hits.length));
    pager.hidden = !!q;
    updateStatus();
  }

  /* ---------- Status line ---------- */
  function updateStatus() {
    if (locked) return;
    var text;
    if (state.folder) {
      text = state.folder.n + " · " + state.folder.apps.length + " apps";
    } else if (state.query) {
      var n = state.hits.length;
      text = n === 0 ? "No matches" : n === TOTAL ? TOTAL + " apps" : n + " of " + TOTAL + " apps";
    } else {
      text = TOTAL + " apps · Page " + (state.page + 1) + " of " + PAGES;
    }
    status.textContent = text;
  }
  function lockStatus(text, t) {
    locked = true;
    status.textContent = text;
    clearTimeout(lockTimer);
    lockTimer = setTimeout(function () { locked = false; updateStatus(); }, t);
  }

  /* ---------- Keycaps ---------- */
  function addKey(ch) {
    var k = document.createElement("kbd");
    k.className = "tk";
    k.textContent = ch;
    tape.appendChild(k);
  }
  function popKey() {
    var last = tape.lastElementChild;
    if (last) last.remove();
  }

  /* ---------- Pages ---------- */
  function goTo(p) {
    var next = Math.max(0, Math.min(PAGES - 1, p));
    track.classList.remove("is-dragging");
    track.style.transform = "translate3d(" + (-next * 100) + "%,0,0)";
    if (next === state.page) return;
    state.page = next;
    track.querySelectorAll(".page").forEach(function (pg, i) { pg.inert = i !== next; });
    renderPager();
    updateStatus();
  }

  /* ---------- Folder sheet ---------- */
  function openFolder(cell) {
    var folder = FOLDERS[cell.dataset.name];
    if (!folder) return;
    state.folder = folder;
    state.origin = cell;
    sheetTitle.textContent = folder.n;
    sheetGrid.textContent = "";
    folder.apps.forEach(function (n) { sheetGrid.appendChild(appCell(BY_NAME[n])); });
    sheet.hidden = false;
    anim(sheetPanel, [{ opacity: 0, scale: "0.94", translate: "0px 12px" }, { opacity: 1, scale: "1", translate: "0px 0px" }],
      { duration: OPEN_MS, easing: OPEN });
    anim(sheetScrim, [{ opacity: 0 }, { opacity: 1 }], { duration: OPEN_MS, easing: "linear" });
    updateStatus();
    sheetClose.focus({ preventScroll: true });
  }
  function closeFolder() {
    if (!state.folder) return;
    state.folder = null;
    sheet.hidden = true;
    var origin = state.origin;
    state.origin = null;
    if (origin && origin.isConnected) origin.focus({ preventScroll: true });
    updateStatus();
  }

  /* ---------- Launch: the signature moment, a press and a light ribbon ---------- */
  function openApp(name, cell) {
    if (!BY_NAME[name]) return;
    if (state.folder) closeFolder();
    if (cell) {
      anim(cell.querySelector(".ico"),
        [{ scale: "1" }, { scale: "0.88", offset: 0.22 }, { scale: "1.05", offset: 0.66 }, { scale: "1" }],
        { duration: ms("--dur-slow", "0.5s"), easing: "linear" });
    }
    anim(glintEl, [{ translate: "-120% 0" }, { translate: "260% 0" }],
      { duration: ms("--dur-slower", "0.8s"), easing: EASE });
    lockStatus("Opening " + name, 1400);
  }

  /* ---------- Intro loop: types a word, presses the top hit, clears ---------- */
  function resetSample() {
    input.value = "";
    tape.textContent = "";
    setQuery("");
  }
  async function loop(id) {
    while (alive(id)) {
      resetSample();
      await sleep(1100);
      for (var i = 1; i <= WORD.length; i++) {
        if (!alive(id)) return;
        input.value = WORD.slice(0, i);
        addKey(WORD.charAt(i - 1));
        setQuery(input.value);
        await sleep(240);
      }
      if (!alive(id)) return;
      await sleep(650);
      if (!alive(id)) return;
      var top = track.querySelector(".cell.is-top");
      if (top) openApp(top.dataset.name, top);
      await sleep(1000);
      for (var j = WORD.length; j >= 0; j--) {
        if (!alive(id)) return;
        input.value = WORD.slice(0, j);
        popKey();
        setQuery(input.value);
        await sleep(60);
      }
      await sleep(1800);
    }
  }
  function start() {
    if (running || stopped || reduce.matches) return;
    running = true;
    loop(++runId);
  }
  function halt() { running = false; }
  /* A visitor takes the window: the loop stops for good. */
  function takeOver() {
    if (stopped) return;
    stopped = true;
    halt();
  }

  /* ---------- Events ---------- */
  /* A visitor who clicks the field mid-loop gets the field cleared first, so their typing
     is not added to the sample word. Text they typed themselves stays. */
  var visitorTyped = false;
  input.addEventListener("focus", function () {
    takeOver();
    if (!visitorTyped && state.query) resetSample();
  });
  input.addEventListener("input", function () {
    visitorTyped = true;
    takeOver();
    setQuery(input.value);
  });
  input.addEventListener("keydown", function (e) {
    if (e.key === "Enter") {
      e.preventDefault();
      var top = track.querySelector(".cell.is-top");
      if (top) openApp(top.dataset.name, top);
    }
  });

  win.addEventListener("keydown", function (e) {
    if (e.key === "Escape") {
      if (state.folder) { e.preventDefault(); closeFolder(); }
      else if (state.query) { e.preventDefault(); input.value = ""; setQuery(""); }
    } else if ((e.key === "ArrowRight" || e.key === "ArrowLeft") && e.target !== input) {
      if (state.query || state.folder) return;
      e.preventDefault();
      takeOver();
      goTo(state.page + (e.key === "ArrowRight" ? 1 : -1));
    }
  });

  /* Taps on a cell: a folder opens, an app launches. Ignored when the tap was a swipe. */
  track.addEventListener("click", function (e) {
    if (justDragged) { justDragged = false; e.preventDefault(); return; }
    var cell = e.target.closest(".cell");
    if (!cell) return;
    takeOver();
    if (cell.dataset.folder) openFolder(cell);
    else openApp(cell.dataset.name, cell);
  });

  pager.addEventListener("click", function (e) {
    var b = e.target.closest(".pg");
    if (!b) return;
    takeOver();
    goTo(Number(b.dataset.page));
  });

  /* Swipe: drag the pages with a mouse or a finger. Vertical moves scroll the page. */
  view.addEventListener("pointerdown", function (e) {
    if (state.query || state.folder || !e.isPrimary || e.button !== 0) return;
    justDragged = false;
    drag = { id: e.pointerId, x: e.clientX, y: e.clientY, dx: 0, axis: null };
  });
  view.addEventListener("pointermove", function (e) {
    if (!drag || e.pointerId !== drag.id) return;
    var dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    if (!drag.axis) {
      if (Math.abs(dx) < 6 && Math.abs(dy) < 6) return;
      drag.axis = Math.abs(dx) > Math.abs(dy) ? "x" : "y";
      if (drag.axis === "y") { drag = null; return; }
      takeOver();
      track.classList.add("is-dragging");
      view.setPointerCapture(e.pointerId);
    }
    drag.dx = dx;
    var atEdge = (state.page === 0 && dx > 0) || (state.page === PAGES - 1 && dx < 0);
    var shown = atEdge ? dx * 0.35 : dx;
    track.style.transform = "translate3d(calc(" + (-state.page * 100) + "% + " + shown.toFixed(1) + "px),0,0)";
  });
  function endDrag(e) {
    if (!drag || e.pointerId !== drag.id) return;
    var d = drag;
    drag = null;
    track.classList.remove("is-dragging");
    if (d.axis !== "x") return;
    justDragged = true;
    var threshold = view.clientWidth * 0.18;
    var next = state.page;
    if (d.dx < -threshold) next = state.page + 1;
    else if (d.dx > threshold) next = state.page - 1;
    goTo(next);
  }
  view.addEventListener("pointerup", endDrag);
  view.addEventListener("pointercancel", endDrag);

  /* Trackpad: one horizontal gesture turns one page. Inertia keeps sending events, so a
     new turn needs a pause of more than 200 ms. */
  view.addEventListener("wheel", function (e) {
    if (state.query || state.folder) return;
    if (Math.abs(e.deltaX) < 12 || Math.abs(e.deltaX) < Math.abs(e.deltaY)) return;
    e.preventDefault();
    var now = Date.now();
    var fresh = now - wheelLast > 200;
    wheelLast = now;
    if (!fresh) return;
    takeOver();
    goTo(state.page + (e.deltaX > 0 ? 1 : -1));
  }, { passive: false });

  sheetClose.addEventListener("click", closeFolder);
  sheetScrim.addEventListener("click", closeFolder);
  sheetGrid.addEventListener("click", function (e) {
    var c = e.target.closest(".cell");
    if (c) openApp(c.dataset.name, c);
  });

  replay.addEventListener("click", function () {
    stopped = false;
    halt();
    closeFolder();
    state.page = 0;
    state.query = "";
    state.hits = [];
    input.value = "";
    tape.textContent = "";
    enter.classList.remove("is-ready");
    pager.hidden = false;
    paint();
    updateStatus();
    ripple();
    start();
  });

  if (reduce.addEventListener) {
    reduce.addEventListener("change", function () { if (reduce.matches) halt(); });
  }

  /* Start the intro once the window is on screen, pause when it leaves. */
  if ("IntersectionObserver" in window) {
    var timer = 0, first = true;
    var io = new IntersectionObserver(function (entries) {
      var on = entries[0].isIntersecting;
      clearTimeout(timer);
      if (on) {
        if (first) { first = false; ripple(); }
        timer = setTimeout(start, 1400);
      } else {
        halt();
      }
    }, { threshold: 0.4 });
    io.observe(win);
  }

  paint();
  updateStatus();
})();
