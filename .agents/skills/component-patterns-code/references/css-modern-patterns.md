# Modern CSS Patterns — The 2025-2026 Revolution

CSS has undergone the most significant evolution in its history between 2023 and 2026. Features that once required JavaScript libraries, CSS preprocessors, or convoluted workarounds are now native to the platform. This reference covers twelve foundational modern CSS patterns, each with problem statements, production-ready code, browser support notes, and fallback strategies.

---

## 1. Container Queries

### Problem

Media queries respond to the viewport, not the component's container. A card component placed in a narrow sidebar receives the same breakpoint treatment as one in a wide main content area. This forces developers to create variant classes or rely on JavaScript resize observers to build truly responsive components.

### Solution

Container queries scope responsive behavior to the nearest containment context rather than the viewport. A component adapts based on its parent container's dimensions.

**Defining a container:**

```css
/* Named container */
.card-wrapper {
  container-name: card;
  container-type: inline-size;
}

/* Shorthand */
.sidebar {
  container: sidebar / inline-size;
}
```

**Querying the container:**

```css
/* Card adapts from vertical to horizontal layout */
.card {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
}

@container card (min-inline-size: 400px) {
  .card {
    grid-template-columns: 200px 1fr;
    align-items: start;
  }

  .card__image {
    aspect-ratio: 1;
    object-fit: cover;
  }
}

@container card (min-inline-size: 600px) {
  .card {
    grid-template-columns: 280px 1fr;
  }

  .card__title {
    font-size: 1.5rem;
  }
}
```

**Container query units:**

```css
/* Units relative to the query container */
.card__title {
  /* cqi = 1% of container's inline size */
  font-size: clamp(1rem, 3cqi, 2rem);
}

.card__body {
  /* cqw = 1% of container width */
  padding: 2cqw;
}

.card__image {
  /* cqh = 1% of container height (requires block-size containment) */
  max-height: 50cqh;
}
```

**Sidebar collapse pattern:**

```css
.sidebar {
  container: sidebar / inline-size;
}

.sidebar-nav__label {
  display: inline;
}

.sidebar-nav__icon {
  width: 1.5rem;
  height: 1.5rem;
}

@container sidebar (max-inline-size: 80px) {
  .sidebar-nav__label {
    display: none;
  }

  .sidebar-nav__icon {
    width: 2rem;
    height: 2rem;
    margin-inline: auto;
  }

  .sidebar-nav__item {
    justify-content: center;
  }
}
```

**Comparison with media queries:**

```css
/* OLD: Media query -- responds to viewport */
@media (min-width: 768px) {
  .card { grid-template-columns: 200px 1fr; }
}

/* NEW: Container query -- responds to parent */
@container (min-inline-size: 400px) {
  .card { grid-template-columns: 200px 1fr; }
}
```

The critical difference: the same card component works in a 300px sidebar and a 900px main area without any variant classes. The component is self-aware of its available space.

### Browser Support

Chrome 105+, Firefox 110+, Safari 16+, Edge 105+. Container query units supported in Chrome 105+, Firefox 110+, Safari 16+.

### Fallback Strategy

Use `@supports (container-type: inline-size)` to detect support. Fall back to media queries for older browsers. The component will be viewport-responsive rather than container-responsive, which is acceptable degradation.

```css
/* Fallback */
@media (min-width: 600px) {
  .card { grid-template-columns: 200px 1fr; }
}

/* Enhancement */
@supports (container-type: inline-size) {
  .card-wrapper { container-type: inline-size; }

  @container (min-inline-size: 400px) {
    .card { grid-template-columns: 200px 1fr; }
  }
}
```

---

## 2. :has() — The Parent Selector

### Problem

CSS selectors only traverse downward or sideways. There was no way to select a parent element based on the state or presence of its children. Styling a form field wrapper when its input is invalid, or changing a layout when a checkbox is checked, required JavaScript class toggling.

### Solution

The `:has()` relational pseudo-class selects an element based on what it contains or what follows it.

**Example 1: Form validation styling**

```css
/* Style the field wrapper when its input is invalid */
.field:has(:invalid) {
  border-left: 3px solid oklch(0.65 0.25 25);
}

.field:has(:invalid) .field__label {
  color: oklch(0.65 0.25 25);
}

.field:has(:focus) {
  border-left: 3px solid oklch(0.65 0.2 250);
}

/* Show error message only when sibling input is invalid */
.field:has(:invalid) .field__error {
  display: block;
}
```

**Example 2: Checkbox-controlled layout**

```css
/* Toggle sidebar visibility with a checkbox, no JS */
body:has(#sidebar-toggle:checked) .sidebar {
  transform: translateX(0);
}

body:has(#sidebar-toggle:not(:checked)) .sidebar {
  transform: translateX(-100%);
}

/* Dark mode toggle via checkbox */
body:has(#dark-mode:checked) {
  color-scheme: dark;
  --surface: oklch(0.2 0.02 260);
  --text: oklch(0.9 0.01 260);
}
```

**Example 3: Empty state detection**

