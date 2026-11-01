// unfocused landing page: reveals, the pinned panel story, the Capture demo and copy buttons.

// Reveal once when an element comes into view, or has been scrolled past. Content is never left hidden.
(() => {
  const pending = new Set(document.querySelectorAll('[data-reveal], .step, .sheet, .slip'));
  document.querySelectorAll('.slip li').forEach((li, n) => li.style.setProperty('--n', n));
  let queued = false;
  const check = () => {
    queued = false;
    const line = innerHeight * 0.9;
    for (const el of pending) {
      if (el.getBoundingClientRect().top < line) { el.classList.add('is-in'); pending.delete(el); }
    }
    if (!pending.size) removeEventListener('scroll', onScroll);
  };
  const onScroll = () => { if (!queued) { queued = true; requestAnimationFrame(check); } };
  addEventListener('scroll', onScroll, { passive: true });
  addEventListener('resize', onScroll);
  check();
})();

// The plate holds while the three panel states scroll past; the tabs jump between them.
(() => {
  const img = document.getElementById('plate-img');
  const tabs = [...document.querySelectorAll('.tabs [data-step]')];
  const steps = [...document.querySelectorAll('.step[data-step]')];
  if (!img || !steps.length) return;
  let current = 0;
  const select = (index) => {
    if (index === current) return;
    current = index;
    tabs.forEach((tab, i) => tab.setAttribute('aria-selected', String(i === index)));
    const step = steps[index];
    img.classList.add('is-swapping');
    setTimeout(() => {
      img.src = step.dataset.src;
      img.alt = step.dataset.alt;
      img.classList.remove('is-swapping');
    }, 180);
  };
  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver((entries) => {
      for (const entry of entries) if (entry.isIntersecting) select(Number(entry.target.dataset.step));
    }, { rootMargin: '-45% 0px -45% 0px' });
    steps.forEach((step) => io.observe(step));
  }
  tabs.forEach((tab, i) => {
    tab.addEventListener('click', () => {
      select(i);
      const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
      steps[i].scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'center' });
    });
    tab.addEventListener('keydown', (event) => {
      const delta = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0;
      if (!delta) return;
      const next = tabs[(i + delta + tabs.length) % tabs.length];
      next.focus();
      next.click();
    });
  });
})();

// Capture, as in the panel: ⌘↩ captures something new, plain ↩ doesn't.
(() => {
  const form = document.getElementById('capture-form');
  const input = document.getElementById('capture-input');
  const list = document.getElementById('mini-list');
  const note = document.getElementById('mini-note');
  const hint = document.getElementById('capture-hint');
  if (!form || !input || !list) return;
  const looseEnds = list.querySelectorAll('.mini__row--loose').length;
  let open = list.children.length;
  const defaultHint = hint.textContent;

  const capture = () => {
    const title = input.value.trim().replace(/\s+/g, ' ');
    if (!title) { input.focus(); return; }
    list.querySelector('.is-new')?.classList.remove('is-new');
    const row = document.createElement('li');
    row.className = 'mini__row is-new';
    const ring = document.createElement('span');
    ring.className = 'ring ring--new';
    ring.setAttribute('aria-hidden', 'true');
    const name = document.createElement('span');
    name.className = 'mini__title';
    name.textContent = title.charAt(0).toUpperCase() + title.slice(1);
    const age = document.createElement('span');
    age.className = 'mini__age';
    age.textContent = 'now';
    row.append(ring, name, age);
    list.prepend(row);
    while (list.children.length > 6) list.lastElementChild.remove();
    open += 1;
    note.textContent = `Captured. That's ${open} Open Loops, and ${looseEnds === 1 ? '1 Loose End is' : `${looseEnds} Loose Ends are`} older than this idea.`;
    hint.textContent = defaultHint;
    hint.classList.remove('is-nudge');
    input.value = '';
  };

  input.addEventListener('keydown', (event) => {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    if (event.metaKey || event.ctrlKey) { capture(); return; }
    hint.textContent = 'Plain ↩ Focuses a Loop you already have. Something new takes ⌘↩, one key more.';
    hint.classList.add('is-nudge');
  });
  form.addEventListener('submit', (event) => { event.preventDefault(); capture(); });
})();

// Copy the install commands.
(() => {
  document.querySelectorAll('[data-copy]').forEach((button) => {
    button.addEventListener('click', async () => {
      const text = document.getElementById(button.dataset.copy)?.textContent ?? '';
      try {
        await navigator.clipboard.writeText(text);
        button.textContent = 'Copied';
      } catch {
        button.textContent = 'Select and copy';
      }
      setTimeout(() => { button.textContent = 'Copy'; }, 2000);
    });
  });
})();
