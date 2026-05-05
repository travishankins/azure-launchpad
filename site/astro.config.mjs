// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import mermaid from 'astro-mermaid';

// Custom domain (azurelaunchpad.com) — apex hosted on Cloudflare DNS,
// proxied by GitHub Pages. The legacy GitHub Pages URL
// (travishankins.github.io/azure-launchpad) automatically redirects.
const REPO = 'azure-launchpad';
const OWNER = process.env.GH_OWNER ?? 'travishankins';

export default defineConfig({
  site: process.env.SITE_URL ?? 'https://azurelaunchpad.com',
  base: process.env.SITE_BASE ?? '/',
  redirects: {
    // Renamed 2026-05: Foundation Health workbook -> Monitoring workbook.
    '/governance/workbook/': '/governance/monitoring-workbook/',
    // Renamed 2026-05: Operations & teardown -> Day-2 operations.
    '/reference/operations/': '/reference/day-2-operations/',
  },
  integrations: [
    // Must come BEFORE starlight so the remark plugin runs first.
    mermaid({
      theme: 'default',
      autoTheme: true,
    }),
    starlight({
      title: '🚀 Azure Launchpad (SMB / SMEC Edition)',
      description:
        'Deploy a hub-spoke Azure landing zone with either Terraform or Bicep, plus an interactive deployment wizard.',
      social: {
        github: `https://github.com/${OWNER}/${REPO}`,
      },
      sidebar: [
        {
          label: 'Start here',
          items: [
            { label: 'Overview', link: '/' },
            { label: 'Deployment wizard', link: '/wizard/' },
          ],
        },
        {
          label: 'Getting started',
          items: [
            { label: 'Prerequisites', link: '/getting-started/prerequisites/' },
            { label: 'Quick start (Terraform)', link: '/getting-started/quick-start/' },
            { label: 'Quick start (Bicep)', link: '/getting-started/quick-start-bicep/' },
          ],
        },
        {
          label: 'Scenarios',
          items: [
            { label: 'Compare all four', link: '/scenarios/' },
            { label: 'Baseline (~$48)', link: '/scenarios/baseline/' },
            { label: 'Firewall (~$336)', link: '/scenarios/firewall/' },
            { label: 'VPN (~$327)', link: '/scenarios/vpn/' },
            { label: 'Full (~$616)', link: '/scenarios/full/' },
            { label: 'Multi-subscription (ALZ split)', link: '/scenarios/multi-subscription/' },
          ],
        },
        {
          label: 'Governance (optional)',
          items: [
            { label: 'Management Groups', link: '/governance/management-groups/' },
            { label: 'Policy catalog', link: '/governance/policy-catalog/' },
            { label: 'Budgets', link: '/governance/budgets/' },
            { label: 'Monitoring workbook', link: '/governance/monitoring-workbook/' },
          ],
        },
        {
          label: 'Reference',
          items: [
            { label: 'Architecture', link: '/reference/architecture/' },
            { label: 'Day-2 operations', link: '/reference/day-2-operations/' },
            { label: 'CI/CD pipeline', link: '/reference/cicd/' },
            { label: 'Troubleshooting', link: '/reference/troubleshooting/' },
            { label: 'Glossary', link: '/reference/glossary/' },
            { label: 'vs the ALZ Accelerator', link: '/reference/vs-alz-accelerator/' },
            { label: 'FAQ', link: '/reference/faq/' },
          ],
        },
      ],
      customCss: ['./src/styles/custom.css'],
      components: {
        // Hide the "On this page" table of contents site-wide.
        PageSidebar: './src/components/EmptyPageSidebar.astro',
      },
      head: [
        // Don't leak page URLs (which never contain secrets, but may carry
        // wizard state in future) via the Referer header on outbound clicks.
        {
          tag: 'meta',
          attrs: { name: 'referrer', content: 'no-referrer' },
        },
      ],
    }),
  ],
});
