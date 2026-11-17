(function () {
  "use strict";

  /* Design page: each spring track toggles between its two ends on click or Enter.
     The track is a button with aria-pressed, so the state is announced. Reduce Motion
     is handled in CSS: the dot jumps instead of moving. Nothing here needs the network. */
  var tracks = document.querySelectorAll(".ds-track");
  Array.prototype.forEach.call(tracks, function (btn) {
    btn.addEventListener("click", function () {
      var on = btn.getAttribute("aria-pressed") !== "true";
      btn.setAttribute("aria-pressed", String(on));
      btn.classList.toggle("is-on", on);
    });
  });
})();
