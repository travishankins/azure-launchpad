---
title: CI/CD pipeline
description: GitHub Actions workflows for plan and apply (Terraform + Bicep, foundation + management groups), using OIDC.
---

This repo ships **8 GitHub Actions workflows** under `.github/workflows/` — a plan + apply pair for each of the four root modules (Terraform foundation, Bicep foundation, Terraform management groups, Bicep management groups).

| Workflow                 | Trigger                                                      | Purpose                                                                                                  |
| ------------------------ | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| `terraform-plan.yml`     | PR to `main` touching `infra/terraform/foundation/**`        | `fmt -check`, `validate`, `tfsec`, matrix-`plan` over all 4 scenarios, uploads each plan as an artifact. |
| `terraform-apply.yml`    | Manual `workflow_dispatch` (pick scenario)                   | Creates a fresh saved plan, then applies that exact artifact after `prod` approval.                      |
| `bicep-plan.yml`         | PR to `main` touching `infra/bicep/foundation/**`            | `bicep build`, `az deployment sub what-if` for the chosen scenario, posts results as a PR comment.       |
| `bicep-apply.yml`        | Manual `workflow_dispatch`                                   | Runs what-if, then deploys after `apply` approval.                                                       |
| `terraform-mg-plan.yml`  | PR to `main` touching `infra/terraform/management-groups/**` | `validate` + `plan` for the MG hierarchy at tenant scope.                                                |
| `terraform-mg-apply.yml` | Manual `workflow_dispatch`                                   | Creates a saved MG plan, then applies that artifact after `apply-mg` approval.                           |
| `bicep-mg-plan.yml`      | PR to `main` touching `infra/bicep/management-groups/**`     | `bicep build` + `az deployment tenant what-if`.                                                          |
| `bicep-mg-apply.yml`     | Manual `workflow_dispatch`                                   | Runs tenant what-if, then deploys after `apply-mg` approval.                                             |

---

## Step 1 — Bootstrap state (Terraform only)

Bicep stores deployment history in Azure automatically; Terraform needs a remote backend. Skip this step if you're only using Bicep.

```bash
# From the repo root, against the target subscription:
az login
az account set --subscription <subscription-id>
./scripts/bootstrap-state.sh
```

This creates `rg-tfstate-<prefix>-<region>`, a Storage Account, a `tfstate` container, and `.launchpad/backend.hcl`. It grants the signed-in operator `Storage Blob Data Contributor`. Set `TFSTATE_EXTRA_PRINCIPAL_ID` to the OIDC service principal object ID to grant CI data-plane access during the same bootstrap.

---

## Step 2 — Create the OIDC identity in Entra

No client secrets — GitHub Actions exchanges a workflow-issued OIDC token for an Azure access token. Run this **once per repo**:

```bash
APP_NAME="azure-launchpad-gha"
SUB_ID=<subscription-id>
TENANT_ID=<tenant-id>
REPO=<owner>/azure-launchpad          # e.g. travishankins/azure-launchpad

# 2a. Create app registration + service principal
APP_ID=$(az ad app create --display-name $APP_NAME --query appId -o tsv)
az ad sp create --id $APP_ID

# 2b. Grant Contributor on the subscription (required for foundation deploy)
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/$SUB_ID

# Grant the OIDC principal access to Terraform state. The bootstrap is
# idempotent, so re-running it after the service principal exists is safe.
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query id -o tsv)
TFSTATE_EXTRA_PRINCIPAL_ID=$SP_OBJECT_ID ./scripts/bootstrap-state.sh

# 2c. (Optional) If you'll deploy the management-groups module,
#     grant Management Group Contributor at Tenant Root:
TENANT_ROOT_MG=/providers/Microsoft.Management/managementGroups/$TENANT_ID
az role assignment create \
  --assignee $APP_ID \
  --role "Management Group Contributor" \
  --scope $TENANT_ROOT_MG
```

---

## Step 3 — Add federated credentials

Add one credential per GitHub trigger you want to use. The plan workflows run on pull requests; the apply workflows run inside protected GitHub environments.

```bash
# 3a. Foundation plan environment (unprotected)
az ad app federated-credential create --id $APP_ID --parameters '{
  "name":"gha-plan",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:'$REPO':environment:plan",
  "audiences":["api://AzureADTokenExchange"]
}'

# 3b. Management Group plan environment (unprotected)
az ad app federated-credential create --id $APP_ID --parameters '{
  "name":"gha-plan-mg",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:'$REPO':environment:plan-mg",
  "audiences":["api://AzureADTokenExchange"]
}'

# 3c. Foundation apply — Terraform uses environment "prod"
az ad app federated-credential create --id $APP_ID --parameters '{
  "name":"gha-prod",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:'$REPO':environment:prod",
  "audiences":["api://AzureADTokenExchange"]
}'

# 3d. Foundation apply — Bicep uses environment "apply"
az ad app federated-credential create --id $APP_ID --parameters '{
  "name":"gha-apply",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:'$REPO':environment:apply",
  "audiences":["api://AzureADTokenExchange"]
}'

# 3e. Management Groups apply (TF + Bicep) — environment "apply-mg"
az ad app federated-credential create --id $APP_ID --parameters '{
  "name":"gha-apply-mg",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:'$REPO':environment:apply-mg",
  "audiences":["api://AzureADTokenExchange"]
}'
```

