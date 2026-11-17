/* Folders and edit mode demo for the homepage.
   Uses the sample apps and glyphs that site.js publishes as window.InletSamples.
   Taps stand in for the Mac gestures: Edit replaces press and hold, the minus
   badge replaces the hide control. Every change can be undone for five seconds. */
(function () {
  "use strict";

  var S = window.InletSamples;
  var grid = document.getElementById("orgGrid");
  if (!S || !grid) return;

  var byName = {};
  S.APPS.forEach(function (a) { byName[a.n] = a; });

  function $(id) { return document.getElementById(id); }
  function el(tag, cls) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    return e;
  }

  var stage = document.querySelector(".org-stage");
  var editBtn = $("orgEdit");
  var hint = $("orgHint");
  var folderEl = $("orgFolder");
  var folderTitle = $("orgFolderName");
  var folderGrid = $("orgFolderGrid");
  var folderDone = $("orgFolderClose");
  var hiddenBox = $("orgHidden");
  var hiddenList = $("orgHiddenList");
  var toast = $("orgToast");
  var toastMsg = $("orgToastMsg");
  var undoBtn = $("orgUndo");

  /* ---------- State: top-level items, hidden apps, the open folder, and one undo step ---------- */
  var items = [
    { t: "app", n: "Notes" }, { t: "app", n: "Calendar" }, { t: "app", n: "Mail" },
    { t: "app", n: "Maps" }, { t: "app", n: "Weather" }, { t: "app", n: "Messages" },
    { t: "folder", n: "Creative", apps: ["Photos", "Music", "Journal", "Charts"] },
    { t: "app", n: "Reminders" }, { t: "app", n: "Terminal" }, { t: "app", n: "Code" },
    { t: "app", n: "Files" }, { t: "app", n: "Books" }
  ];
  var hidden = [{ n: "Lens", at: 12 }];
  var editing = false;
  var openFolderName = null;
  var snap = null;
  var toastTimer = null;

  function findFolder(name) {
    for (var i = 0; i < items.length; i++) {
      if (items[i].t === "folder" && items[i].n === name) return items[i];
    }
    return null;
  }
  function openFolder() { return openFolderName ? findFolder(openFolderName) : null; }

  /* Save the state before a change so Undo can bring it back. */
  function remember() {
    snap = JSON.stringify({ items: items, hidden: hidden, folder: openFolderName });
  }
  function say(msg) {
    toastMsg.textContent = msg;
    toast.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(hideToast, 5000);
  }
  function hideToast() {
    toast.hidden = true;
    snap = null;
    clearTimeout(toastTimer);
  }
  function undoLast() {
    if (!snap) return;
    var s = JSON.parse(snap);
    items = s.items;
    hidden = s.hidden;
    openFolderName = s.folder;
    if (!findFolder(openFolderName)) openFolderName = null;
    folderEl.hidden = !openFolderName;
    hideToast();
    render();
    editBtn.focus({ preventScroll: true });
  }

  /* ---------- Builders ---------- */
  function iconHTML(a, cls) {
    return '<span class="ico ' + (cls || "") + '" style="--a:' + a.a + ';--b:' + a.b + '">' +
      '<svg viewBox="0 0 24 24" aria-hidden="true">' + S.GLYPH[a.g] + '</svg></span>';
  }
  function appItem(name, onBadge, badgeLabel) {
    var a = byName[name];
    var wrap = el("div", "org-item");
    var cell = el("button", "cell");
    cell.type = "button";
    cell.setAttribute("aria-label", name);
    cell.innerHTML = iconHTML(a) + '<span class="name">' + name + "</span>";
    wrap.appendChild(cell);
    if (editing) {
      var badge = el("button", "org-badge");
      badge.type = "button";
      badge.textContent = "−";
      badge.setAttribute("aria-label", badgeLabel);
      badge.addEventListener("click", onBadge);
      wrap.appendChild(badge);
    }
    return wrap;
  }
  function folderItem(f) {
    var wrap = el("div", "org-item");
    var btn = el("button", "fold");
    btn.type = "button";
    btn.setAttribute("aria-label", f.n + " folder, " + f.apps.length + " apps");
    var mini = f.apps.slice(0, 4).map(function (n) {
      var a = byName[n];
      return '<i style="--a:' + a.a + ';--b:' + a.b + '"><svg viewBox="0 0 24 24" aria-hidden="true">' + S.GLYPH[a.g] + "</svg></i>";
    }).join("");
    btn.innerHTML = '<span class="fold-ico">' + mini + '</span><span class="name">' + f.n + "</span>";
    btn.addEventListener("click", function () { showFolder(f.n); });
    wrap.appendChild(btn);
    return wrap;
  }

  /* ---------- Render ---------- */
  function renderHidden() {
    hiddenBox.hidden = hidden.length === 0;
    hiddenList.innerHTML = "";
    hidden.forEach(function (h) {
      var b = el("button", "org-restore");
      b.type = "button";
      b.innerHTML = iconHTML(byName[h.n]) + "<span>" + h.n + "</span>";
      b.setAttribute("aria-label", "Restore " + h.n);
      b.addEventListener("click", function () { restore(h.n); });
      hiddenList.appendChild(b);
    });
  }
  function renderFolder() {
    var f = openFolder();
    if (!f) { folderEl.hidden = true; return; }
    folderEl.hidden = false;
    folderTitle.textContent = f.n;
    folderGrid.classList.toggle("is-editing", editing);
    folderGrid.innerHTML = "";
    f.apps.forEach(function (n) {
      folderGrid.appendChild(appItem(n, function () { moveOut(n); }, "Take " + n + " out of " + f.n));
    });
  }
  function render() {
    grid.classList.toggle("is-editing", editing);
    grid.innerHTML = "";
    items.forEach(function (it, i) {
      if (it.t === "folder") {
        grid.appendChild(folderItem(it));
      } else {
        grid.appendChild(appItem(it.n, function () { hide(i); }, "Hide " + it.n));
      }
    });
    renderHidden();
    renderFolder();
  }

  /* ---------- Actions ---------- */
  function hide(i) {
    remember();
    var name = items[i].n;
    items.splice(i, 1);
    hidden.push({ n: name, at: i });
    render();
    say("Hid " + name + ".");
    undoBtn.focus({ preventScroll: true });
  }
  function restore(name) {
    remember();
    var idx = -1;
    hidden.forEach(function (h, k) { if (h.n === name) idx = k; });
    if (idx < 0) return;
    var h = hidden.splice(idx, 1)[0];
    items.splice(Math.min(h.at, items.length), 0, { t: "app", n: name });
    render();
    say("Restored " + name + ".");
  }
  function moveOut(name) {
    var f = openFolder();
    if (!f) return;
    remember();
    var fi = items.indexOf(f);
    f.apps.splice(f.apps.indexOf(name), 1);
    if (f.apps.length === 0) {
      items.splice(fi, 1, { t: "app", n: name });
      openFolderName = null;
      folderEl.hidden = true;
    } else {
      items.splice(fi + 1, 0, { t: "app", n: name });
    }
    render();
    say("Took " + name + " out of " + f.n + ".");
  }
  function showFolder(name) {
    openFolderName = name;
    render();
    folderDone.focus({ preventScroll: true });
  }
  function closeFolder() {
    openFolderName = null;
    hideToast();
    render();
    editBtn.focus({ preventScroll: true });
  }

  /* ---------- Controls ---------- */
  editBtn.addEventListener("click", function () {
    editing = !editing;
    editBtn.textContent = editing ? "Done" : "Edit";
    editBtn.setAttribute("aria-pressed", String(editing));
    editBtn.classList.toggle("is-on", editing);
    hint.textContent = editing
      ? "Tap the minus badge to hide an app, or to take it out of a folder. Tap Done when you finish."
      : "Tap a folder to open it. Tap Edit to hide apps or take them out of folders.";
    render();
  });
  folderDone.addEventListener("click", closeFolder);
  undoBtn.addEventListener("click", undoLast);
  stage.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && openFolderName) closeFolder();
  });

  render();
})();
