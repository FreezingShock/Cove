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
    if (open) showHeader();
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
    home: '<path d="M3 11l9-8 9 8v10H3z"/><rect class="k-a" x="10" y="14" width="4" height="7"/>',
    doc: '<path d="M5 3h10l4 4v14H5zM15 3v4h4M8 11h8M8 14h8"/><rect class="k-a" x="8" y="17" width="5" height="2"/>',
    arrow: '<g class="k-m"><path d="M4 12h16M13 5l7 7-7 7"/></g>',
    grid: '<rect class="k-a" x="3" y="3" width="8" height="8"/><path d="M3 3h8v8H3zM13 3h8v8h-8zM3 13h8v8H3zM13 13h8v8h-8z"/>',
    theme: '<path class="k-a" d="M3 3h18v18z"/><path d="M3 3h18v18H3z"/>',
    replay: '<g class="k-m"><path d="M20 11V5h-6M4 13v6h6"/><path d="M20 5l-3 2.5A8 8 0 0 0 4.5 10M4 19l3-2.5A8 8 0 0 0 19.5 14"/></g>',
    lock: '<rect x="4" y="11" width="16" height="10"/><path d="M8 11V4h8v7"/><rect class="k-a" x="10.5" y="14.5" width="3" height="3.5"/>',
    external: '<path d="M10 4H4v16h16v-6"/><g class="k-m"><path d="M14 3h7v7M21 3l-9 9"/></g>'
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
    { group: "Sections", label: "Motion", hint: "Section", icon: ICON.arrow, href: "designers.html", keys: "motion spring animation reduce" },
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
          '<svg class="kit" viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="3" width="13" height="13"/><path d="M16 16l5 5" class="k-m"/><rect class="k-a" x="6.5" y="6.5" width="6" height="6"/></svg>' +
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
      li.innerHTML = '<span class="fi"><svg class="kit" viewBox="0 0 24 24" aria-hidden="true">' + it.icon + '</svg></span>' +
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

  /* ---------- Header states ----------
     top: the full pill, with Download outlined.
     mid: scrolled. The pill compacts, a hairline band fades in, a progress line fills as you read,
          and the label names the section you are in (or the page, off the home page).
     end: within 96 px of the bottom. The header is always on screen, Download turns solid,
          and the progress line is full.
     Scrolling down past the first screen hides the header in the middle of a page. Scrolling up brings it back.
     An open menu, the ⌘K palette and the pinned demo keep it on screen. */
  var lastY = window.scrollY || 0;
  var headerQueued = false;
  var MOVE = 6;   // px of scroll before the header reacts, so small jitters do nothing
  var TOP = 120;  // above this the header is always shown
  var END = 96;   // within this many px of the bottom the header is in its end state

  var innerEl = nav.querySelector(".nav-inner");
  var progressEl = document.createElement("span");
  progressEl.className = "nav-progress";
  progressEl.setAttribute("aria-hidden", "true");
  var hereEl = document.createElement("span");
  hereEl.className = "nav-here";
  hereEl.setAttribute("aria-hidden", "true");
  // Phones get a "Download Inlet" button at the end of the page, since they cannot install the disk image.
  // It links to the download section, which hands the link to the phone.
  var ctaEl = document.createElement("a");
  ctaEl.className = "btn btn-primary btn-sm nav-cta";
  ctaEl.href = onHome ? "#get" : "index.html#get";
  ctaEl.textContent = "Download Inlet";
  if (innerEl) {
    innerEl.insertBefore(progressEl, innerEl.firstChild);
    var brandEl = innerEl.querySelector(".brand");
    if (brandEl) brandEl.insertAdjacentElement("afterend", hereEl);
    var rightEl = innerEl.querySelector(".nav-right");
    var menuBtnEl = innerEl.querySelector(".menu-btn");
    if (rightEl) rightEl.insertBefore(ctaEl, menuBtnEl || null);
  }

  // Home page sections, by id. Other pages show their own page name instead.
  var SECTION_LABEL = {
    demo: "Demo", features: "Search", quick: "Quick panel", organize: "Organize", settings: "Settings",
    uses: "Uses", privacy: "Privacy", "for": "Who it's for", get: "Get Inlet"
  };
  var sectionEls = Array.prototype.filter.call(document.querySelectorAll("main section[id]"), function (s) {
    return SECTION_LABEL.hasOwnProperty(s.id);
  });
  var pageLabel = "";
  var activeLink = linksEl ? linksEl.querySelector(":scope > a[aria-current='page'], :scope > a[aria-current='true']") : null;
  if (activeLink) pageLabel = activeLink.textContent.trim();

  function sectionLabelAt(line) {
    var label = "";
    for (var i = 0; i < sectionEls.length; i++) {
      if (sectionEls[i].getBoundingClientRect().top <= line) label = SECTION_LABEL[sectionEls[i].id];
    }
    return label;
  }
  function setHere(text) {
    if (hereEl.textContent !== text) hereEl.textContent = text;
  }
  function setPhase(phase) {
    if (nav.getAttribute("data-phase") !== phase) nav.setAttribute("data-phase", phase);
  }

  function showHeader() { nav.classList.remove("is-hidden"); }
  function hideHeader() {
    if (menuOpen() || (palette && palette.open())) return;
    if (document.querySelector("[data-scrub].is-pinned")) return; // the pinned demo sits right under the header
    nav.classList.add("is-hidden");
  }
  function onHeaderScroll() {
    headerQueued = false;
    var y = window.scrollY || 0;
    var max = Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
    var atEnd = max > 0 && y >= max - END;
    var phase = atEnd ? "end" : (y < 8 ? "top" : "mid");
    setPhase(phase);
    progressEl.style.transform = "scaleX(" + (max > 0 ? Math.min(1, y / max) : 1).toFixed(4) + ")";
    if (phase === "top") setHere("");
    else if (sectionEls.length) setHere(sectionLabelAt(window.innerHeight * 0.4));
    else setHere(pageLabel);

    if (atEnd || y <= TOP) { showHeader(); lastY = y; return; }
    if (Math.abs(y - lastY) < MOVE) return;
    if (y > lastY) hideHeader(); else showHeader();
    lastY = y;
  }
  function queueHeader() {
    if (headerQueued) return;
    headerQueued = true;
    requestAnimationFrame(onHeaderScroll);
  }
  window.addEventListener("scroll", queueHeader, { passive: true });
  window.addEventListener("resize", queueHeader);
  // Keyboard focus anywhere in the header brings it back, so nothing tabs into a hidden bar.
  nav.addEventListener("focusin", showHeader);
  onHeaderScroll();

  /* ---------- Desktop links: one pill slides to the link under the pointer or focus, and rests on the current page ---------- */
  if (linksEl) {
    var pill = document.createElement("span");
    pill.className = "links-ind no-anim";
    pill.setAttribute("aria-hidden", "true");
    linksEl.insertBefore(pill, linksEl.firstChild);

    var linkEls = Array.prototype.slice.call(linksEl.children).filter(function (el) { return el.tagName === "A"; });
    linkEls.forEach(function (a, i) { a.style.setProperty("--i", String(i)); });
    var menuGet = linksEl.querySelector(".menu-get");
    if (menuGet) menuGet.style.setProperty("--i", String(linkEls.length));

    function currentLink() {
      return linksEl.querySelector(":scope > a[aria-current='page'], :scope > a[aria-current='true']");
    }
    function linkOf(target) {
      var a = target && target.closest ? target.closest("a") : null;
      return a && a.parentNode === linksEl ? a : null;
    }
    function placePill(a) {
      if (!a || mobileQuery.matches) { pill.classList.remove("is-on"); return; }
      pill.style.width = a.offsetWidth + "px";
      pill.style.transform = "translate3d(" + a.offsetLeft + "px, 0, 0)";
      pill.classList.add("is-on");
    }
    function restPill() { placePill(currentLink()); }

    linksEl.addEventListener("pointerover", function (e) {
      if (!fineQuery.matches) return;
      var a = linkOf(e.target);
      if (a) placePill(a);
    });
    linksEl.addEventListener("pointerleave", restPill);
    linksEl.addEventListener("focusin", function (e) {
      var a = linkOf(e.target);
      if (a) placePill(a);
    });
    linksEl.addEventListener("focusout", restPill);
    window.addEventListener("resize", restPill);
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(restPill);

    restPill();
    // Place the pill before the first paint, then let it animate on later moves.
    requestAnimationFrame(function () { pill.classList.remove("no-anim"); });
  }

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