---

## Step 4 — Configure repo variables

**Settings → Secrets and variables → Actions → Variables** (these are non-sensitive identifiers, so use **Variables**, not **Secrets**):

| Variable                 | Value                                             | Required for                            |
| ------------------------ | ------------------------------------------------- | --------------------------------------- |
| `AZURE_CLIENT_ID`        | `$APP_ID` from step 2a                            | All workflows                           |
| `AZURE_MG_CLIENT_ID`     | `$APP_ID` or a separate tenant-scope identity     | Management Group workflows              |
| `AZURE_TENANT_ID`        | Your Entra tenant ID                              | All workflows                           |
| `AZURE_SUBSCRIPTION_ID`  | Target subscription                               | All workflows                           |
| `AZURE_DEFAULT_LOCATION` | e.g. `westcentralus`                              | Bicep (subscription-scoped deployments) |
| `TFSTATE_RG`             | From `bootstrap-state.sh` output                  | Terraform foundation                    |
| `TFSTATE_SA`             | From `bootstrap-state.sh` output                  | Terraform foundation                    |
| `TFSTATE_CONTAINER`      | `tfstate`                                         | Terraform foundation                    |

---

## Step 5 — Create protected environments

**Settings → Environments → New environment**, create these and enable **Required reviewers** on each:

| Environment | Protection | Used by |
| ----------- | ---------- | ------- |
| `plan` | No reviewers | Foundation preview jobs |
| `plan-mg` | No reviewers | Management Group preview jobs |
| `prod` | Required reviewers | Terraform foundation apply |
| `apply` | Required reviewers | Bicep foundation apply |
| `apply-mg` | Required reviewers | Terraform/Bicep Management Group apply |

This lets previews run first and forces a human approval before any apply. Terraform apply jobs download and apply the exact plan artifact produced earlier in the same workflow run.

---

## Step 6 — Deploy

### Foundation (Terraform)

1. In a private deployment repo, copy the reviewed generator values into the matching `baseline.tfvars`, `firewall.tfvars`, `vpn.tfvars`, or `full.tfvars`, then open a PR.
2. `terraform-plan.yml` runs automatically; review the plan artifact attached to the PR check.
3. Merge the PR.
4. **Actions → terraform-apply → Run workflow**, pick the scenario, click **Run**.
5. A reviewer approves the `prod` environment gate.
6. The dispatch workflow creates a fresh saved plan. After approval, the apply job downloads and applies that exact plan. ~10–25 min depending on scenario.

### Foundation (Bicep)

1. In a private deployment repo, copy the reviewed generator values into the matching `baseline.bicepparam`, `firewall.bicepparam`, `vpn.bicepparam`, or `full.bicepparam`, then open a PR.
2. `bicep-plan.yml` runs `what-if` and posts the diff as a PR comment.
3. Merge the PR.
4. **Actions → bicep-apply → Run workflow**, pick the scenario, click **Run**.
5. A reviewer approves the `apply` environment gate.
6. The job runs `az deployment sub create`. ~10–25 min depending on scenario.

Generator files are intentionally ignored because they contain internal identifiers. The stock workflows deploy the four named scenario files, so transfer only the reviewed values into the matching file in a private deployment repository before committing it.

> **Multi-subscription:** the stock Actions workflows are single-subscription. Run the generator's Terraform or Bicep multi-sub commands locally, in Codespaces, or in Cloud Shell until dedicated multi-sub workflows are added.

### Management Groups (either IaC)

> **Heads up** — runs at **tenant root**, not in your subscription. The OIDC principal needs `Management Group Contributor` on the Tenant Root Group (step 2c).

1. Open a PR touching `infra/terraform/management-groups/**` or `infra/bicep/management-groups/**`.
2. The matching `*-mg-plan` workflow runs.
3. Merge the PR.
4. **Actions → terraform-mg-apply** (or **bicep-mg-apply**) **→ Run workflow** → **Run**.
5. A reviewer approves the `apply-mg` environment gate.
6. The job creates / updates the management-group hierarchy and any opt-in policy assignments.

---

## Local pre-commit equivalence

The plan workflows just wrap commands you can also run locally.

**Terraform**:

```bash
cd infra/terraform/foundation
terraform fmt -recursive -check
terraform init -backend=false
terraform validate
terraform test
tfsec .
```

**Bicep**:

```bash
cd infra/bicep/foundation
az bicep build --file main.bicep
az deployment sub what-if \
  --location westcentralus \
  --parameters scenarios/baseline.bicepparam
```
