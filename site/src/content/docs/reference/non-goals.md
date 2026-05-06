---
title: Non-goals
description: What Azure Launchpad intentionally does not do, so you know when to reach for something else.
---

Azure Launchpad is a small, opinionated landing-zone starter. To stay small and opinionated, it deliberately avoids a number of things. If you need any of these, plan for additional work or pick a different tool.

## Not in scope

- **Not a full ALZ Accelerator.** Launchpad covers the foundation (networking, identity boundary, monitoring, optional governance) for SMB / SMEC scale. For enterprise-scale ALZ with dozens of policies, multiple regions, and full guardrails, see the [comparison vs the ALZ Accelerator](/reference/vs-alz-accelerator/).
- **Not a managed service.** You own the deployment, the state file, the Azure subscription, and the lifecycle. Launchpad is code you clone, configure, and deploy.
- **No workload deployment.** The foundation prepares the landing zone (RGs, VNets, Key Vault, monitoring, optional firewall/VPN). It does not deploy applications, App Service plans, AKS clusters, databases, or workload-specific resources. Layer those on top.
- **VPN site-to-site connection deferred by design.** Foundation provisions the VPN Gateway (`VpnGw2AZ`), but the on-prem-specific pieces — Local Network Gateway, IPsec connection, PSK — are intentionally out of the foundation deploy because they require customer inputs (peer public IP, on-prem CIDRs, shared key). See [Post-deploy VPN connection](/reference/vpn-post-deploy/) for ready-to-use Terraform and Bicep snippets.
- **Azure Firewall Basic SKU only.** Standard and Premium SKUs are not exposed as toggles. See [ADR 0003](https://github.com/travishankins/azure-launchpad/blob/main/docs/adr/0003-firewall-basic-default.md) for the reasoning. Switching SKUs is a re-deploy.
- **Management Groups are opt-in.** The single-sub foundation does not create or move subscriptions into MGs. The optional `management-groups` stack is a separate deploy. See [ADR 0004](https://github.com/travishankins/azure-launchpad/blob/main/docs/adr/0004-management-groups-opt-in.md).
- **Single region by default.** Multi-region failover, paired-region replication topologies, and global front-door patterns are not built in. You can deploy multiple instances per region, but cross-region wiring is on you.
- **No Defender for Cloud / Sentinel packs (yet).** Workspace and Recovery Services Vault are deployed and ready for them, but plan-level Defender enablement and Sentinel content packs are not included.
- **No automated drift remediation.** Plans surface drift; reconciling it is a human decision.
- **No customer-data ingest.** The site has no analytics, telemetry, or third-party scripts. The wizard runs entirely in the browser.

## Things that look like gaps but aren't

- **AVM module versions are pinned.** This is intentional ([ADR 0002](https://github.com/travishankins/azure-launchpad/blob/main/docs/adr/0002-pin-avm-versions.md)). Bumps are reviewed, not automatic.
- **One scenario per workspace.** Switching scenarios means a new Terraform workspace / Bicep deployment name, not a flag flip on an existing one ([ADR 0001](https://github.com/travishankins/azure-launchpad/blob/main/docs/adr/0001-scenarios-as-workspaces.md)).

If something on this list feels like it should move to "in scope," open an issue with the use case.
