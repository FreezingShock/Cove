(function () {
  "use strict";

  /* Hero window: a live search loop. It types a word one key at a time, the grid
     reflows around the matches, the top hit is pressed, and a light ribbon sweeps
     the window edge. The loop stops for good as soon as a visitor takes the field.
     Runs on the grid that site.js fills; uses only WAAPI on `translate`, `scale`
     and `opacity`, so it never fights the `transform` that site.js sets on cells. */

  var win = document.getElementById("heroWin");
  var grid = document.getElementById("heroGrid");
  var input = document.getElementById("heroQ");
  var tape = document.getElementById("heroTape");
  var status = document.getElementById("heroStatus");
  var enter = win && win.querySelector(".win-enter");
  var glintEl = win && win.querySelector(".glint");
  if (!win || !grid || !input || !tape || !status || !enter) return;

  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
  var EASE = "cubic-bezier(0.2, 0.8, 0.2, 1)";
  var WORD = "photos";
  var total = grid.querySelectorAll(".cell").length;
  var running = false;
  var stopped = false;
  var runId = 0;

  function cells() { return Array.prototype.slice.call(grid.querySelectorAll(".cell")); }
  function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
  function anim(el, frames, opts) {
    if (!el || !el.animate || reduce.matches) return;
    el.animate(frames, opts);
  }

  function setEnter(top) {
    enter.classList.toggle("is-ready", !!top);
  }

  /* Filter the grid. Cells that stay visible glide from their old slot (FLIP on
     `translate`); new arrivals spring in from a smaller scale. Returns the top hit. */
  function filter(q) {
    var list = cells();
    var before = new Map();
    list.forEach(function (c) {
      if (!c.hidden) before.set(c, { x: c.offsetLeft, y: c.offsetTop });
    });
    var first = null;
    list.forEach(function (c) {
      var match = !q || c.dataset.name.toLowerCase().indexOf(q) !== -1;
      c.hidden = !match;
      c.classList.remove("is-top");
      if (match && !first) first = c;
    });
    if (q && first) first.classList.add("is-top");

    list.forEach(function (c) {
      if (c.hidden) return;
      var o = before.get(c);
      if (o) {
        var dx = o.x - c.offsetLeft, dy = o.y - c.offsetTop;
        if (Math.abs(dx) > 0.5 || Math.abs(dy) > 0.5) {
          anim(c, [{ translate: dx + "px " + dy + "px" }, { translate: "0px 0px" }],
            { duration: 520, easing: EASE });
        }
      } else {
        anim(c, [{ opacity: 0, scale: "0.6" }, { opacity: 1, scale: "1" }],
          { duration: 420, easing: EASE });
      }
    });

    var shown = list.filter(function (c) { return !c.hidden; }).length;
    if (!status.dataset.locked) {
      status.textContent = shown === total ? total + " apps" : shown + " of " + total + " apps";
    }
    setEnter(first && q ? first : null);
    return first;
  }

  /* Keycap tape: one keycap per typed key. */
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

  /* The signature moment: the top hit is pressed and a light ribbon crosses the window. */
  function launch(top) {
    if (!top) return;
    anim(top.querySelector(".ico"),
      [{ scale: "1" }, { scale: "0.88", offset: 0.22 }, { scale: "1.05", offset: 0.66 }, { scale: "1" }],
      { duration: 560, easing: "linear" });
    anim(glintEl,
      [{ translate: "-120% 0" }, { translate: "260% 0" }],
      { duration: 900, easing: EASE });
  }

  async function loop(id) {
    while (running && id === runId) {
      input.value = "";
      tape.innerHTML = "";
      status.dataset.locked = "";
      filter("");
      await sleep(1100);

      for (var i = 1; i <= WORD.length && running && id === runId; i++) {
        input.value = WORD.slice(0, i);
        addKey(WORD.charAt(i - 1));
        filter(input.value.toLowerCase());
        await sleep(240);
      }
      if (!running || id !== runId) break;

      await sleep(650);
      var top = grid.querySelector(".cell.is-top");
      launch(top);
      status.dataset.locked = "1";
      status.textContent = "Opening Photos";
      await sleep(1000);

      for (var j = WORD.length; j >= 0 && running && id === runId; j--) {
        input.value = WORD.slice(0, j);
        popKey();
        filter(input.value.toLowerCase());
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
  function halt() {
    running = false;
  }
  function takeOver() {
    stopped = true;
    halt();
    status.dataset.locked = "";
  }

  /* Start once the window is on screen, pause when it leaves, never restart after a visitor types. */
  if ("IntersectionObserver" in window) {
    var timer = null;
    var io = new IntersectionObserver(function (entries) {
      var on = entries[0].isIntersecting;
      clearTimeout(timer);
      if (on) timer = setTimeout(start, 1400);
      else halt();
    }, { threshold: 0.4 });
    io.observe(win);
  }

  input.addEventListener("focus", takeOver);
  input.addEventListener("input", function () {
    takeOver();
    filter(input.value.trim().toLowerCase());
  });
  input.addEventListener("keydown", function (e) {
    if (e.key === "Enter") {
      var top = grid.querySelector(".cell.is-top");
      if (top) top.click();
    }
  });
})();