```css
/* Style a list container when it has no children */
.task-list:has(:not(*)) {
  display: grid;
  place-items: center;
  min-height: 200px;
}

/* More reliable: check for absence of specific children */
.task-list:not(:has(.task-item)) {
  background: oklch(0.95 0.01 260);
}

.task-list:not(:has(.task-item))::after {
  content: "No tasks yet. Add one to get started.";
  color: oklch(0.55 0.02 260);
  font-style: italic;
}
```

**Example 4: Sibling-aware styling**

```css
/* A figure that contains a figcaption gets different padding */
figure:has(figcaption) {
  padding-bottom: 0.5rem;
}

figure:not(:has(figcaption)) {
  padding-bottom: 1.5rem;
}

/* Style an article differently if it has a hero image */
article:has(> .hero-image) {
  padding-top: 0;
}

article:not(:has(> .hero-image)) {
  padding-top: 2rem;
}
```

**Example 5: Quantity-aware grid**

```css
/* Adjust grid layout based on number of children */
.grid:has(> :nth-child(4)) {
  grid-template-columns: repeat(2, 1fr);
}

.grid:has(> :nth-child(7)) {
  grid-template-columns: repeat(3, 1fr);
}

.grid:has(> :only-child) {
  grid-template-columns: 1fr;
  max-width: 40ch;
}
```

**Example 6: Interactive table rows**

```css
/* Highlight a table row when any cell within it is hovered */
tr:has(td:hover) {
  background-color: oklch(0.95 0.01 250);
}

/* Style the entire form when any input inside is focused */
form:has(:focus-visible) {
  box-shadow: 0 0 0 2px oklch(0.65 0.2 250 / 0.3);
}
```

### Browser Support

Chrome 105+, Firefox 121+, Safari 15.4+, Edge 105+.

### Fallback Strategy

`:has()` has no pure CSS fallback. For critical functionality, use JavaScript as a progressive enhancement layer:

```js
// Fallback for browsers without :has()
if (!CSS.supports('selector(:has(*))')) {
  document.querySelectorAll('.field input:invalid').forEach(input => {
    input.closest('.field').classList.add('field--invalid');
  });
}
```

---

## 3. CSS Anchor Positioning

### Problem

Positioning tooltips, popovers, and dropdown menus relative to a trigger element requires JavaScript libraries like Floating UI (Popper.js). These libraries must calculate positions, handle overflow, manage scroll offsets, and recalculate on resize. This adds bundle weight and complexity.

### Solution

CSS Anchor Positioning allows elements to be positioned relative to a named anchor element, entirely in CSS.

**Complete tooltip example:**

```css
/* Define the anchor */
.tooltip-trigger {
  anchor-name: --tooltip-anchor;
}

/* Position the tooltip */
.tooltip {
  position: fixed;
  position-anchor: --tooltip-anchor;

  /* Place above the anchor, centered horizontally */
  inset-area: top;
  justify-self: center;

  /* Fine-tune with anchor() function */
  margin-bottom: 8px;

  /* Auto-flip if not enough space */
  position-try-fallbacks: flip-block;

  /* Styling */
  background: oklch(0.2 0.02 260);
  color: oklch(0.95 0.01 260);
  padding: 0.5rem 0.75rem;
  border-radius: 6px;
  font-size: 0.875rem;
  white-space: nowrap;
  pointer-events: none;
}

/* Show on hover/focus */
.tooltip-trigger:hover + .tooltip,
.tooltip-trigger:focus-visible + .tooltip {
  display: block;
}
```

**Complete popover dropdown example:**

```css
.dropdown-trigger {
  anchor-name: --dropdown;
}

.dropdown-menu {
  position: fixed;
  position-anchor: --dropdown;

  /* Position below and aligned to start edge */
  inset-area: bottom span-right;
  margin-top: 4px;

  /* Try alternative positions if no space */
  position-try-fallbacks:
    --above,
    --left;

  /* Sizing */
  min-width: anchor-size(width);
  max-height: 300px;
  overflow-y: auto;

  /* Styling */
  background: oklch(1 0 0);
  border: 1px solid oklch(0.85 0.01 260);
  border-radius: 8px;
  box-shadow: 0 8px 24px oklch(0 0 0 / 0.12);
  padding: 0.25rem;
}

@position-try --above {
  inset-area: top span-right;
  margin-bottom: 4px;
}

@position-try --left {
  inset-area: left;
  margin-right: 4px;
}
```

**Dynamic anchor with `anchor-scope`:**

```css
/* Each list item anchors its own tooltip */
.list-item {
  anchor-name: --item;
  anchor-scope: --item;
}

.list-item .item-tooltip {
  position: fixed;
  position-anchor: --item;
  inset-area: right;
  margin-left: 8px;
}
```

### Browser Support

Chrome 125+, Edge 125+. Firefox and Safari are actively implementing as of early 2026. Check caniuse.com for the latest status.

### Fallback Strategy

Anchor positioning is the newest feature on this list. Use progressive enhancement with a JavaScript positioning library as fallback.

```css
/* Fallback: static positioning or basic absolute */
.tooltip {
  position: absolute;
  bottom: 100%;
  left: 50%;
  transform: translateX(-50%);
}

/* Enhancement: anchor positioning */
@supports (anchor-name: --a) {
  .tooltip {
    position: fixed;
    position-anchor: --tooltip-anchor;
    inset-area: top;
    justify-self: center;
    transform: none;
    bottom: auto;
    left: auto;
  }
}
```

