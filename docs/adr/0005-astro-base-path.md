# 0005. Astro `base: '/'` for custom-domain GitHub Pages hosting

- **Status**: Accepted
- **Date**: 2026-04-15
- **Updated**: 2026-05-06

## Context

The docs site (`site/`) is built with Astro + Starlight and published by GitHub Pages. It was originally served as a GitHub project Pages site at `https://travishankins.github.io/azure-launchpad/`, which required Astro `base: '/azure-launchpad/'`.

The project now has a dedicated custom apex domain, `https://azurelaunchpad.com`, with `site/public/CNAME` set to `azurelaunchpad.com`. With a custom apex domain, GitHub Pages serves the site at the origin root instead of under the repository path. Astro therefore needs `base: '/'` so generated asset URLs, Starlight routes, sitemap URLs, and wizard script references resolve correctly.

The site references its own assets, sidebar links, and the wizard's anchor links — every one of those breaks if `base` is wrong.

## Decision

Set `site: 'https://azurelaunchpad.com'` and `base: '/'` in [`site/astro.config.mjs`](../../site/astro.config.mjs). Keep [`site/public/CNAME`](../../site/public/CNAME) containing `azurelaunchpad.com` so Astro copies it into the build output and GitHub Pages preserves the custom-domain setting on each deploy.

Use root-relative links in site content and code, such as `/governance/budgets/` and `/wizard/`. Do not prefix internal links with `/azure-launchpad/`.

Configure DNS for the apex and `www` hostnames:

- `azurelaunchpad.com`: use an apex `ALIAS`/`ANAME` to `travishankins.github.io` if the DNS provider supports it, otherwise configure GitHub Pages `A` records. Add GitHub Pages `AAAA` records for IPv6.
- `www.azurelaunchpad.com`: create a `CNAME` pointing to `travishankins.github.io` (the account Pages hostname, not the repository URL).

Verify `azurelaunchpad.com` at the GitHub account level using the GitHub Pages TXT challenge, configure the repository Pages custom domain as `azurelaunchpad.com`, and enable Enforce HTTPS.

## Consequences

- Local dev (`npm run dev`) serves at `http://localhost:4321/`.
- The GitHub Pages default URL may still exist, but `https://azurelaunchpad.com` is the canonical public URL.
- Repository renames no longer require changing Astro `base` or internal links.
- Custom Open Graph images, robots.txt, favicon, and `scripts/wizard.js` all live under `site/public/` and are served from the root path.
- The domain setup has a small amount of external DNS/GitHub Pages state. Keep the repo `CNAME`, GitHub Pages custom-domain setting, account-level domain verification, and DNS records in sync.

## Alternatives considered

- **Keep project Pages at `/azure-launchpad/`**: rejected now that `azurelaunchpad.com` exists. It makes links less clean and requires a non-root Astro base path.
- **Deploy to the user-site (`travishankins.github.io` root)**: rejected — that root is reserved for one repo, and this project already has its own domain.
- **Proxy or redirect `azurelaunchpad.com` to `travishankins.github.io/azure-launchpad/`**: rejected — it preserves the old project-path complexity and can create confusing canonical URLs.
