/* Ledger Tiles motion: reveals, random tile fields, scroll-speed tickers, page wipe.
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

  /* Tile fields: random dim tiles, with lit tiles that hop. */
  const fields = [];
  const build = (host, cls, cols, rows, dimChance) => {
    const f = document.createElement('div');
    f.className = cls;
    f.setAttribute('aria-hidden', 'true');
    f.style.setProperty(cls === 'ld-field' ? '--fc' : '--wc', cols);
    const tiles = [];
    for (let i = 0; i < cols * rows; i++) {
      const t = document.createElement('i');
      if (Math.random() < dimChance) t.className = 'dim';
      f.appendChild(t); tiles.push(t);
    }
    host.prepend(f);
    fields.push({ tiles, lit: new Set(), max: Math.max(2, Math.round(cols * rows / 40)) });
    if (reduce()) tiles[(cols * 2 + 3) % tiles.length].classList.add('on');
  };
  const narrow = innerWidth < 760;
  const hero = document.querySelector('.hero');
  if (hero) build(hero, 'ld-field', narrow ? 8 : 16, narrow ? 14 : 12, 0.3);
  document.querySelectorAll('.ld-ink, .get-box').forEach((h) => {
    const r = h.getBoundingClientRect();
    const cols = narrow ? 8 : 16;
    build(h, 'ld-wall', cols, Math.max(4, Math.ceil((h.offsetHeight || 500) / (innerWidth / cols))), 0.25);
  });

  /* One timer for everything. Scroll speed shortens the beat. */
  let v = 0, lastY = scrollY, lastT = performance.now();
  addEventListener('scroll', () => {
    const now = performance.now(), dy = Math.abs(scrollY - lastY);
    v = Math.min(1, Math.max(v, dy / Math.max(16, now - lastT) / 4));
    lastY = scrollY; lastT = now;
  }, { passive: true });

  const bands = [...document.querySelectorAll('.lit-band-track')];
  const anims = bands.flatMap((b) => b.getAnimations ? b.getAnimations() : []);
  const tick = () => {
    v *= 0.94;
    const rate = 1 + v * 7;
    anims.forEach((a) => { a.playbackRate = rate; });
    requestAnimationFrame(tick);
  };
  if (!reduce()) requestAnimationFrame(tick);

  const beat = () => {
    if (!reduce() && !document.hidden) {
      fields.forEach((f) => {
        const t = f.tiles[rnd(f.tiles.length)];
        t.classList.add('on'); f.lit.add(t);
        if (f.lit.size > f.max) { const o = f.lit.values().next().value; o.classList.remove('on'); f.lit.delete(o); }
        if (v > 0.15) { const t2 = f.tiles[rnd(f.tiles.length)]; t2.classList.add('on'); f.lit.add(t2); }
      });
    }
    setTimeout(beat, Math.max(140, 900 - v * 700));
  };
  if (fields.length && !reduce()) beat();

  /* Page wipe: tiles fill from the clicked link, then the page changes. */
  const wipe = document.createElement('div');
  wipe.id = 'ld-wipe';
  wipe.setAttribute('aria-hidden', 'true');
  document.body.appendChild(wipe);
  const run = (ox, oy, done, out) => {
    const cs = Math.max(64, Math.round(innerWidth / 12));
    const c = Math.ceil(innerWidth / cs), r = Math.ceil(innerHeight / cs);
    wipe.style.gridTemplateColumns = `repeat(${c},1fr)`;
    wipe.style.gridTemplateRows = `repeat(${r},1fr)`;
    wipe.innerHTML = '';
    const cells = [];
    for (let y = 0; y < r; y++) for (let x = 0; x < c; x++) {
      const i = document.createElement('i');
      i._d = Math.hypot(x * cs + cs / 2 - ox, y * cs + cs / 2 - oy);
      if ((x * 3 + y) % 7 === 0) i.className = 'l';
      wipe.appendChild(i); cells.push(i);
    }
    const max = Math.max(...cells.map((i) => i._d)) || 1;
    cells.forEach((i) => { i.style.transitionDelay = ((out ? max - i._d : i._d) / max) * 260 + 'ms'; });
    wipe.style.display = 'grid';
    if (out) cells.forEach((i) => i.classList.add('on'));
    requestAnimationFrame(() => requestAnimationFrame(() => cells.forEach((i) => i.classList.toggle('on', !out))));
    setTimeout(done, out ? 700 : 520);
  };
  if (!reduce() && sessionStorage.getItem('ld-wipe') === '1') {
    sessionStorage.removeItem('ld-wipe');
    run(innerWidth / 2, innerHeight / 2, () => { wipe.style.display = 'none'; }, true);
  }
  document.addEventListener('click', (e) => {
    const a = e.target.closest && e.target.closest('a[href]');
    if (!a || reduce() || e.defaultPrevented || e.button || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    if (a.target || a.hasAttribute('download') || a.origin !== location.origin) return;
    const same = a.pathname === location.pathname;
    if (same) return;
    e.preventDefault();
    try { sessionStorage.setItem('ld-wipe', '1'); } catch (_) {}
    run(e.clientX || innerWidth / 2, e.clientY || innerHeight / 2, () => { location.href = a.href; }, false);
  });
  addEventListener('pageshow', (e) => { if (e.persisted) wipe.style.display = 'none'; });
})();