---

## 4. @starting-style — Entry Animations

### Problem

CSS transitions cannot animate elements entering the DOM or transitioning from `display: none` to `display: block`. Dialogs, popovers, and toast notifications that appear dynamically cannot have entry animations without JavaScript-managed class toggling or animation libraries.

### Solution

`@starting-style` defines the initial state for CSS transitions when an element first renders or moves from `display: none` to a displayed state. Combined with `transition-behavior: allow-discrete`, it enables transitions on discrete properties like `display` and `overlay`.

**Dialog open/close animation:**

```css
dialog {
  opacity: 1;
  transform: translateY(0) scale(1);
  transition:
    opacity 0.3s ease,
    transform 0.3s ease,
    overlay 0.3s ease allow-discrete,
    display 0.3s ease allow-discrete;
}

/* State when dialog first appears */
@starting-style {
  dialog[open] {
    opacity: 0;
    transform: translateY(-20px) scale(0.95);
  }
}

/* State when dialog closes */
dialog:not([open]) {
  opacity: 0;
  transform: translateY(10px) scale(0.98);
}

/* Backdrop animation */
dialog::backdrop {
  background: oklch(0 0 0 / 0.5);
  opacity: 1;
  transition:
    opacity 0.3s ease,
    overlay 0.3s ease allow-discrete,
    display 0.3s ease allow-discrete;
}

@starting-style {
  dialog[open]::backdrop {
    opacity: 0;
  }
}
```

**Popover entry animation:**

```css
[popover] {
  opacity: 1;
  transform: translateY(0);
  transition:
    opacity 0.2s ease,
    transform 0.2s ease,
    overlay 0.2s ease allow-discrete,
    display 0.2s ease allow-discrete;
}

@starting-style {
  [popover]:popover-open {
    opacity: 0;
    transform: translateY(8px);
  }
}

/* Exit */
[popover]:not(:popover-open) {
  opacity: 0;
  transform: translateY(-4px);
}
```

**Toast notification slide-in:**

```css
.toast {
  position: fixed;
  bottom: 1rem;
  right: 1rem;
  translate: 0 0;
  opacity: 1;
  transition:
    translate 0.4s cubic-bezier(0.16, 1, 0.3, 1),
    opacity 0.4s ease,
    display 0.4s ease allow-discrete;
}

@starting-style {
  .toast {
    translate: 100% 0;
    opacity: 0;
  }
}

.toast.dismissed {
  translate: 100% 0;
  opacity: 0;
  display: none;
}
```

### Browser Support

Chrome 117+, Edge 117+, Firefox 129+, Safari 17.5+.

### Fallback Strategy

Without `@starting-style`, elements appear instantly without animation. This is acceptable graceful degradation. For browsers that need entry animations, use CSS `@keyframes` as an alternative:

```css
@supports not (transition-behavior: allow-discrete) {
  dialog[open] {
    animation: dialog-in 0.3s ease forwards;
  }

  @keyframes dialog-in {
    from {
      opacity: 0;
      transform: translateY(-20px) scale(0.95);
    }
  }
}
```

---

## 5. View Transitions API

### Problem

Page transitions and element morphing between states require complex JavaScript animation orchestration. Transitioning between routes in a SPA, or animating a thumbnail expanding into a full-size image, demands manual snapshot management and FLIP animation techniques.

### Solution

The View Transitions API provides browser-managed transitions between DOM states. The browser captures snapshots of the old and new states, then animates between them.

**Same-document transition (SPA route change):**

```js
// Wrap the DOM update in startViewTransition
document.startViewTransition(() => {
  updateDOM(); // Your function that swaps content
});
```

```css
/* Default crossfade for the entire page */
::view-transition-old(root) {
  animation: fade-out 0.25s ease forwards;
}

::view-transition-new(root) {
  animation: fade-in 0.25s ease forwards;
}

@keyframes fade-out {
  to { opacity: 0; }
}

@keyframes fade-in {
  from { opacity: 0; }
}
```

**Element-level transitions with `view-transition-name`:**

```css
/* Give specific elements their own transition */
.hero-image {
  view-transition-name: hero;
}

.page-title {
  view-transition-name: title;
}

/* Animate the hero image morph */
::view-transition-old(hero),
::view-transition-new(hero) {
  animation-duration: 0.4s;
  animation-timing-function: cubic-bezier(0.16, 1, 0.3, 1);
}

/* Slide title in from left */
::view-transition-new(title) {
  animation: slide-in-left 0.3s ease;
}

::view-transition-old(title) {
  animation: slide-out-right 0.3s ease;
}

@keyframes slide-in-left {
  from { transform: translateX(-30px); opacity: 0; }
}

@keyframes slide-out-right {
  to { transform: translateX(30px); opacity: 0; }
}
```

**Cross-document transitions (MPA):**

```css
/* In both pages' CSS: */
@view-transition {
  navigation: auto;
}

/* Match elements between pages by view-transition-name */
.product-image {
  view-transition-name: product-hero;
}
```

**SPA route change with directional animation:**

```js
function navigateTo(url, direction) {
  const transition = document.startViewTransition(() => {
    loadRoute(url);
  });

  document.documentElement.dataset.direction = direction;
}
```

