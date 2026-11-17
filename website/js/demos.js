(function () {
  "use strict";

  /* Feature demos: small, real samples of Inlet that sit beside the feature copy.
     One engine (mount, tile builders, FLIP, autoplay) drives every demo: the search field,
     the quick panel, and groups with Edit mode. Each demo starts when it scrolls into view,
     plays a short loop until the visitor touches it, and never moves on its own with Reduce
     Motion on. Every control works with a mouse, a finger or the keyboard. */

  var G = {
    note: '<path d="M13.4 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7.4" /><path d="M2 6h4" /><path d="M2 10h4" /><path d="M2 14h4" /><path d="M2 18h4" /><path d="M21.4 5.6a1 1 0 1 0-3-3l-5 5a2 2 0 0 0-.5.9l-.8 2.9a.5.5 0 0 0 .6.6l2.9-.8a2 2 0 0 0 .9-.5z" />',
    calendar: '<path d="M8 2v3" /><path d="M16 2v3" /><rect x="3" y="3" width="18" height="18" rx="2" /><path d="M3 9h18" />',
    music: '<path d="M21 16V3a1 1 0 0 0-1.3-1L9.7 4.9a1 1 0 0 0-.7 1V19" /><circle cx="18" cy="16" r="3" /><circle cx="6" cy="19" r="3" />',
    photos: '<rect width="18" height="18" x="3" y="3" rx="2" /><circle cx="9" cy="9" r="2" /><path d="m21 15-3.1-3.1a2 2 0 0 0-2.8 0L6 21" />',
    terminal: '<path d="M12 19h8" /><path d="m4 17 6-6-6-6" />',
    mail: '<path d="m22 7-9 5.7a2 2 0 0 1-2 0L2 7" /><rect x="2" y="4" width="20" height="16" rx="2" />',
    maps: '<path d="M20 10c0 5-5.5 10.2-7.4 11.8a1 1 0 0 1-1.2 0C9.5 20.2 4 15 4 10a8 8 0 0 1 16 0" /><circle cx="12" cy="10" r="3" />',
    reminders: '<path d="M13 5h8" /><path d="M13 12h8" /><path d="M13 19h8" /><path d="m3 17 2 2 4-4" /><path d="m3 7 2 2 4-4" />',
    files: '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.7-.9L9.6 3.9A2 2 0 0 0 7.9 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z" />',
    chart: '<path d="M3 3v16a2 2 0 0 0 2 2h16" /><path d="M18 17V9" /><path d="M13 17V5" /><path d="M8 17v-3" />',
    code: '<path d="m16 18 6-6-6-6" /><path d="m8 6-6 6 6 6" />',
    messages: '<path d="M3 16.3a2 2 0 0 1 .1 1.2l-1.1 3.3a1 1 0 0 0 1.2 1.2l3.4-1a2 2 0 0 1 1.1.1 10 10 0 1 0-4.8-4.7" />',
    journal: '<path d="M2 6h4" /><path d="M2 10h4" /><path d="M2 14h4" /><path d="M2 18h4" /><rect width="16" height="20" x="4" y="2" rx="2" /><path d="M16 2v20" />',
    doc: '<path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.7.7l3.6 3.6A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z" /><path d="M14 2v5a1 1 0 0 0 1 1h5" />'
  };
  var APPS = [
    { n: "Notes", g: "note", a: "#FFD36E", b: "#F0A020", k: "Work" },
    { n: "Calendar", g: "calendar", a: "#FF8F84", b: "#E0443E", k: "Work" },
    { n: "Music", g: "music", a: "#FF8DBB", b: "#D23D7F", k: "Creative" },
    { n: "Photos", g: "photos", a: "#9BE8A6", b: "#2C9E5C", k: "Creative" },
    { n: "Terminal", g: "terminal", a: "#5A6275", b: "#1A1F29", k: "Tools" },
    { n: "Mail", g: "mail", a: "#8CC8FF", b: "#2F6FE0", k: "Work" },
    { n: "Maps", g: "maps", a: "#A8E9B4", b: "#1E8C6E", k: "Tools" },
    { n: "Reminders", g: "reminders", a: "#BCAEFF", b: "#5B45D6", k: "Work" },
    { n: "Files", g: "files", a: "#84DDFF", b: "#0A7FCF", k: "Tools" },
    { n: "Charts", g: "chart", a: "#CDF58F", b: "#4E9A1F", k: "Creative" },
    { n: "Code", g: "code", a: "#8E98FF", b: "#3340A8", k: "Tools" },
    { n: "Messages", g: "messages", a: "#83EEA2", b: "#1FA34A", k: "Social" },
    { n: "Journal", g: "journal", a: "#FFB9CC", b: "#C4456B", k: "Creative" }
  ];
  var FILES = [
    { n: "Notes from Tuesday.txt", p: "Documents" },
    { n: "Lab notes, week 3.txt", p: "Classes" },
    { n: "Packing list.md", p: "Desktop" },
    { n: "Cover letter final.pdf", p: "Downloads" },
    { n: "Budget 2026.csv", p: "Money" },
    { n: "Trip photos, May.pdf", p: "Downloads" }
  ];
  var BY = {};
  APPS.forEach(function (a) { BY[a.n] = a; });

  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
  var SPRING = "cubic-bezier(.22,.9,.24,1)";

  /* ---------- Engine ---------- */
  function el(tag, cls, html) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    return e;
  }
  function esc(s) { return s.replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function icon(app) {
    return '<span class="dm-ico" style="--a:' + app.a + ';--b:' + app.b + '"><svg viewBox="0 0 24 24" aria-hidden="true">' + G[app.g] + "</svg></span>";
  }
  function tile(app) {
    var b = el("button", "dm-tile", icon(app) + '<span class="dm-name">' + app.n + "</span>");
    b.type = "button";
    b.dataset.name = app.n;
    return b;
  }
  function anim(node, frames, ms, easing) {
    if (reduce.matches || !node.animate) return null;
    return node.animate(frames, { duration: ms || 320, easing: easing || SPRING, fill: "none" });
  }
  /* FLIP: measure, change the DOM, then slide every tile from where it was. */
  function flip(nodes, change) {
    var first = nodes().map(function (n) { return [n, n.getBoundingClientRect()]; });
    change();
    first.forEach(function (p) {
      if (!p[0].isConnected) return;
      var r = p[0].getBoundingClientRect();
      var dx = p[1].left - r.left, dy = p[1].top - r.top;
      if (dx || dy) anim(p[0], [{ translate: dx + "px " + dy + "px" }, { translate: "0 0" }], 380);
    });
  }
  /* Runs `steps` (an array of [delay, fn]) in a loop until stop() is called. Never starts with Reduce Motion. */
  function player(steps, pause) {
    var timer = null, live = false, i = 0;
    function next() {
      if (!live) return;
      var s = steps[i % steps.length];
      i++;
      timer = setTimeout(function () { if (live) { s[1](); next(); } }, s[0]);
    }
    return {
      start: function () { if (live || reduce.matches) return; live = true; next(); },
      stop: function () { live = false; clearTimeout(timer); },
      reset: function () { i = 0; }
    };
  }
  /* Start when visible, pause when off screen, stop for good once touched. */
  function mount(root, setup) {
    if (!root) return;
    var ctl = setup(root) || {};
    var touched = false;
    function stop() { touched = true; if (ctl.stop) ctl.stop(); }
    ["pointerdown", "keydown", "input", "focusin"].forEach(function (t) { root.addEventListener(t, stop, { passive: true }); });
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (es) {
        es.forEach(function (e) {
          if (touched) return;
          if (e.isIntersecting) { if (ctl.start) ctl.start(); } else if (ctl.pause) ctl.pause();
        });
      }, { threshold: 0.45 }).observe(root);
    }
  }

  /* ---------- Demo: search ---------- */
  function searchDemo(root) {
    root.innerHTML =
      '<div class="dm-bar"><span class="dm-dots" aria-hidden="true"><i></i><i></i><i></i></span><span class="dm-title">Inlet search</span><span class="dm-hint">Try it</span></div>' +
      '<div class="dm-body"><label class="dm-field"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" /></svg>' +
      '<input type="search" placeholder="Search apps and files" aria-label="Search the sample apps and files" autocomplete="off" spellcheck="false"><kbd class="dm-key">Return</kbd></label>' +
      '<div class="dm-chips" role="group" aria-label="Try a search"></div>' +
      '<div class="dm-grid dm-grid-6" data-role="apps"></div>' +
      '<div class="dm-files" data-role="files"></div></div>' +
      '<p class="dm-status" aria-live="polite" data-role="status"></p>';
    var input = root.querySelector("input"), apps = root.querySelector('[data-role="apps"]'),
        files = root.querySelector('[data-role="files"]'), status = root.querySelector('[data-role="status"]'),
        chips = root.querySelector(".dm-chips");
    var nodes = APPS.map(tile);
    nodes.forEach(function (n) { apps.appendChild(n); });
    ["photos", "notes", "budget"].forEach(function (w) {
      var c = el("button", "dm-chip", w); c.type = "button";
      c.addEventListener("click", function () { type(w, true); });
      chips.appendChild(c);
    });
    function score(name, q) {
      var s = name.toLowerCase(), i = s.indexOf(q);
      return i === 0 ? 2 : i > 0 ? 1 : 0;
    }
    function run(q) {
      q = q.trim().toLowerCase();
      var hits = 0, top = null, best = 0;
      nodes.forEach(function (n) {
        var sc = q ? score(n.dataset.name, q) : 1;
        n.hidden = !sc; n.classList.remove("is-top");
        if (sc) hits++;
        if (q && sc > best) { best = sc; top = n; }
      });
      if (top) top.classList.add("is-top");
      var fl = q ? FILES.filter(function (f) { return f.n.toLowerCase().indexOf(q) > -1; }) : [];
      files.innerHTML = fl.map(function (f) {
        return '<div class="dm-file"><svg viewBox="0 0 24 24" aria-hidden="true">' + G.doc + "</svg><span>" + esc(f.n) + "</span><em>" + f.p + "</em></div>";
      }).join("");
      files.hidden = !fl.length;
      root.querySelector(".dm-key").classList.toggle("on", !!top);
      status.textContent = q ? (hits ? hits + (hits === 1 ? " app" : " apps") + (fl.length ? " and " + fl.length + (fl.length === 1 ? " file" : " files") : "") : (fl.length ? fl.length + " files" : "Nothing matches")) : APPS.length + " apps";
    }
    var tmr = null;
    function type(word, fromUser) {
      clearTimeout(tmr);
      if (reduce.matches || fromUser === true) { input.value = word; run(word); return; }
      input.value = ""; run("");
      var i = 0;
      (function step() { i++; input.value = word.slice(0, i); run(input.value); if (i < word.length) tmr = setTimeout(step, 150); })();
    }
    input.addEventListener("input", function () { run(input.value); });
    input.addEventListener("keydown", function (e) {
      if (e.key === "Enter") {
        var t = apps.querySelector(".is-top");
        if (t) { anim(t, [{ scale: 1 }, { scale: 0.88 }, { scale: 1 }], 260); status.textContent = "Opened " + t.dataset.name; }
      }
    });
    apps.addEventListener("click", function (e) {
      var t = e.target.closest(".dm-tile");
      if (t) { anim(t, [{ scale: 1 }, { scale: 0.88 }, { scale: 1 }], 260); status.textContent = "Opened " + t.dataset.name; }
    });
    run("");
    var words = ["pho", "notes", "bud", ""];
    return player(words.map(function (w) { return [w ? 1700 : 1400, function () { type(w); }]; }), 0);
  }

  /* ---------- Demo: quick panel ---------- */
  function quickDemo(root) {
    var recents = ["Notes", "Mail", "Photos", "Terminal", "Maps", "Music", "Code", "Files"];
    root.innerHTML =
      '<div class="dm-desk"><div class="dm-wall" aria-hidden="true"></div>' +
      '<div class="dm-panel" data-role="panel"><div class="dm-qhead"><span class="dm-qsearch"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" /></svg>Search</span></div>' +
      '<p class="dm-label">Recent apps</p><div class="dm-grid dm-grid-4" data-role="recent"></div>' +
      '<p class="dm-label">Recent files</p><div class="dm-files" data-role="rfiles"></div>' +
      '<button class="dm-all" type="button" data-role="all">Show All Apps</button>' +
      '<div class="dm-full" data-role="full" hidden><div class="dm-grid dm-grid-5" data-role="fullgrid"></div><button class="dm-all dm-back" type="button" data-role="back">Back</button></div></div>' +
      '<div class="dm-dock" aria-label="Dock"><button class="dm-dockbtn" type="button" data-role="dock" aria-expanded="true" aria-label="Inlet in the Dock. Open or close the quick panel">' +
      '<span class="dm-ico" style="--a:#46E6D6;--b:#1FB6A6"><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="4" width="7" height="7" /><rect x="13" y="4" width="7" height="7" /><rect x="4" y="13" width="7" height="7" /><rect x="13" y="13" width="7" height="7" /></svg></span></button></div></div>' +
      '<p class="dm-status" aria-live="polite" data-role="status">Click an app. It moves to the front of Recent apps.</p>';
    var q = function (r) { return root.querySelector('[data-role="' + r + '"]'); };
    var panel = q("panel"), rc = q("recent"), rf = q("rfiles"), full = q("full"), fg = q("fullgrid"), status = q("status"), dock = q("dock");
    FILES.slice(0, 3).forEach(function (f) {
      rf.appendChild(el("div", "dm-file", '<svg viewBox="0 0 24 24" aria-hidden="true">' + G.doc + "</svg><span>" + esc(f.n) + "</span><em>" + f.p + "</em>"));
    });
    function paint() {
      rc.innerHTML = "";
      recents.slice(0, 4).forEach(function (n) { rc.appendChild(tile(BY[n])); });
    }
    function launch(name) {
      flip(function () { return [].slice.call(rc.children); }, function () {
        recents = [name].concat(recents.filter(function (n) { return n !== name; }));
        paint();
      });
      status.textContent = "Opened " + name + ". Recent apps now start with it.";
    }
    function showFull(on) {
      full.hidden = !on;
      panel.classList.toggle("is-full", on);
      if (on) anim(full, [{ opacity: 0, translate: "0 10px" }, { opacity: 1, translate: "0 0" }], 360);
    }
    function togglePanel(open) {
      panel.hidden = false;
      if (open === undefined) open = panel.classList.contains("is-down");
      dock.setAttribute("aria-expanded", open ? "true" : "false");
      if (open) {
        panel.classList.remove("is-down");
        anim(panel, [{ opacity: 0, translate: "0 24px", scale: 0.96 }, { opacity: 1, translate: "0 0", scale: 1 }], 480);
      } else {
        var a = anim(panel, [{ opacity: 1, translate: "0 0" }, { opacity: 0, translate: "0 24px" }], 260);
        if (a) { a.onfinish = function () { panel.classList.add("is-down"); }; } else panel.classList.add("is-down");
      }
    }
    APPS.forEach(function (a) { fg.appendChild(tile(a)); });
    paint();
    panel.addEventListener("click", function (e) {
      var t = e.target.closest(".dm-tile");
      if (t) launch(t.dataset.name);
    });
    q("all").addEventListener("click", function () { showFull(true); });
    q("back").addEventListener("click", function () { showFull(false); });
    dock.addEventListener("click", function () { togglePanel(); });
    var seq = ["Maps", "Code", "Music"];
    return player([
      [1500, function () { launch(seq[0]); }],
      [1500, function () { launch(seq[1]); }],
      [1500, function () { showFull(true); }],
      [1900, function () { showFull(false); launch(seq[2]); }],
      [1700, function () { togglePanel(false); }],
      [900, function () { togglePanel(true); }]
    ]);
  }

  /* ---------- Demo: groups and Edit mode ---------- */
  function arrangeDemo(root) {
    var GROUPS = ["All", "Work", "Creative", "Tools", "Social"];
    var order = APPS.map(function (a) { return a.n; });
    var hidden = null, editing = false, group = "All";
    root.innerHTML =
      '<div class="dm-bar"><span class="dm-dots" aria-hidden="true"><i></i><i></i><i></i></span><span class="dm-title">Inlet grid</span>' +
      '<button class="dm-edit" type="button" data-role="edit" aria-pressed="false">Edit</button></div>' +
      '<div class="dm-body"><div class="dm-groups" role="tablist" aria-label="Groups" data-role="groups"></div>' +
      '<div class="dm-grid dm-grid-6 dm-sortable" data-role="grid"></div></div>' +
      '<p class="dm-status" aria-live="polite" data-role="status">Pick a group, or press Edit and drag icons into a new order.</p>' +
      '<div class="dm-toast" data-role="toast" hidden><span data-role="msg"></span><button type="button" data-role="undo">Undo</button></div>';
    var q = function (r) { return root.querySelector('[data-role="' + r + '"]'); };
    var gbar = q("groups"), grid = q("grid"), editBtn = q("edit"), status = q("status"), toast = q("toast");
    var map = {};
    function build() {
      grid.innerHTML = "";
      order.forEach(function (n) {
        var t = tile(BY[n]);
        var x = el("span", "dm-minus", "<svg viewBox='0 0 24 24' aria-hidden='true'><path d='M5 12h14' /></svg>");
        x.setAttribute("role", "button"); x.setAttribute("aria-label", "Hide " + n); x.tabIndex = -1;
        t.appendChild(x);
        map[n] = t; grid.appendChild(t);
      });
    }
    function filt() {
      Object.keys(map).forEach(function (n) { map[n].hidden = group !== "All" && BY[n].k !== group; });
      var c = 0; Object.keys(map).forEach(function (n) { if (!map[n].hidden) c++; });
      status.textContent = group === "All" ? "All groups, " + c + " apps" : group + ", " + c + " apps";
    }
    function setGroup(g, silent) {
      flip(function () { return order.map(function (n) { return map[n]; }).filter(function (n) { return !n.hidden; }); }, function () { group = g; filt(); });
      [].forEach.call(gbar.children, function (b) { b.setAttribute("aria-selected", b.dataset.g === g ? "true" : "false"); b.classList.toggle("on", b.dataset.g === g); });
      if (silent !== true) status.textContent = status.textContent;
    }
    GROUPS.forEach(function (g) {
      var b = el("button", "dm-gchip", g); b.type = "button"; b.dataset.g = g; b.setAttribute("role", "tab");
      b.addEventListener("click", function () { setGroup(g); });
      gbar.appendChild(b);
    });
    function setEdit(on) {
      editing = on; root.classList.toggle("is-editing", on);
      editBtn.textContent = on ? "Done" : "Edit"; editBtn.setAttribute("aria-pressed", on ? "true" : "false");
      grid.querySelectorAll(".dm-minus").forEach(function (m) { m.tabIndex = on ? 0 : -1; });
      if (on) status.textContent = "Drag an icon to move it. The minus badge hides an app.";
      else filt();
    }
    editBtn.addEventListener("click", function () { setEdit(!editing); });
    var tt = null;
    function say(msg) {
      q("msg").textContent = msg; toast.hidden = false;
      anim(toast, [{ opacity: 0, translate: "0 8px" }, { opacity: 1, translate: "0 0" }], 300);
      clearTimeout(tt); tt = setTimeout(function () { toast.hidden = true; }, 4500);
    }
    function hide(n) {
      var at = order.indexOf(n);
      anim(map[n], [{ scale: 1, opacity: 1 }, { scale: 0.6, opacity: 0 }], 240);
      setTimeout(function () {
        flip(function () { return order.map(function (x) { return map[x]; }); }, function () {
          map[n].hidden = true; order.splice(at, 1); hidden = { n: n, at: at };
        });
        say(n + " is hidden.");
      }, reduce.matches ? 0 : 200);
    }
    q("undo").addEventListener("click", function () {
      if (!hidden) return;
      flip(function () { return order.map(function (x) { return map[x]; }); }, function () {
        order.splice(hidden.at, 0, hidden.n);
        map[hidden.n].hidden = false;
        grid.insertBefore(map[hidden.n], grid.children[hidden.at] || null);
        filt();
      });
      hidden = null; toast.hidden = true;
    });
    /* Drag to reorder: the grabbed tile follows the pointer, the others slide aside. */
    var drag = null;
    grid.addEventListener("pointerdown", function (e) {
      var t = e.target.closest(".dm-tile");
      if (!editing || !t) return;
      if (e.target.closest(".dm-minus")) { hide(t.dataset.name); e.preventDefault(); return; }
      var r = t.getBoundingClientRect();
      drag = { t: t, x: e.clientX, y: e.clientY, id: e.pointerId, ox: 0, oy: 0 };
      t.setPointerCapture(e.pointerId);
      t.classList.add("is-drag");
    });
    grid.addEventListener("pointermove", function (e) {
      if (!drag || e.pointerId !== drag.id) return;
      var t = drag.t;
      t.style.translate = (e.clientX - drag.x) + "px " + (e.clientY - drag.y) + "px";
      var cx = e.clientX, cy = e.clientY;
      var over = null;
      order.forEach(function (n) {
        var o = map[n]; if (o === t || o.hidden) return;
        var r = o.getBoundingClientRect();
        if (cx > r.left && cx < r.right && cy > r.top && cy < r.bottom) over = o;
      });
      if (over) {
        var tr = t.getBoundingClientRect();
        var items = order.map(function (n) { return map[n]; });
        var from = items.indexOf(t), to = items.indexOf(over);
        var before = t.getBoundingClientRect();
        flip(function () { return items.filter(function (i) { return i !== t && !i.hidden; }); }, function () {
          order.splice(from, 1); order.splice(to, 0, t.dataset.name);
          grid.insertBefore(t, from < to ? over.nextSibling : over);
        });
        var after = t.getBoundingClientRect();
        drag.x += after.left - before.left; drag.y += after.top - before.top;
        t.style.translate = (e.clientX - drag.x) + "px " + (e.clientY - drag.y) + "px";
      }
    });
    function drop(e) {
      if (!drag || e.pointerId !== drag.id) return;
      var t = drag.t; drag = null;
      t.classList.remove("is-drag");
      var cur = t.style.translate; t.style.translate = "";
      if (cur) { var p = cur.split(" "); anim(t, [{ translate: cur }, { translate: "0 0" }], 320); }
    }
    grid.addEventListener("pointerup", drop);
    grid.addEventListener("pointercancel", drop);
    build(); setGroup("All", true);
    var go = function (g) { return function () { setGroup(g); }; };
    return player([
      [1500, go("Creative")], [1700, go("Work")], [1600, go("All")],
      [1200, function () { setEdit(true); }],
      [1500, function () {
        flip(function () { return order.map(function (n) { return map[n]; }); }, function () {
          var n = order.splice(order.length - 1, 1)[0]; order.unshift(n); grid.insertBefore(map[n], grid.firstChild);
        });
      }],
      [1700, function () { setEdit(false); }]
    ]);
  }

  /* ---------- Mount ---------- */
  function boot() {
    mount(document.getElementById("demoSearch"), searchDemo);
    mount(document.getElementById("demoQuick"), quickDemo);
    mount(document.getElementById("demoArrange"), arrangeDemo);
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot); else boot();
})();
