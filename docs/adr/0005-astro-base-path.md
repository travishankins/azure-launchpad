# 0005. Astro `base: '/azure-launchpad/'` for GitHub Pages hosting

- **Status**: Accepted
- **Date**: 2026-04-15

## Context

The docs site (`site/`) is built with Astro + Starlight and published to GitHub Pages at `https://travishankins.github.io/azure-launchpad/`. GitHub Pages serves project sites under a sub-path (`/<repo-name>/`), not at the root of the domain. Astro requires a matching `base` config so internal links, asset URLs, and the Starlight router resolve correctly.

The site references its own assets, sidebar links, and the wizard's anchor links — every one of those breaks if `base` is wrong.

## Decision

Set `base: '/azure-launchpad/'` (with the trailing slash) in [`site/astro.config.mjs`](../../site/astro.config.mjs). All in-page links use **absolute paths beginning with `/azure-launchpad/`** (e.g. `/azure-launchpad/governance/budgets/`), never bare `/governance/budgets/` or relative `../governance/budgets/`.

The `site` value is set to the production GitHub Pages origin so the generated `sitemap.xml` and Open Graph URLs are absolute.

## Consequences

- Local dev (`npm run dev`) serves at `http://localhost:4321/azure-launchpad/` — not the bare root. Contributors need to know to add the `/azure-launchpad/` segment when typing URLs by hand.
- If the repo is ever renamed, **all three** of `base`, `site`, and every absolute link in markdown / wizard.js have to change. ADR 0005 is the canonical reminder of this.
- The Starlight sidebar uses repo-relative links (`/governance/budgets/`) that Astro automatically prefixes with `base` at build time, so they stay portable.
- Custom Open Graph images, robots.txt, and favicon all live under `site/public/` and are served at `/azure-launchpad/<file>` correctly without extra config.

## Alternatives considered

- **Custom domain (CNAME)**: rejected for now — adds DNS + TLS cert lifecycle to the project. Revisit if/when the project gets its own domain.
- **Deploy to the user-site (`travishankins.github.io` root)**: rejected — that root is reserved for one repo, and we don't want to claim it for a single sample project.
- **Astro `base: '/'` and rewrite at the proxy layer**: rejected — adds infrastructure (Cloudflare Worker / equivalent) for a problem the framework already solves natively.