```css
[data-direction="forward"] ::view-transition-new(root) {
  animation: slide-from-right 0.3s ease;
}

[data-direction="forward"] ::view-transition-old(root) {
  animation: slide-to-left 0.3s ease;
}

[data-direction="back"] ::view-transition-new(root) {
  animation: slide-from-left 0.3s ease;
}

[data-direction="back"] ::view-transition-old(root) {
  animation: slide-to-right 0.3s ease;
}
```

### Browser Support

Chrome 111+, Edge 111+, Safari 18+. Firefox support for same-document transitions landed in Firefox 131+. Cross-document transitions in Chrome 126+.

### Fallback Strategy

The API is progressively enhancing by nature. Without support, DOM updates happen instantly. Always check before calling:

```js
if (!document.startViewTransition) {
  updateDOM();
  return;
}
document.startViewTransition(() => updateDOM());
```

---

## 6. Scroll-Driven Animations

### Problem

Scroll-linked animations (progress bars, parallax effects, reveal-on-scroll) require JavaScript scroll event listeners or IntersectionObserver. These are performance-sensitive; jank is common unless the listener runs off the main thread.

### Solution

Scroll-driven animations tie CSS animations to scroll progress or an element's position in the viewport, running entirely on the compositor thread for guaranteed smoothness.

**Scroll progress indicator:**

```css
.progress-bar {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 3px;
  background: oklch(0.6 0.2 250);
  transform-origin: left;
  animation: grow-width linear;
  animation-timeline: scroll();
}

@keyframes grow-width {
  from { transform: scaleX(0); }
  to { transform: scaleX(1); }
}
```

**Reveal-on-scroll with `view()`:**

```css
.reveal-card {
  animation: reveal linear both;
  animation-timeline: view();
  animation-range: entry 0% entry 100%;
}

@keyframes reveal {
  from {
    opacity: 0;
    transform: translateY(40px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
```

**Parallax effect:**

```css
.parallax-bg {
  animation: parallax linear;
  animation-timeline: scroll();
}

@keyframes parallax {
  from { transform: translateY(0); }
  to { transform: translateY(-30%); }
}
```

**Element-scoped scroll timeline (horizontal carousel indicator):**

```css
.carousel {
  overflow-x: scroll;
  scroll-snap-type: x mandatory;
  scroll-timeline: --carousel inline;
}

.carousel-indicator {
  animation: track-scroll linear;
  animation-timeline: --carousel;
}

@keyframes track-scroll {
  from { transform: translateX(0); }
  to { transform: translateX(calc(100% - var(--indicator-width))); }
}
```

**Image reveal on scroll into view:**

```css
.image-reveal {
  clip-path: inset(100% 0 0 0);
  animation: unclip linear both;
  animation-timeline: view();
  animation-range: entry 10% cover 40%;
}

@keyframes unclip {
  to { clip-path: inset(0 0 0 0); }
}
```

### Browser Support

Chrome 115+, Edge 115+, Firefox 130+, Safari 18+.

### Fallback Strategy

Use `@supports (animation-timeline: scroll())` to detect support. Fall back to IntersectionObserver for reveal-on-scroll, and omit decorative parallax effects. The scroll progress bar can fall back to a JavaScript implementation.

```css
@supports not (animation-timeline: scroll()) {
  .reveal-card {
    opacity: 1;
    transform: none;
  }
}
```

---

## 7. Subgrid

### Problem

Nested grid children cannot align to the parent grid's tracks. A common frustration: a card grid where each card has a title, body, and footer, but the titles and footers do not align across cards because each card defines its own independent row sizing.

### Solution

`subgrid` allows a grid child to adopt its parent's tracks for its own rows or columns, creating alignment through nested structures.

**Card grid with aligned content:**

```css
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1.5rem;
}

.card {
  display: grid;
  /* Inherit parent's column tracks if spanning multiple columns,
     but define 3 rows that align across all cards */
  grid-row: span 3;
  grid-template-rows: subgrid;
  gap: 0;
  border: 1px solid oklch(0.88 0.01 260);
  border-radius: 12px;
  overflow: hidden;
}

.card__header {
  /* Aligns with every other card's header row */
  padding: 1rem;
}

.card__body {
  /* Aligns with every other card's body row */
  padding: 0 1rem;
}

.card__footer {
  /* Aligns with every other card's footer row */
  padding: 1rem;
  align-self: end;
}
```

**Form label alignment:**

```css
.form {
  display: grid;
  grid-template-columns: [label] max-content [input] 1fr;
  gap: 1rem 1.5rem;
}

.form-field {
  display: grid;
  grid-column: 1 / -1;
  grid-template-columns: subgrid;
  align-items: baseline;
}

.form-field label {
  grid-column: label;
  text-align: right;
}

.form-field input {
  grid-column: input;
}
```

**Navigation with subgrid alignment:**

```css
.nav {
  display: grid;
  grid-template-columns: repeat(5, auto);
}

.nav-item {
  display: grid;
  grid-template-rows: subgrid;
  grid-row: span 2; /* icon row + label row */
  justify-items: center;
  gap: 0.25rem;
}
```

### Browser Support

Chrome 117+, Firefox 71+, Safari 16+, Edge 117+. Firefox was first to implement subgrid in 2019.

