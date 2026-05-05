---
title: vs the ALZ Accelerator
description: When to use Azure Launchpad (SMB / SMEC Edition) versus Microsoft's official Azure Landing Zone Accelerator for enterprise.
---

Microsoft publishes an official [**Azure Landing Zone (ALZ) Accelerator**](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/) for both [Bicep](https://github.com/Azure/ALZ-Bicep) and [Terraform](https://github.com/Azure/terraform-azurerm-avm-ptn-alz). It's excellent — and large. **Azure Launchpad is intentionally smaller, opinionated, and SMB / SMEC-shaped.**

This page helps you decide which one fits.

## TL;DR

| Question                                               | Use Microsoft's ALZ Accelerator | Use Azure Launchpad |
| ------------------------------------------------------ | ------------------------------- | ------------------- |
| You have a dedicated platform team of 5+ people        | ✅                              | also fine           |
| You'll run 50+ subscriptions across the org            | ✅                              | —                   |
| You need every CAF pillar wired up day one             | ✅                              | —                   |
| You want **one repo, four cost tiers, one command**    | —                               | ✅                  |
| You want a guided wizard that emits the parameter file | —                               | ✅                  |
| Your monthly Azure spend is < $5k                      | maybe overkill                  | ✅                  |
| You want to learn ALZ concepts without 30+ modules     | —                               | ✅                  |
| You operate from a single hub region                   | both                            | ✅                  |

If you're an enterprise with a fully-staffed cloud platform team, **use Microsoft's accelerator**. If you're a small or midsized organization that wants ALZ-aligned defaults without weeks of setup, **use this**.

## Side-by-side

| Aspect                                                  | Microsoft ALZ Accelerator                                              | Azure Launchpad (SMB / SMEC)                                      |
| ------------------------------------------------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------- |
| **Audience**                                            | Large enterprise / regulated                                           | SMB and SMEC                                                      |
| **Target spend**                                        | $10k+ / month                                                          | $48 – $616 / month                                                |
| **Scenarios**                                           | One full reference, configurable                                       | Four pre-tiered scenarios (baseline, firewall, vpn, full)         |
| **Module count**                                        | 30+ (Bicep) / 20+ (TF)                                                 | ~10 per stack                                                     |
| **Management Groups**                                   | Required, full ALZ tree                                                | Opt-in module, simplified tree                                    |
| **Identity**                                            | Dedicated `identity` MG + Entra Connect guidance                       | Hooks documented; no resources deployed by default                |
| **Security stack**                                      | Defender for Cloud across plans, Sentinel, Key Vault, Bastion          | Key Vault + LAW; Defender / Sentinel left for you to enable       |
| **Connectivity**                                        | Hub-spoke or vWAN, ExpressRoute + VPN, Azure Firewall Standard/Premium | Hub-spoke, VPN gateway, Azure Firewall **Basic**                  |
| **Backup**                                              | Recovery Services Vault + policies + cross-region restore              | RSV deployed; policies left for you to add                        |
| **Monitoring**                                          | Workspace + DCRs + workbooks + alerts                                  | Workspace + diagnostic settings; DCRs/workbooks/alerts on roadmap |
| **Governance**                                          | Full ALZ policy initiative (~80 policies)                              | Starter policy catalog in the opt-in MG module                    |
| **Tooling**                                             | Azure Portal accelerator + IaC + AzOps                                 | IaC + interactive wizard + Astro/Starlight docs site              |
| **Time-to-deploy**                                      | Days to weeks (planning + customisation)                               | < 1 hour (wizard → tfvars → apply)                                |
| **Lifecycle ownership**                                 | Dedicated platform team                                                | One or two part-time engineers                                    |
| **Customisation surface**                               | Very large                                                             | Small and explicit                                                |
| **Both Terraform and Bicep, byte-for-byte equivalent?** | Two separate projects                                                  | ✅ Yes — one repo, both stacks, identical resources               |

## Why "smaller" is sometimes the right answer

The official ALZ Accelerator is built for enterprises that **already have**:

- A platform engineering team that owns the foundation full-time
- Dozens of application teams consuming subscriptions
- Compliance frameworks (PCI, HIPAA, SOC 2) driving every default
- A budget where the foundation cost is rounding error

If you're not in that situation, the accelerator's defaults — Defender for Cloud across every plan, Sentinel, Bastion, Firewall Premium, multi-region monitoring — can easily run **$3 000+/month** _before you deploy a single workload_. The full Azure Launchpad scenario runs ~$616/month for the same shape (hub-spoke + firewall + VPN), and baseline runs ~$48/month.

## Where Azure Launchpad is **not** the right tool

- You need vWAN. We're hub-spoke only.
- You're regulated and audited against ALZ-Bicep / ALZ-TF parity. Use the official thing — auditors recognise it.
- You need 4 nested levels of MGs across 200 subscriptions. The opt-in MG module here is intentionally 2 levels deep.
- You need Sentinel + Defender plans wired up by IaC. Roadmap, not today.
- You want every CAF policy out of the box. We ship a starter set; the official accelerator ships ~80.

## Migration path

You can start with Azure Launchpad and graduate to the official accelerator later:

1. **Now:** deploy `baseline` or `full` here. Operate. Learn.
2. **6–12 months in:** if you outgrow it (more subs, more compliance, more teams), stand up the official accelerator alongside your existing deployment under a new MG branch.
3. **Migrate workloads** spoke-by-spoke. Tear down the Launchpad foundation when empty.

The deployments are intentionally tagged (`workload = "azure-launchpad"`) so they're trivially distinguishable in cost reporting and the portal.

## Credits

The architecture, naming, and module choices in this repo are directly inspired by the [CAF Ready methodology](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/) and the [ALZ design areas](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-areas). Where an [Azure Verified Module](https://aka.ms/avm) exists, this repo uses it.

This project is **not** affiliated with or endorsed by Microsoft.
