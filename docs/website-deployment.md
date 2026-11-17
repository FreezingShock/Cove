# Deploying the Inlet website

The landing page in `website/` is plain static HTML, CSS and JavaScript. It is hosted on **GitHub Pages**, published by the workflow in `.github/workflows/website.yml`.

## Why GitHub Pages

- **Free for this repo.** The repository is public, and Pages is free on public repos.
- **No new account.** It runs on the GitHub account and repo you already use.
- **Deploys from the same flow as the app.** Merging `integration` into `main` publishes the site.

Vercel was the alternative. It gives a live preview for every branch, but it needs a separate account and a project connected to this repo. GitHub Pages hosts one site per repo, so PR previews come as downloadable artifacts instead (see below).

## How it works

| Event | What runs |
| --- | --- |
| PR into `integration` that touches `website/` | `check` job: checks links, anchors and the privacy rule, and uploads the site as the `inlet-website` artifact |
| Push to `integration` that touches `website/` | Same `check` job |
| Push to `main` that touches `website/` (nate's release merge) | `check`, then `deploy` publishes `website/` to Pages |
| Manual run from `main` (Actions tab, Run workflow) | Same as the push to `main`, even with no site change |
| A release is published, edited, unpublished or deleted | Redeploys the site, so the release notes stay current |

To preview a PR's site, open the run in the Actions tab, download the `inlet-website` artifact, unzip it, and open `index.html`.

`scripts/check-website.py` fails the build on:

- a link or image to a file that does not exist,
- a `#anchor` with no matching `id`,
- any script, stylesheet, image, font or media file loaded from another site. The page promises no external requests, so this check enforces that.

## One-time setup (nate)

1. **Pages source.** Go to **Settings > Pages > Build and deployment > Source** and choose **GitHub Actions**. The workflow turns this on by itself where it is allowed. If the first deploy fails with a Pages error, set it here.
2. **Custom domain (optional, after you buy one).** Go to **Settings > Pages > Custom domain**, enter the domain, and save. Then follow the DNS steps below.

Nothing else is needed. The first deploy happens the next time `website/` changes on `main`, or when you run the workflow by hand.

## Release notes on the changelog page

The changelog page lists every published GitHub Release, newest first. `scripts/release/render-changelog.py` builds that list from `gh api repos/<repo>/releases` and writes it into `changelog.html` between the `release-notes` markers. It runs in two places:

- **PR previews** (the check job) render the page on the runner, so the `inlet-website` artifact shows what goes live.
- **Deploy** (the deploy job) renders the staged copy of the site, so the live page never asks GitHub from a visitor's browser.

Drafts are skipped. Pre-releases are listed and marked. The newest full release is marked Latest.

The site redeploys when a release is published, edited, unpublished or deleted, so fixing a release's notes on GitHub updates the page. Release notes should be plain Markdown. Images in them are dropped, so the page never loads anything from another site.

Run the renderer tests with `python3 scripts/release/test_render_changelog.py`.

## Pointing "Get Inlet" at the release

The download button should go to the newest release's DMG using GitHub's stable URL:

```
https://github.com/FreezingShock/Inlet/releases/latest/download/Inlet.dmg
```

This works only when:

- the release is published (not a draft or pre-release), and
- its DMG asset is named exactly `Inlet.dmg`.

Until the first signed release exists, that URL returns a 404. Keep the site's current "no signed download yet" note until then, and switch the button over once a release is out.

## Domain

Nothing here is bought yet. Nate buys the domain himself.

First check the name is free at the registrar and that the trademark check is clear. A `.app` domain only loads over HTTPS, which GitHub Pages provides once DNS is set. A `.com` needs no extra setup.

### Registrar prices (USD, checked 19 Oct 2026 and 3 Nov 2026)

| Registrar | Extension | First year | Renewal per year | Notes |
| --- | --- | --- | --- | --- |
| Porkbun | .com | $11.08 | $11.08 | Flat price. ICANN fee, WHOIS privacy and SSL included. |
| Spaceship | .com | $8.88 (sale) | $9.98 | Plus a $0.20 ICANN fee at checkout. Sells at cost. |
| Dynadot | .com | $10.88 | $10.88 | First-year code 899COM drops year one to $8.99 (limited). |
| Namecheap | .com | $11.28 (sale) | $18.48 | Renewal jumps. Compare the renewal, not year one. |
| Cloudflare Registrar | .app | $8.20 | $14.20 | At cost, no markup. Domains must use Cloudflare nameservers. |
| Porkbun | .app | $8.75 | $14.93 | Flat price with privacy included. |

Sources: [Dupple, cheapest .com registrars, Oct 2026](https://dupple.com/learn/cheapest-domain-registrars) and [CostGoat, .app price comparison, Nov 2026](https://costgoat.com/compare/domains/app). Prices change. Check the registrar before you buy.

### Recommendation

- If a `.com` for the name is free, buy it at **Porkbun** ($11.08 a year, same price every year, privacy and fees included).
- If only a `.app` is free, buy it at **Cloudflare Registrar** ($8.20 the first year, $14.20 after, no markup). Cloudflare requires its own DNS, which works fine with GitHub Pages.

Avoid a first-year code if you plan to keep the name. The renewal is what you pay every year after.

## Connecting the domain

1. In **Settings > Pages**, enter the domain under **Custom domain** and save.
2. At your DNS provider, add these records.

   For an apex domain such as `example.com`:

   ```
   A     @   185.199.108.153
   A     @   185.199.109.153
   A     @   185.199.110.153
   A     @   185.199.111.153
   AAAA  @   2606:50c0:8000::153
   AAAA  @   2606:50c0:8001::153
   AAAA  @   2606:50c0:8002::153
   AAAA  @   2606:50c0:8003::153
   ```

   For the `www` subdomain, add `CNAME  www  FreezingShock.github.io`. GitHub then redirects one to the other.

   Do not add a wildcard (`*`) record.

3. Wait for DNS to update (up to 24 hours). Check with `dig example.com +noall +answer -t A`. The results should match the four IPs above.
4. Once the certificate is issued, tick **Enforce HTTPS** in **Settings > Pages**. GitHub may take up to 24 hours to offer this option.

Source: [GitHub Docs, managing a custom domain for GitHub Pages](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site).

## Running the checker locally

```sh
python3 scripts/check-website.py website
```

It uses only the Python standard library.