### Fallback Strategy

Without subgrid, each nested grid sizes its rows independently. Visual alignment is lost but layout remains functional. For critical alignment, fall back to fixed row heights:

```css
@supports not (grid-template-rows: subgrid) {
  .card__header { min-height: 3rem; }
  .card__footer { min-height: 2.5rem; }
}
```

---

## 8. Modern Color

### Problem

`rgb()` and `hsl()` produce perceptually non-uniform colors. Two colors with the same lightness value in HSL can look dramatically different in perceived brightness. Creating consistent color palettes, computing tints and shades, and managing themes requires manual tuning or design tools.

### Solution

Modern CSS color functions provide perceptually uniform color spaces, computed color variants, and automatic theme color resolution.

**`oklch()` for perceptually uniform color:**

```css
:root {
  /* oklch(lightness chroma hue) */
  --primary: oklch(0.6 0.2 250);      /* Blue */
  --secondary: oklch(0.6 0.2 330);    /* Pink — same perceived lightness */
  --success: oklch(0.6 0.2 145);      /* Green — same perceived lightness */
  --warning: oklch(0.75 0.18 85);     /* Amber */
  --danger: oklch(0.6 0.22 25);       /* Red */
}
```

**`color-mix()` for computed color variants:**

```css
:root {
  --primary: oklch(0.6 0.2 250);

  /* Tint: mix with white */
  --primary-100: color-mix(in oklch, var(--primary) 10%, white);
  --primary-200: color-mix(in oklch, var(--primary) 25%, white);
  --primary-300: color-mix(in oklch, var(--primary) 50%, white);

  /* Shade: mix with black */
  --primary-700: color-mix(in oklch, var(--primary) 70%, black);
  --primary-800: color-mix(in oklch, var(--primary) 50%, black);
  --primary-900: color-mix(in oklch, var(--primary) 30%, black);

  /* Transparent variant */
  --primary-alpha: color-mix(in oklch, var(--primary) 15%, transparent);
}
```

**`light-dark()` for automatic theme colors:**

```css
:root {
  color-scheme: light dark;

  --surface: light-dark(oklch(0.99 0.005 260), oklch(0.15 0.02 260));
  --text: light-dark(oklch(0.15 0.02 260), oklch(0.93 0.01 260));
  --border: light-dark(oklch(0.88 0.01 260), oklch(0.3 0.02 260));
  --primary: light-dark(oklch(0.55 0.22 250), oklch(0.72 0.18 250));
}

/* Explicit override */
@media (prefers-color-scheme: dark) {
  :root {
    color-scheme: dark;
  }
}
```

**Relative color syntax for dynamic adjustments:**

```css
:root {
  --brand: oklch(0.6 0.2 250);
}

.button-hover {
  /* Increase lightness by 10%, keep chroma and hue */
  background: oklch(from var(--brand) calc(l + 0.1) c h);
}

.button-active {
  /* Decrease lightness */
  background: oklch(from var(--brand) calc(l - 0.1) c h);
}

.button-ghost {
  /* Same hue and chroma, but 15% opacity */
  background: oklch(from var(--brand) l c h / 0.15);
  color: var(--brand);
}

.muted-text {
  /* Desaturate: reduce chroma */
  color: oklch(from var(--brand) l calc(c * 0.3) h);
}
```

### Browser Support

`oklch()`: Chrome 111+, Firefox 113+, Safari 15.4+, Edge 111+. `color-mix()`: Chrome 111+, Firefox 113+, Safari 16.2+. `light-dark()`: Chrome 123+, Firefox 120+, Safari 17.5+. Relative color syntax: Chrome 119+, Safari 16.4+, Firefox 128+.

### Fallback Strategy

Always provide a fallback color in a widely supported format before the modern one:

```css
.element {
  background: #3b82f6;                    /* Fallback */
  background: oklch(0.6 0.2 250);         /* Modern */
}
```

---

## 9. CSS Layers

### Problem

Specificity conflicts are the bane of CSS maintenance. Utility classes fight component styles. Third-party CSS overrides design system tokens. Developers resort to `!important` or artificially inflated specificity to win cascade battles.

### Solution

`@layer` creates explicit cascade layers. Styles in later-declared layers win over earlier layers, regardless of specificity within those layers.

**Design system layer architecture:**

```css
/* Declare layer order first — this is the cascade priority */
@layer reset, base, tokens, components, utilities, overrides;

/* Reset layer: lowest priority */
@layer reset {
  *,
  *::before,
  *::after {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }

  body {
    line-height: 1.5;
    -webkit-font-smoothing: antialiased;
  }
}

/* Base layer: foundational element styles */
@layer base {
  body {
    font-family: var(--font-sans);
    color: var(--text);
    background: var(--surface);
  }

  a {
    color: var(--primary);
    text-decoration-thickness: 1px;
    text-underline-offset: 2px;
  }

  img {
    display: block;
    max-width: 100%;
  }
}

/* Token layer: design tokens as custom properties */
@layer tokens {
  :root {
    --primary: oklch(0.6 0.2 250);
    --surface: oklch(0.99 0.005 260);
    --text: oklch(0.15 0.02 260);
    --font-sans: system-ui, sans-serif;
    --radius-md: 8px;
    --space-4: 1rem;
  }
}

/* Component layer */
@layer components {
  .button {
    padding: var(--space-2) var(--space-4);
    border-radius: var(--radius-md);
    font-weight: 600;
  }

  .card {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-4);
  }
}

/* Utility layer: high priority */
@layer utilities {
  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    clip: rect(0 0 0 0);
    overflow: hidden;
  }

  .hidden { display: none; }
  .flex { display: flex; }
  .grid { display: grid; }
  .gap-4 { gap: 1rem; }
}

/* Override layer: highest priority, for one-off fixes */
@layer overrides {
  /* Third-party widget fix */
  .third-party-widget .button {
    font-family: var(--font-sans);
  }
}
```

