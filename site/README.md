# Landing page

The site at <https://unfocused.stefanhoth.com>: one static page with a description, screenshots and install instructions. No build step and no dependencies; what's in `public/` is what ships.

## Layout

- `public/`: the site as served. `index.html`, `styles.css`, `main.js`, `img/`, self-hosted `fonts/` (Switzer, Fontshare free licence), `_headers` (CSP, HSTS, caching).
- `og/og.html`: source of `public/og.png`, the 1200×630 social sharing image. Re-render with `make site-og`.
- `wrangler.jsonc`: Cloudflare Workers config (static assets only, custom domain).
- `assets-src/credits.json`: where each found picture comes from and its licence. The originals are not committed.

## Work on it

```bash
make site      # http://127.0.0.1:8787
make site-og   # after changing og/og.html or the hero screenshot
```

The page has no third-party requests: fonts and images are local, and the CSP in `public/_headers` only allows `'self'` plus the one inline script by hash. Change the hash there if you change that line in `index.html`:

```bash
printf "%s" "document.documentElement.classList.add('js')" | openssl dgst -sha256 -binary | openssl base64
```

## Screenshots

App screenshots come from the dev build on made-up data (`make demo SHOW=…`, see [docs/local-development.md](../docs/local-development.md#screenshots-on-made-up-data)), never from a real database. Convert them with `cwebp -q 86 -alpha_q 100`; crop panel captures with `-crop 76 74 1752 874`.

## Design

The direction is "the page is the object": the app's own vocabulary is rope (Loop, Anchor, Loose End, Tie-off), so the page is set like a plate from an old knot manual. Paper sheets on stone, charcoal ink, the app icon's blue as the only accent, and 19th-century rope engravings next to the real screens. The house rules (no gradients, no shadows on resting elements, no eyebrow labels, headlines of two lines at most) follow the `design-taste-frontend` skill.

## Deploys

`.github/workflows/site.yml` runs only when `site/` changes:

- **Pull requests** upload a preview version: `https://pr-<number>-unfocused.stefanhoth-de.workers.dev`, linked as a `site-preview` deployment on the PR.
- **`main`** deploys to `unfocused.stefanhoth.com`.

One-time setup, done by hand:

1. Add the repository secrets `CLOUDFLARE_API_TOKEN` (Workers Scripts: Edit, plus Zone → Workers Routes: Edit for `stefanhoth.com`) and `CLOUDFLARE_ACCOUNT_ID`, as for monomix.
2. Create the `unfocused` Worker once, before the first PR preview: `wrangler versions upload` refuses a Worker that doesn't exist yet. It was created as a placeholder script, with preview URLs on and the plain workers.dev address off (`enabled: false, previews_enabled: true` on the script's subdomain settings). Running `wrangler deploy` in `site/` does the same.
3. The first deploy from `main` replaces the placeholder with the site and adds the `unfocused.stefanhoth.com` custom domain, including its DNS record.
4. Set the repository's website to `https://unfocused.stefanhoth.com`.

## Picture credits

- “Making knots and splices” (1919), public domain, via Wikimedia Commons.
- Captain H. Paasch, *Illustrated Marine Encyclopedia* (1890), plate 99, CC BY-SA 4.0, via Wikimedia Commons.
- “Ship-building: ropes and blocks”, engraving (1806), Wellcome Collection, CC BY 4.0, via Wikimedia Commons.

The footer of the page carries the same credits with links.
