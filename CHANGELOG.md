# Changelog

## [0.1.1](https://github.com/travishankins/azure-launchpad/compare/v0.1.0...v0.1.1) (2026-05-08)


### ✨ Features

* **bicep:** multi-sub firewall/vpn/full scenarios + cross-sub PDZ link ([ca0026c](https://github.com/travishankins/azure-launchpad/commit/ca0026cc7b0108ec6059ed9ed11bb422041f9b1a))
* CI hardening, release automation, and reference docs trio ([a74ea7a](https://github.com/travishankins/azure-launchpad/commit/a74ea7adf954325912a37eaa67d2abe4a334e7f1))
* **docs:** wire up mermaid rendering via astro-mermaid ([1933aa9](https://github.com/travishankins/azure-launchpad/commit/1933aa9f94edf051eea3e3a475c040b880f99d35))
* **governance:** opt-in subscription budget module (TF + Bicep parity) ([a67af4f](https://github.com/travishankins/azure-launchpad/commit/a67af4ff37f9c72b7fb4753ee9c8c6b064099aef))
* **phase-3:** devcontainer + Justfile + workbook + ADRs + wizard advanced mode ([134ca6a](https://github.com/travishankins/azure-launchpad/commit/134ca6a5d5a64cdf1a805c4b492a75a5da6a27e1))
* **phase-4:** multi-subscription deployment mode (ALZ 3-sub split) ([8082e35](https://github.com/travishankins/azure-launchpad/commit/8082e35b716da4c1b65a1f6088befea7f461238a))
* **site:** switch to custom domain azurelaunchpad.com ([ff8c236](https://github.com/travishankins/azure-launchpad/commit/ff8c23686d962ce72e443d4d3d641c5fa779365a))


### 🐛 Bug fixes

* align VPN scenario docs and config ([f690463](https://github.com/travishankins/azure-launchpad/commit/f690463c26dcf3c18d040c04f17314f65b7c91da))
* align VPN scenario docs and config ([a861b13](https://github.com/travishankins/azure-launchpad/commit/a861b13af34f3aa256a10940ad3a20368569c6eb))
* **ci:** drop SITE_BASE override now that we serve from custom domain root ([37ae00f](https://github.com/travishankins/azure-launchpad/commit/37ae00fa310ae5a4a3f66306c2b914698d1a6ccb))
* **gitignore:** allow hand-authored workbook JSON under infra/bicep/**/workbooks/ ([214f80e](https://github.com/travishankins/azure-launchpad/commit/214f80e9a59f5120ac6f291e199d24c7eddbbe27))


### 📖 Documentation

* add Azure Cloud Shell path and expand Codespaces guidance ([5f71acc](https://github.com/travishankins/azure-launchpad/commit/5f71accdf1e6c2487eb734370f56122cd388cd9e))
* add post-deploy VPN examples ([168d474](https://github.com/travishankins/azure-launchpad/commit/168d474139957bc65e109ce3b59797e79dba5731))
* add scenario decision guide ([74d0429](https://github.com/travishankins/azure-launchpad/commit/74d0429cf0c733235ce3a3131104f1c237920a82))
* clarify quick start subscription flow ([63a40ab](https://github.com/travishankins/azure-launchpad/commit/63a40abcada32f759a286e4e2cafc066b3118b10))
* clarify quick start subscription flow ([92e7005](https://github.com/travishankins/azure-launchpad/commit/92e70058c5b14056103ecbb71316c83fc4be65b3))
* document launchpad non-goals ([32bcdfb](https://github.com/travishankins/azure-launchpad/commit/32bcdfb0de44bb3b5023a1562d7bedcad022b60e))
* **governance:** align management-groups page with multi-sub mode ([f09daed](https://github.com/travishankins/azure-launchpad/commit/f09daed6dc9e5b90434d984b0423ca35365898dc))
* **governance:** rename Foundation Health workbook -&gt; Monitoring workbook ([652b003](https://github.com/travishankins/azure-launchpad/commit/652b0034c9e9bf4ca07c87a848e62f84a7757eba))
* **governance:** rework workbook page, drop unrendered MDX import ([3b8fc9d](https://github.com/travishankins/azure-launchpad/commit/3b8fc9de9348b6d387bcefb126655e39ce0a42ac))
* **infra:** annotate AVM blocks with known upstream deprecations ([f670ad5](https://github.com/travishankins/azure-launchpad/commit/f670ad5ff3b2e918a90d0d885ac21f031705503c))
* link existing budgets module and add bicep psk rotation ([3170353](https://github.com/travishankins/azure-launchpad/commit/317035317e009f365842a697662bc4781c289602))
* **reference:** rename Operations & teardown -&gt; Day-2 operations ([b6210b1](https://github.com/travishankins/azure-launchpad/commit/b6210b19f8a55846ebc09378ef4525638fb78db4))
* **reference:** replace mermaid diagrams with ASCII art ([81ec3d1](https://github.com/travishankins/azure-launchpad/commit/81ec3d1a765f9554180e7967ebf6d518173ccde7))
* **scenarios:** expand multi-subscription page ([cd54739](https://github.com/travishankins/azure-launchpad/commit/cd54739fae9b1676bcc8650e310a4cd774ebfb96))
* **scenarios:** fix mode table wrapping on multi-sub page ([dcda7dd](https://github.com/travishankins/azure-launchpad/commit/dcda7dda5496ee10fe8ac3930780343243afc5f4))
* **scenarios:** fix multi-subscription page rendering ([1d789a8](https://github.com/travishankins/azure-launchpad/commit/1d789a8ec89572ebb3ddbfd1388ecd597b5d4147))
* surface the dev container in README + Prerequisites page ([e15fe14](https://github.com/travishankins/azure-launchpad/commit/e15fe143fe6cfa0f374f5b2d478110d79932187d))
* update GitHub Pages custom domain ADR ([bf8d6eb](https://github.com/travishankins/azure-launchpad/commit/bf8d6eb4004c5b9a61a3433e53385de40a9ebd6c))
* update GitHub Pages custom domain ADR ([4d34194](https://github.com/travishankins/azure-launchpad/commit/4d34194ed9ff6354574a97c987e2f489923deb17))


### 🤖 CI / CD

* build multi-subscription bicep templates ([c760a0e](https://github.com/travishankins/azure-launchpad/commit/c760a0e2aae4e43d6cab0b00fe43a8cb616aff99))
* run terraform tests in plan workflow ([ea73771](https://github.com/travishankins/azure-launchpad/commit/ea7377156acbfdba5a0bf178a9ea9ad39f9fa03c))

## Changelog

All notable changes to this project will be documented in this file.

This file is maintained by [release-please](https://github.com/googleapis/release-please) based on [Conventional Commits](https://www.conventionalcommits.org/) since the `0.1.0` baseline.