**Importing third-party CSS into a layer:**

```css
/* Place third-party CSS in a low-priority layer */
@import url("vendor/datepicker.css") layer(vendor);

/* Your layers will always win over vendor */
@layer vendor, tokens, components, utilities;
```

Key insight: a selector with id-level specificity inside `@layer components` will still lose to a single class selector inside `@layer utilities`, because layer order determines the winner. This eliminates specificity wars entirely.

### Browser Support

Chrome 99+, Firefox 97+, Safari 15.4+, Edge 99+.

### Fallback Strategy

Browsers that do not support `@layer` will ignore the layer declarations and treat all styles as unlayered (which has higher priority than layered styles). This means older browsers get the styles but without cascade ordering. For most projects, this is acceptable since the browsers that lack layer support are now extremely rare.

---

## 10. CSS Nesting

### Problem

Flat CSS selectors are verbose and repetitive. Developers depend on Sass or other preprocessors primarily for nesting syntax, adding a build step to the development process.

### Solution

Native CSS nesting allows selectors to be nested directly, with the `&` symbol representing the parent selector.

**Basic nesting syntax:**

```css
.card {
  padding: 1.5rem;
  border-radius: 12px;
  background: var(--surface);

  .card__title {
    font-size: 1.25rem;
    font-weight: 600;
    margin-bottom: 0.5rem;
  }

  .card__body {
    color: var(--text-muted);
    line-height: 1.6;
  }

  .card__footer {
    margin-top: 1rem;
    display: flex;
    gap: 0.5rem;
  }
}
```

**The `&` selector for compound selectors and pseudo-classes:**

```css
.button {
  background: var(--primary);
  color: white;
  padding: 0.5rem 1rem;
  border-radius: var(--radius-md);
  transition: background 0.15s ease;

  &:hover {
    background: oklch(from var(--primary) calc(l + 0.08) c h);
  }

  &:active {
    background: oklch(from var(--primary) calc(l - 0.05) c h);
  }

  &:focus-visible {
    outline: 2px solid var(--primary);
    outline-offset: 2px;
  }

  /* Modifier pattern */
  &.button--large {
    padding: 0.75rem 1.5rem;
    font-size: 1.125rem;
  }

  &.button--ghost {
    background: transparent;
    color: var(--primary);
    border: 1px solid var(--primary);
  }

  /* Disabled state */
  &:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
}
```

**Media query nesting:**

```css
.sidebar {
  width: 280px;
  position: fixed;

  @media (max-width: 768px) {
    width: 100%;
    position: relative;
  }

  @media (prefers-reduced-motion: reduce) {
    transition: none;
  }
}
```

**Comparison with Sass nesting:**

```scss
/* Sass — requires build step */
.nav {
  &__item { ... }
  &__link {
    &:hover { ... }
    &--active { ... }
  }
}
```

```css
/* Native CSS — no build step needed */
.nav {
  .nav__item { ... }

  .nav__link {
    &:hover { ... }
    &.nav__link--active { ... }
  }
}
```

Note: Native CSS nesting does not support Sass-style partial selector concatenation (`&__item` to produce `.nav__item`). The `&` always represents the full parent selector.

### Browser Support

Chrome 120+, Firefox 117+, Safari 17.2+, Edge 120+. Relaxed nesting syntax (without requiring `&` before type selectors) is supported in Chrome 120+, Firefox 117+, Safari 17.2+.

### Fallback Strategy

Use a PostCSS nesting plugin during development to compile nested CSS for older browsers. Modern bundlers like Vite and Webpack can process this automatically.

---

## 11. Popover API

### Problem

Building accessible popovers, menus, and disclosures requires managing focus traps, keyboard interaction, light dismiss (clicking outside), stacking context, and ARIA attributes. This is error-prone and typically requires a JavaScript UI library.

### Solution

The Popover API provides declarative popover behavior with built-in accessibility, light dismiss, focus management, and top-layer stacking, all without JavaScript.

**Basic popover:**

```html
<button popovertarget="menu">Open Menu</button>

<div id="menu" popover>
  <nav>
    <a href="/settings">Settings</a>
    <a href="/profile">Profile</a>
    <a href="/logout">Log out</a>
  </nav>
</div>
```

**Popover actions:**

```html
<!-- Toggle (default) -->
<button popovertarget="info" popovertargetaction="toggle">Toggle Info</button>

<!-- Explicit show/hide -->
<button popovertarget="info" popovertargetaction="show">Show Info</button>
<button popovertarget="info" popovertargetaction="hide">Hide Info</button>
```

