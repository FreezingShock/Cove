/* Ledger Tiles: eyebrow mark and scroll reveals. Tile fields, tickers and the page wipe live in kit.js.
   Every effect is skipped under Reduced Motion, and the page reads fully without this file. */
(() => {
  const root = document.documentElement;
  const mq = matchMedia('(prefers-reduced-motion: reduce)');
  const reduce = () => mq.matches;
  const rnd = (n) => (Math.random() * n) | 0;

  /* Eyebrows get the two-tile mark. */
  document.querySelectorAll('main .eyebrow').forEach((el) => {
    if (el.querySelector('.ld-tiles')) return;
    const t = document.createElement('span');
    t.className = 'ld-tiles';
    t.setAttribute('aria-hidden', 'true');
    t.innerHTML = '<i></i><i></i><i></i><i></i>';
    el.prepend(t);
  });

  /* Reveal on scroll. Only things below the first screen are hidden first, so the hero paints at once. */
  if (!reduce() && 'IntersectionObserver' in window) {
    const sel = '.band > *, .feature > *, .uses > *, .privacy > *, .get-box, .cards .card, .fact, .plan, .recipe, .aud-list li, .faq-group, .ld-inner > *';
    const io = new IntersectionObserver((es) => es.forEach((e) => {
      if (e.isIntersecting) { e.target.classList.add('on'); io.unobserve(e.target); }
    }), { threshold: 0.08, rootMargin: '0px 0px -4% 0px' });
    let n = 0;
    document.querySelectorAll(sel).forEach((el) => {
      if (el.closest('.nav, .scrub, .lit-band') || el.getBoundingClientRect().top < innerHeight) return;
      el.classList.add('ld-rv');
      el.style.setProperty('--d', (n++ % 4) * 70 + 'ms');
      io.observe(el);
    });
  }

})();
