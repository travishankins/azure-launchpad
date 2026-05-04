// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// Repo name -> base path for GitHub Pages project sites.
const REPO = 'smb-foundations';
const OWNER = process.env.GH_OWNER ?? 'travishankins';

export default defineConfig({
  site: `https://${OWNER}.github.io`,
  base: process.env.SITE_BASE ?? `/${REPO}/`,
  integrations: [
    starlight({
      title: 'SMB Foundations — Azure Landing Zones',
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
            { label: 'VPN (~$187)', link: '/scenarios/vpn/' },
            { label: 'Full (~$476)', link: '/scenarios/full/' },
          ],
        },
        {
          label: 'Governance (optional)',
          items: [
            { label: 'Management Groups', link: '/governance/management-groups/' },
            { label: 'Policy catalog', link: '/governance/policy-catalog/' },
          ],
        },
        {
          label: 'Reference',
          items: [
            { label: 'Architecture', link: '/reference/architecture/' },
            { label: 'Operations & teardown', link: '/reference/operations/' },
            { label: 'CI/CD pipeline', link: '/reference/cicd/' },
            { label: 'FAQ', link: '/reference/faq/' },
          ],
        },
      ],
      customCss: ['./src/styles/custom.css'],
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