**Styling popovers:**

```css
[popover] {
  /* Reset default popover styles */
  border: none;
  padding: 0;
  margin: 0;
  background: none;

  /* Custom styles */
  &:popover-open {
    display: flex;
    flex-direction: column;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 0.5rem;
    box-shadow: 0 12px 32px oklch(0 0 0 / 0.1);
    min-width: 200px;
  }

  /* Backdrop styling (only for manual popovers) */
  &::backdrop {
    background: oklch(0 0 0 / 0.25);
    backdrop-filter: blur(2px);
  }
}
```

**Manual popover (no light dismiss):**

```html
<!-- popover="manual" disables light dismiss — must be closed explicitly -->
<div id="toast" popover="manual">
  <p>File saved successfully.</p>
  <button popovertarget="toast" popovertargetaction="hide">Dismiss</button>
</div>
```

**Popover with entry animation (combining with @starting-style):**

```css
[popover] {
  opacity: 1;
  transform: scale(1);
  transition:
    opacity 0.2s ease,
    transform 0.2s ease,
    overlay 0.2s ease allow-discrete,
    display 0.2s ease allow-discrete;

  &:not(:popover-open) {
    opacity: 0;
    transform: scale(0.95);
  }
}

@starting-style {
  [popover]:popover-open {
    opacity: 0;
    transform: scale(0.95);
  }
}
```

Key advantages: Popovers are promoted to the top layer, so they are never clipped by `overflow: hidden` or stuck behind higher z-index elements. Light dismiss (clicking outside) is handled automatically. Focus management follows the accessibility spec.

### Browser Support

Chrome 114+, Firefox 125+, Safari 17+, Edge 114+.

### Fallback Strategy

Use the popover polyfill (`@oddbird/popover-polyfill`) for older browsers. The polyfill provides the same HTML API and JavaScript behavior. For CSS-only fallbacks, target the `[popover]` attribute with basic positioning:

```css
@supports not selector(:popover-open) {
  [popover] {
    display: none;
    position: fixed;
    z-index: 9999;
  }
  /* Requires JS toggle fallback */
}
```

---

## 12. Design System Integration Patterns

### Problem

Design systems must reconcile global tokens, component-scoped styles, responsive behavior, theming, and third-party CSS. Without a coherent architecture, these concerns clash and create maintenance nightmares.

### Solution

Modern CSS features combine to form a comprehensive design system architecture where each layer has a clear role.

**Complete architecture:**

```css
/* === Layer declaration: cascade hierarchy === */
@layer reset, tokens, base, components, utilities, overrides;

/* === Tokens layer: design tokens with light-dark() === */
@layer tokens {
  :root {
    color-scheme: light dark;

    /* Spacing scale */
    --space-1: 0.25rem;
    --space-2: 0.5rem;
    --space-3: 0.75rem;
    --space-4: 1rem;
    --space-6: 1.5rem;
    --space-8: 2rem;

    /* Color tokens using oklch + light-dark */
    --color-primary: light-dark(
      oklch(0.55 0.22 250),
      oklch(0.72 0.18 250)
    );
    --color-surface-1: light-dark(
      oklch(0.99 0.005 260),
      oklch(0.15 0.02 260)
    );
    --color-surface-2: light-dark(
      oklch(0.96 0.005 260),
      oklch(0.2 0.02 260)
    );
    --color-text-1: light-dark(
      oklch(0.15 0.02 260),
      oklch(0.93 0.01 260)
    );
    --color-text-2: light-dark(
      oklch(0.4 0.02 260),
      oklch(0.7 0.01 260)
    );
    --color-border: light-dark(
      oklch(0.88 0.01 260),
      oklch(0.3 0.02 260)
    );

    /* Computed color variants using color-mix */
    --color-primary-subtle: color-mix(
      in oklch, var(--color-primary) 12%, var(--color-surface-1)
    );
    --color-primary-hover: oklch(
      from var(--color-primary) calc(l + 0.08) c h
    );

    /* Typography */
    --font-sans: "Inter", system-ui, sans-serif;
    --font-mono: "JetBrains Mono", ui-monospace, monospace;

    /* Radius */
    --radius-sm: 6px;
    --radius-md: 8px;
    --radius-lg: 12px;
    --radius-full: 9999px;
  }
}

/* === Components layer: container-query responsive components === */
@layer components {
  /* Card component with container query responsiveness */
  .card-container {
    container: card / inline-size;
  }

  .card {
    display: grid;
    grid-template-rows: auto 1fr auto;
    gap: var(--space-2);
    padding: var(--space-4);
    background: var(--color-surface-1);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-lg);

    /* Container-responsive font sizing */
    .card__title {
      font-size: clamp(1rem, 2.5cqi, 1.5rem);
      font-weight: 600;
      color: var(--color-text-1);
    }

    .card__body {
      color: var(--color-text-2);
    }

    /* Adapt layout based on container width */
    @container card (min-inline-size: 450px) {
      grid-template-columns: 180px 1fr;
      grid-template-rows: auto 1fr;

      .card__image {
        grid-row: 1 / -1;
      }
    }
  }

  /* Button using :has() for icon detection */
  .button {
    display: inline-flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-4);
    background: var(--color-primary);
    color: white;
    border: none;
    border-radius: var(--radius-md);
    font: inherit;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s ease;

    &:hover {
      background: var(--color-primary-hover);
    }

    /* Adjust padding when button has only an icon */
    &:has(svg):not(:has(span)) {
      padding: var(--space-2);
      border-radius: var(--radius-full);
    }

    /* Adjust gap when button has icon + text */
    &:has(svg):has(span) {
      gap: var(--space-2);
    }
  }

  /* Form field with :has() validation */
  .form-field {
    display: grid;
    gap: var(--space-1);

    &:has(:focus-visible) {
      .form-field__label {
        color: var(--color-primary);
      }
    }

    &:has(:invalid:not(:placeholder-shown)) {
      .form-field__label {
        color: oklch(0.6 0.22 25);
      }

      .form-field__input {
        border-color: oklch(0.6 0.22 25);
      }

      .form-field__error {
        display: block;
      }
    }
  }

  /* Dialog with @starting-style entry animation */
  dialog.modal {
    background: var(--color-surface-1);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-lg);
    padding: var(--space-6);
    max-width: min(90vw, 560px);
    opacity: 1;
    transform: translateY(0);
    transition:
      opacity 0.25s ease,
      transform 0.25s ease,
      overlay 0.25s ease allow-discrete,
      display 0.25s ease allow-discrete;

    &::backdrop {
      background: oklch(0 0 0 / 0.4);
      backdrop-filter: blur(4px);
    }
  }

  @starting-style {
    dialog.modal[open] {
      opacity: 0;
      transform: translateY(-16px);
    }
  }
}

/* === Utilities layer: overrides everything below === */
@layer utilities {
  .text-center { text-align: center; }
  .text-balance { text-wrap: balance; }
  .visually-hidden {
    position: absolute;
    width: 1px;
    height: 1px;
    clip-path: inset(50%);
    overflow: hidden;
    white-space: nowrap;
  }
}
```

