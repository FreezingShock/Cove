(function () {
  "use strict";

  /* Site chrome: the mobile menu, the ⌘K command palette and the magnetic primary buttons.
     Works on every page. Each part is skipped when its markup or its input is missing,
     and nothing here changes the page's content. */

  var reduceQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  var fineQuery = window.matchMedia("(hover: hover) and (pointer: fine)");
  var mobileQuery = window.matchMedia("(max-width: 900px)");
  var nav = document.querySelector(".nav");
  if (!nav) return;

  var isMac = /Mac|iPhone|iPad|iPod/.test(navigator.platform || navigator.userAgent || "");
  Array.prototype.forEach.call(document.querySelectorAll("kbd[data-mod]"), function (k) {
    if (!isMac) k.textContent = "Ctrl";
  });

  /* ---------- Mobile menu: a glass sheet up to 900 px. Escape, a tap outside, or a link closes it ---------- */
  var menuBtn = nav.querySelector(".menu-btn");
  var linksEl = document.getElementById("siteLinks");

  function setMenu(open) {
    nav.classList.toggle("menu-open", open);
    if (menuBtn) {
      menuBtn.setAttribute("aria-expanded", String(open));
      menuBtn.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    }
  }
  function menuOpen() { return nav.classList.contains("menu-open"); }

  if (menuBtn && linksEl) {
    menuBtn.addEventListener("click", function () {
      var open = !menuOpen();
      setMenu(open);
      if (open) {
        var first = linksEl.querySelector("a");
        if (first) first.focus({ preventScroll: true });
      }
    });
    document.addEventListener("click", function (e) {
      if (!menuOpen()) return;
      if (nav.contains(e.target)) return; // the button and links handle their own clicks
      setMenu(false);
    });
    linksEl.addEventListener("click", function (e) {
      if (e.target.closest && e.target.closest("a")) setMenu(false);
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && menuOpen() && !(palette && palette.open())) {
        setMenu(false);
        menuBtn.focus({ preventScroll: true });
      }
    });
    function onMobileChange() { if (!mobileQuery.matches) setMenu(false); }
    if (mobileQuery.addEventListener) mobileQuery.addEventListener("change", onMobileChange);
    else mobileQuery.addListener(onMobileChange);
  }

  /* ---------- Command palette: ⌘K on Mac, Ctrl K elsewhere ---------- */
  var ICON = {
    home: '<path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8" /><path d="M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />',
    doc: '<path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z" /><path d="M14 2v5a1 1 0 0 0 1 1h5" />',
    arrow: '<path d="M5 12h14" /><path d="m12 5 7 7-7 7" />',
    grid: '<rect width="7" height="7" x="3" y="3" rx="1" /><rect width="7" height="7" x="14" y="3" rx="1" /><rect width="7" height="7" x="14" y="14" rx="1" /><rect width="7" height="7" x="3" y="14" rx="1" />',
    theme: '<path d="M12 2v2" /><path d="M14.837 16.385a6 6 0 1 1-7.223-7.222c.624-.147.97.66.715 1.248a4 4 0 0 0 5.26 5.259c.589-.255 1.396.09 1.248.715" /><path d="M16 12a4 4 0 0 0-4-4" /><path d="m19 5-1.256 1.256" /><path d="M20 12h2" />',
    replay: '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" /><path d="M3 3v5h5" />',
    lock: '<rect width="18" height="11" x="3" y="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" />',
    external: '<path d="M15 3h6v6" /><path d="M10 14 21 3" /><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />'
  };

  // Each item is a page, a section of the home page, or an action. Keywords help the filter.
  var file = (location.pathname.split("/").pop() || "").toLowerCase();
  if (file.indexOf(".html") === -1) file = "index.html";
  var onHome = file === "index.html";
  function toHome(hash) { return onHome ? hash : "index.html" + hash; }
  function themeAction(choice) {
    return function () { setChoice(choice); };
  }

  var ITEMS = [
    { group: "Pages", label: "Home", hint: "Page", icon: ICON.home, href: "index.html", keys: "home start inlet landing" },
    { group: "Pages", label: "Features", hint: "Page", icon: ICON.doc, href: "features.html", keys: "features search settings motion" },
    { group: "Pages", label: "Download", hint: "Page", icon: ICON.doc, href: "download.html", keys: "download install dmg mac requirements" },
    { group: "Pages", label: "Pricing", hint: "Page", icon: ICON.doc, href: "pricing.html", keys: "pricing price cost free supporter subscription plan" },
    { group: "Pages", label: "Changelog", hint: "Page", icon: ICON.doc, href: "changelog.html", keys: "changelog releases version notes" },
    { group: "Pages", label: "FAQ", hint: "Page", icon: ICON.doc, href: "faq.html", keys: "faq questions help" },
    { group: "Pages", label: "Privacy", hint: "Page", icon: ICON.lock, href: "privacy.html", keys: "privacy data tracking update check" },
    { group: "Pages", label: "Support", hint: "Page", icon: ICON.doc, href: "support.html", keys: "support help contact bug report" },

    { group: "Sections", label: "See it run", hint: "Demo", icon: ICON.arrow, href: toHome("#demo"), keys: "demo video see it run" },
    { group: "Sections", label: "Search", hint: "Section", icon: ICON.arrow, href: toHome("#features"), keys: "search filter files spotlight" },
    { group: "Sections", label: "Quick panel", hint: "Section", icon: ICON.arrow, href: toHome("#quick"), keys: "quick panel dock" },
    { group: "Sections", label: "Settings", hint: "Section", icon: ICON.arrow, href: toHome("#settings"), keys: "settings columns appearance" },
    { group: "Sections", label: "Privacy facts", hint: "Section", icon: ICON.arrow, href: toHome("#privacy"), keys: "privacy data accounts tracking" },
    { group: "Sections", label: "Motion", hint: "Section", icon: ICON.arrow, href: toHome("#motion"), keys: "motion spring animation reduce" },
    { group: "Sections", label: "Get Inlet", hint: "Section", icon: ICON.arrow, href: toHome("#get"), keys: "get inlet download github" },

    { group: "Actions", label: "Appearance: Auto", hint: "Theme", icon: ICON.theme, action: themeAction("auto"), keys: "theme appearance auto system" },
    { group: "Actions", label: "Appearance: Light", hint: "Theme", icon: ICON.theme, action: themeAction("light"), keys: "theme appearance light" },
    { group: "Actions", label: "Appearance: Dark", hint: "Theme", icon: ICON.theme, action: themeAction("dark"), keys: "theme appearance dark" },
    { group: "Actions", label: "GitHub repository", hint: "External", icon: ICON.external, href: "https://github.com/FreezingShock/Inlet", keys: "github source code repository" }
  ];
  if (onHome) {
    ITEMS.splice(7, 0, {
      group: "Actions", label: "Replay the grid", hint: "Action", icon: ICON.replay, keys: "replay grid hero animation",
      action: function () {
        var stage = document.getElementById("heroStage");
        var btn = document.getElementById("replayBtn");
        if (stage) stage.scrollIntoView({ block: "center", behavior: reduceQuery.matches ? "auto" : "smooth" });
        if (btn) setTimeout(function () { btn.click(); }, reduceQuery.matches ? 0 : 350);
      }
    });
  }

  // Scores a match: 0 label starts with the query, 1 label contains it, 2 keywords contain it,
  // 3 the letters appear in order in the label. Null means no match.
  function score(item, q) {
    var label = item.label.toLowerCase();
    if (label.indexOf(q) === 0) return 0;
    if (label.indexOf(q) !== -1) return 1;
    if (item.keys.indexOf(q) !== -1 || (item.hint && item.hint.toLowerCase().indexOf(q) === 0)) return 2;
    var i = 0;
    for (var n = 0; n < label.length && i < q.length; n++) if (label.charAt(n) === q.charAt(i)) i++;
    return i === q.length ? 3 : null;
  }

  var dlg = null, input = null, listEl = null, emptyEl = null;
  var shown = [], activeIdx = -1, lastFocus = null, skipRestore = false;
  var palette = null;

  function build() {
    dlg = document.createElement("dialog");
    dlg.className = "cmdk";
    dlg.setAttribute("aria-label", "Jump to a page, section or action");
    dlg.innerHTML =
      '<div class="glass cmdk-panel">' +
        '<div class="cmdk-search">' +
          '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m21 21-4.34-4.34" /><circle cx="11" cy="11" r="8" /></svg>' +
          '<input type="text" role="combobox" aria-expanded="true" aria-autocomplete="list" aria-controls="cmdkList" aria-label="Jump to a page, section or action" placeholder="Jump to a page, section or action" autocomplete="off" spellcheck="false">' +
          '<kbd>esc</kbd>' +
        '</div>' +
        '<ul class="cmdk-list" id="cmdkList" role="listbox" aria-label="Results"></ul>' +
        '<p class="cmdk-empty" hidden>No matches. Try a page name or a word like “privacy”.</p>' +
        '<div class="cmdk-foot">' +
          '<span><kbd>↑</kbd><kbd>↓</kbd> move</span>' +
          '<span><kbd>↵</kbd> open</span>' +
          '<span><kbd>esc</kbd> close</span>' +
        '</div>' +
      '</div>';
    document.body.appendChild(dlg);
    input = dlg.querySelector("input");
    listEl = dlg.querySelector("#cmdkList");
    emptyEl = dlg.querySelector(".cmdk-empty");

    input.addEventListener("input", render);
    input.addEventListener("keydown", function (e) {
      if (e.isComposing) return;
      if (e.key === "ArrowDown") { e.preventDefault(); setActive(activeIdx + 1, true); }
      else if (e.key === "ArrowUp") { e.preventDefault(); setActive(activeIdx - 1, true); }
      else if (e.key === "Enter") { e.preventDefault(); run(shown[activeIdx]); }
    });
    listEl.addEventListener("click", function (e) {
      var opt = e.target.closest && e.target.closest("[role=option]");
      if (opt) run(shown[Number(opt.dataset.i)]);
    });
    listEl.addEventListener("pointermove", function (e) {
      if (!fineQuery.matches) return;
      var opt = e.target.closest && e.target.closest("[role=option]");
      if (opt && Number(opt.dataset.i) !== activeIdx) setActive(Number(opt.dataset.i), false);
    });
    // A click on the backdrop lands on the dialog itself; the panel fills the dialog.
    dlg.addEventListener("click", function (e) { if (e.target === dlg) close(); });
    // Focus goes back to whatever opened the palette, however it closed.
    dlg.addEventListener("close", function () {
      if (!skipRestore && lastFocus && document.contains(lastFocus) && lastFocus.focus) {
        lastFocus.focus({ preventScroll: true });
      }
      skipRestore = false;
    });
  }

  function render() {
    var q = input.value.trim().toLowerCase();
    var ranked = [];
    ITEMS.forEach(function (it, idx) {
      var s = q ? score(it, q) : 0;
      if (s !== null) ranked.push({ it: it, s: s, idx: idx });
    });
    if (q) ranked.sort(function (a, b) { return a.s - b.s || a.idx - b.idx; });
    shown = ranked.map(function (r) { return r.it; });

    listEl.innerHTML = "";
    var lastGroup = null;
    shown.forEach(function (it, i) {
      if (!q && it.group !== lastGroup) {
        var h = document.createElement("li");
        h.className = "cmdk-group";
        h.setAttribute("role", "presentation");
        h.textContent = it.group;
        listEl.appendChild(h);
        lastGroup = it.group;
      }
      var li = document.createElement("li");
      li.id = "cmdk-opt-" + i;
      li.className = "cmdk-opt";
      li.setAttribute("role", "option");
      li.setAttribute("aria-selected", "false");
      li.dataset.i = String(i);
      li.innerHTML = '<span class="fi"><svg viewBox="0 0 24 24" aria-hidden="true">' + it.icon + '</svg></span>' +
        '<span class="cmdk-label"></span><span class="cmdk-hint"></span>';
      li.querySelector(".cmdk-label").textContent = it.label;
      li.querySelector(".cmdk-hint").textContent = it.hint;
      listEl.appendChild(li);
    });
    emptyEl.hidden = shown.length > 0;
    setActive(0, false);
  }

  function setActive(i, scroll) {
    var opts = listEl.querySelectorAll("[role=option]");
    if (!opts.length) {
      activeIdx = -1;
      input.removeAttribute("aria-activedescendant");
      return;
    }
    activeIdx = (i + opts.length) % opts.length;
    Array.prototype.forEach.call(opts, function (o, n) {
      o.setAttribute("aria-selected", String(n === activeIdx));
    });
    var cur = opts[activeIdx];
    input.setAttribute("aria-activedescendant", cur.id);
    if (scroll) cur.scrollIntoView({ block: "nearest" });
  }

  function run(it) {
    if (!it) return;
    if (it.action) { close(); it.action(); return; }
    var href = it.href;
    if (href.indexOf("https://") === 0) {
      close();
      window.open(href, "_blank", "noopener");
      return;
    }
    if (href.charAt(0) === "#") {
      // Same page: move focus to the section as well as scrolling to it.
      var id = href.slice(1);
      var target = document.getElementById(id);
      skipRestore = true;
      close();
      location.hash = id;
      if (target) {
        if (!target.hasAttribute("tabindex")) {
          target.setAttribute("tabindex", "-1");
          target.addEventListener("blur", function () { target.removeAttribute("tabindex"); }, { once: true });
        }
        target.focus({ preventScroll: true });
      }
      return;
    }
    location.href = href;
  }

  function open() {
    if (!dlg) build();
    if (dlg.open) return;
    lastFocus = document.activeElement;
    input.value = "";
    render();
    dlg.showModal();
    input.focus();
  }
  function close() {
    if (dlg && dlg.open) dlg.close();
  }
  function isOpen() { return !!(dlg && dlg.open); }
  palette = { open: isOpen };

  document.addEventListener("keydown", function (e) {
    if ((e.metaKey || e.ctrlKey) && !e.altKey && !e.shiftKey && (e.key === "k" || e.key === "K")) {
      e.preventDefault();
      if (isOpen()) close(); else open();
    }
  });
  var trigger = nav.querySelector(".search-btn");
  if (trigger) trigger.addEventListener("click", open);

  /* ---------- Appearance: one icon in the footer cycles Auto, Light and Dark. Auto follows the system. ---------- */
  var THEME_KEY = "inlet-page-theme"; // same key as site.js and pages.js
  var THEME_ORDER = ["auto", "light", "dark"];
  var THEME_NAME = { auto: "Auto", light: "Light", dark: "Dark" };
  var cycleBtn = document.querySelector("[data-theme-cycle]");

  function savedChoice() {
    var c = "auto";
    try { c = localStorage.getItem(THEME_KEY) || "auto"; } catch (err) { c = "auto"; }
    return THEME_ORDER.indexOf(c) === -1 ? "auto" : c;
  }
  function nextChoice(c) {
    return THEME_ORDER[(THEME_ORDER.indexOf(c) + 1) % THEME_ORDER.length];
  }
  function syncCycle() {
    if (!cycleBtn) return;
    var c = savedChoice();
    cycleBtn.dataset.mode = c;
    cycleBtn.setAttribute("aria-label", "Appearance: " + THEME_NAME[c] + ". Switch to " + THEME_NAME[nextChoice(c)]);
    cycleBtn.title = "Appearance: " + THEME_NAME[c];
  }
  function setChoice(choice) {
    if (choice === "auto") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.setAttribute("data-theme", choice);
    try { localStorage.setItem(THEME_KEY, choice); } catch (err) { /* private window or blocked storage */ }
    syncCycle();
  }
  if (cycleBtn) cycleBtn.addEventListener("click", function () { setChoice(nextChoice(savedChoice())); });
  // The home page's Settings demo sets the same key through site.js; keep the icon in step with it.
  document.addEventListener("click", function (e) {
    if (e.target.closest && e.target.closest("[data-theme-choice]")) setTimeout(syncCycle, 0);
  });
  syncCycle();

  /* ---------- Magnetic primary buttons: a few pixels toward the pointer, fine pointers only ---------- */
  if (fineQuery.matches && !reduceQuery.matches) {
    Array.prototype.forEach.call(document.querySelectorAll(".btn-primary"), function (b) {
      b.addEventListener("pointermove", function (e) {
        var r = b.getBoundingClientRect();
        var x = (e.clientX - (r.left + r.width / 2)) / r.width;
        var y = (e.clientY - (r.top + r.height / 2)) / r.height;
        b.style.setProperty("--mx", (x * 6).toFixed(2) + "px");
        b.style.setProperty("--my", (y * 6).toFixed(2) + "px");
      });
      b.addEventListener("pointerleave", function () {
        b.style.setProperty("--mx", "0px");
        b.style.setProperty("--my", "0px");
      });
    });
  }
})();
