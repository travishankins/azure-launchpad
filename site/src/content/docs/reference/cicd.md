---
title: CI/CD pipeline
description: GitHub Actions workflows for plan and apply, using OIDC.
---

Two workflows ship in `.github/workflows/`:

| Workflow              | Trigger                    | What it does                                                                                                                       |
| --------------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `terraform-plan.yml`  | Pull request to `main`     | `fmt -check`, `validate`, `tfsec`, then matrix-`plan` over all 4 scenarios. Uploads each plan as an artifact.                      |
| `terraform-apply.yml` | Manual `workflow_dispatch` | `init`, select workspace for the chosen scenario, `apply -auto-approve`. Gated by the `prod` GitHub environment (manual approval). |

## OIDC federated credential

No client secrets — the apply job exchanges a GitHub-issued OIDC token for an Azure access token. Set this up once per repo:

```bash
APP_NAME="smb-foundations-gha"
SUB_ID=<subscription-id>
TENANT_ID=<tenant-id>
REPO=<owner>/smb-foundations

# 1. Create app registration + service principal
APP_ID=$(az ad app create --display-name $APP_NAME --query appId -o tsv)
az ad sp create --id $APP_ID

# 2. Grant Contributor on the subscription
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/$SUB_ID

# 3. Federated credential for plan jobs (on PRs)
az ad app federated-credential create --id $APP_ID --parameters '{
  "name":"gha-pr",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:'$REPO':pull_request",
  "audiences":["api://AzureADTokenExchange"]
}'

# 4. Federated credential for apply (on protected env)
az ad app federated-credential create --id $APP_ID --parameters '{
  "name":"gha-prod",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:'$REPO':environment:prod",
  "audiences":["api://AzureADTokenExchange"]
}'
```

Then add these **repo variables** (Settings → Secrets and variables → Actions → Variables):

| Variable                | Value                            |
| ----------------------- | -------------------------------- |
| `AZURE_CLIENT_ID`       | `$APP_ID` from step 1            |
| `AZURE_TENANT_ID`       | Your Entra tenant ID             |
| `AZURE_SUBSCRIPTION_ID` | Target subscription              |
| `TFSTATE_RG`            | From `bootstrap-state.sh` output |
| `TFSTATE_SA`            | From `bootstrap-state.sh` output |
| `TFSTATE_CONTAINER`     | `tfstate`                        |

## Protect `prod`

Settings → Environments → New environment → `prod` → enable **Required reviewers**.

## Local pre-commit equivalence

```bash
cd infra/terraform/foundation
terraform fmt -recursive -check
terraform init -backend=false
terraform validate
terraform test
```

The plan workflow runs the same five commands plus `tfsec`.