**Responsive tokens with container queries:**

```css
/* Tokens that adapt based on container size, not viewport */
.section-container {
  container: section / inline-size;
}

.section {
  --heading-size: 1.25rem;
  --body-size: 0.9375rem;
  --content-gap: var(--space-4);

  @container section (min-inline-size: 600px) {
    --heading-size: 1.75rem;
    --body-size: 1rem;
    --content-gap: var(--space-6);
  }

  @container section (min-inline-size: 900px) {
    --heading-size: 2.25rem;
    --body-size: 1.0625rem;
    --content-gap: var(--space-8);
  }
}
```

**Theme switching with layers and light-dark():**

```css
/* Toggle theme with a single property change */
:root {
  color-scheme: light dark;
}

/* Force light */
[data-theme="light"] {
  color-scheme: light;
}

/* Force dark */
[data-theme="dark"] {
  color-scheme: dark;
}

/* All light-dark() tokens adapt automatically */
```

This architecture provides: cascade control via layers so specificity never conflicts; component responsiveness via container queries so components work anywhere; automatic theming via `light-dark()` so themes require minimal code; computed colors via `color-mix()` and relative color syntax so palettes are derived from a few base tokens; accessible interactions via the popover API and `:has()` so less JavaScript is needed.

---

## Browser Support Matrix

| Feature | Chrome | Firefox | Safari | Edge |
|---|---|---|---|---|
| Container Queries | 105+ | 110+ | 16+ | 105+ |
| Container Query Units | 105+ | 110+ | 16+ | 105+ |
| `:has()` | 105+ | 121+ | 15.4+ | 105+ |
| Anchor Positioning | 125+ | In development | In development | 125+ |
| `@starting-style` | 117+ | 129+ | 17.5+ | 117+ |
| View Transitions (same-doc) | 111+ | 131+ | 18+ | 111+ |
| View Transitions (cross-doc) | 126+ | In development | In development | 126+ |
| Scroll-Driven Animations | 115+ | 130+ | 18+ | 115+ |
| Subgrid | 117+ | 71+ | 16+ | 117+ |
| `oklch()` | 111+ | 113+ | 15.4+ | 111+ |
| `color-mix()` | 111+ | 113+ | 16.2+ | 111+ |
| `light-dark()` | 123+ | 120+ | 17.5+ | 123+ |
| Relative Color Syntax | 119+ | 128+ | 16.4+ | 119+ |
| `@layer` | 99+ | 97+ | 15.4+ | 99+ |
| CSS Nesting | 120+ | 117+ | 17.2+ | 120+ |
| Popover API | 114+ | 125+ | 17+ | 114+ |

**Version date reference:** Chrome and Edge version numbers are closely aligned because Edge uses the Chromium engine. Firefox and Safari versions follow their own release cadences. All version numbers listed represent stable release versions where the feature shipped without flags.

**Evergreen browser guidance:** As of early 2026, all major browsers are evergreen (auto-updating). The features listed above with full cross-browser support -- container queries, `:has()`, subgrid, `oklch()`, `color-mix()`, `@layer`, CSS nesting, popover API, `@starting-style`, and scroll-driven animations -- can be used in production for audiences that do not require legacy browser support. Anchor positioning and cross-document view transitions remain Chromium-leading features that require fallback strategies for Firefox and Safari users.
