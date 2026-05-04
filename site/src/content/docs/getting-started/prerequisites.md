---
title: Prerequisites
description: What you need before deploying the SMB Foundations landing zone.
---

## Tooling

| Tool                  | Minimum version | Why                             |
| --------------------- | --------------- | ------------------------------- |
| Terraform             | 1.9             | Module syntax, validation rules |
| Azure CLI             | 2.60            | `az login`, bootstrap script    |
| GitHub CLI (optional) | 2.40            | OIDC federated credential setup |
| `git`                 | 2.30            | Clone the repo                  |

## Azure access

- An Azure subscription where you have **Owner** at the subscription scope (needed once for the Service Principal + bootstrap RG/storage).
- Permission to create app registrations in Microsoft Entra ID (or an existing app registration you can reuse).
- For `vpn` / `full`: knowledge of the customer's on-premises VPN device public IP, supported IKE versions, and the on-premises CIDR(s) that should be reachable.

## Local prep

```bash
git clone https://github.com/travishankins/smb-foundations.git
cd smb-foundations
az login
az account set --subscription <subscription-id>
```

## State backend (one-time per customer)

```bash
export ARM_SUBSCRIPTION_ID=<subscription-id>
./scripts/bootstrap-state.sh
```

This creates:

- A resource group `rg-tfstate-<prefix>-<region>`
- A storage account `sttfstate<prefix><region><6-char-hash>`
- A blob container `tfstate`

The script is idempotent — re-running it just discovers the existing resources.

## CI/CD prerequisites (optional)

If you want plan/apply to run in GitHub Actions, you also need:

- An Entra ID app registration with a federated credential trusting your repo
- The repo variables listed in [CI/CD pipeline](/smb-foundations/reference/cicd/)
