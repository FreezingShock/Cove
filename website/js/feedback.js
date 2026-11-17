/* Micro-feedback: a copy button on each command block, a shared toast that confirms a copy,
   a download, or a hand-off to the mail app, and nothing else. Plain script, no dependencies,
   no network requests, no sound. The toast is never a modal and never takes focus unless
   the reader tabs into its action link. Under Reduce Motion it appears without sliding. */
(function () {
  "use strict";

  var SHORT_MS = 2600;   // a plain confirmation
  var ACTION_MS = 6500;  // a confirmation with a link to follow
  var RESUME_MS = 1800;  // after the pointer or focus leaves the toast
  var DONE_MS = 1600;    // how long a copy button says "Copied"

  var toast, msg, act, timer = null;

  /* ---------- Clipboard: resolves to true only when the text was written ---------- */
  function copyText(text) {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        return navigator.clipboard.writeText(text).then(
          function () { return true; },
          function () { return false; }
        );
      }
    } catch (err) { /* blocked: fall through */ }
    return Promise.resolve(false);
  }

  /* ---------- Toast: one live region, created once so screen readers hear every update ---------- */
  function hide() {
    clearTimeout(timer);
    timer = null;
    toast.classList.remove("is-on");
  }
  function schedule(ms) {
    clearTimeout(timer);
    timer = setTimeout(hide, ms);
  }
  function show(text, opts) {
    msg.textContent = text;
    if (opts && opts.href) {
      act.href = opts.href;
      act.textContent = opts.label;
      act.hidden = false;
    } else {
      act.hidden = true;
      act.textContent = "";
    }
    toast.classList.add("is-on");
    schedule(opts && opts.href ? ACTION_MS : SHORT_MS);
  }

  function buildToast() {
    toast = document.createElement("div");
    toast.className = "glass capsule site-toast";
    toast.setAttribute("role", "status");
    toast.setAttribute("aria-live", "polite");
    msg = document.createElement("span");
    msg.className = "site-toast-msg";
    act = document.createElement("a");
    act.className = "site-toast-act";
    act.href = "download.html#install"; // always a real link, so it stays crawlable and works without script
    act.hidden = true;
    toast.appendChild(msg);
    toast.appendChild(act);
    document.body.appendChild(toast);

    // Keep the message on screen while the reader is looking at it or using the link.
    toast.addEventListener("pointerenter", function () { clearTimeout(timer); });
    toast.addEventListener("pointerleave", function () { if (toast.classList.contains("is-on")) schedule(RESUME_MS); });
    toast.addEventListener("focusin", function () { clearTimeout(timer); });
    toast.addEventListener("focusout", function () { if (toast.classList.contains("is-on")) schedule(RESUME_MS); });
  }

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && toast && toast.classList.contains("is-on")) hide();
  });

  /* ---------- Command blocks: wrap each one and add a Copy button beside it ---------- */
  function enhanceCommands() {
    var blocks = document.querySelectorAll("pre.cmd");
    Array.prototype.forEach.call(blocks, function (pre) {
      if (!pre.parentNode || pre.parentNode.classList.contains("cmd-wrap")) return;
      var wrap = document.createElement("div");
      wrap.className = "cmd-wrap";
      pre.parentNode.insertBefore(wrap, pre);
      wrap.appendChild(pre);

      var btn = document.createElement("button");
      btn.type = "button";
      btn.className = "cmd-copy";
      btn.textContent = "Copy";
      btn.setAttribute("aria-label", "Copy command");
      wrap.appendChild(btn);

      var timerBtn = null;
      btn.addEventListener("click", function () {
        var text = pre.textContent.trim();
        copyText(text).then(function (ok) {
          if (!ok) {
            show("Copy isn't available here. Select the command and copy it.");
            return;
          }
          show("Copied. Paste it into Terminal or Finder.");
          btn.textContent = "Copied";
          btn.setAttribute("aria-label", "Copied command");
          btn.classList.add("is-done");
          clearTimeout(timerBtn);
          timerBtn = setTimeout(function () {
            btn.textContent = "Copy";
            btn.setAttribute("aria-label", "Copy command");
            btn.classList.remove("is-done");
          }, DONE_MS);
        });
      });
    });
  }

  /* ---------- Hand-offs: the disk image download and the mail link ---------- */
  function watchHandoffs() {
    document.addEventListener("click", function (e) {
      if (!e.target.closest) return;
      var dmg = e.target.closest('a[href$="Inlet.dmg"]');
      // Buttons that are hidden on phones have no layout box, so they never start a download here.
      if (dmg && dmg.offsetParent !== null) {
        show("Download started. Drag Inlet into Applications when it finishes.", {
          href: "download.html#install",
          label: "Install steps"
        });
        return;
      }
      var mail = e.target.closest('a[href^="mailto:"]');
      if (mail && mail.offsetParent !== null) {
        show("Opening your mail app. If nothing opens, use Copy link.");
      }
    });
  }

  function init() {
    buildToast();
    enhanceCommands();
    watchHandoffs();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
