---
title: CI/CD pipeline
description: GitHub Actions workflows for plan and apply (Terraform + Bicep, foundation + management groups), using OIDC.
---

This repo ships **8 GitHub Actions workflows** under `.github/workflows/` — a plan + apply pair for each of the four root modules (Terraform foundation, Bicep foundation, Terraform management groups, Bicep management groups).

| Workflow                 | Trigger                                                      | Purpose                                                                                                  |
| ------------------------ | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| `terraform-plan.yml`     | PR to `main` touching `infra/terraform/foundation/**`        | `fmt -check`, `validate`, `tfsec`, matrix-`plan` over all 4 scenarios, uploads each plan as an artifact. |
| `terraform-apply.yml`    | Manual `workflow_dispatch` (pick scenario)                   | `init`, select workspace, `apply -auto-approve`. Gated by the `prod` environment.                        |
| `bicep-plan.yml`         | PR to `main` touching `infra/bicep/foundation/**`            | `bicep build`, `az deployment sub what-if` for the chosen scenario, posts results as a PR comment.       |
| `bicep-apply.yml`        | Manual `workflow_dispatch`                                   | `az deployment sub create` for the chosen scenario. Gated by the `apply` environment.                    |
| `terraform-mg-plan.yml`  | PR to `main` touching `infra/terraform/management-groups/**` | `validate` + `plan` for the MG hierarchy at tenant scope.                                                |
| `terraform-mg-apply.yml` | Manual `workflow_dispatch`                                   | `apply` for the MG hierarchy. Gated by the `apply-mg` environment.                                       |
| `bicep-mg-plan.yml`      | PR to `main` touching `infra/bicep/management-groups/**`     | `bicep build` + `az deployment tenant what-if`.                                                          |
| `bicep-mg-apply.yml`     | Manual `workflow_dispatch`                                   | `az deployment tenant create`. Gated by the `apply-mg` environment.                                      |

---

## Step 1 — Bootstrap state (Terraform only)

Bicep stores deployment history in Azure automatically; Terraform needs a remote backend. Skip this step if you're only using Bicep.

```bash
# From the repo root, against the target subscription:
az login
az account set --subscription <subscription-id>
./scripts/bootstrap-state.sh
```

This creates `rg-tfstate-<prefix>-<region>` containing a Storage Account and a `tfstate` container, then prints the values you need for the repo variables in step 4. Run it **once per customer subscription**.

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
# 3a. Plan (pull requests) — used by all *-plan workflows
az ad app federated-credential create --id $APP_ID --parameters '{
  "name":"gha-pr",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:'$REPO':pull_request",
  "audiences":["api://AzureADTokenExchange"]
}'

# 3b. Foundation apply — Terraform uses environment "prod"
az ad app federated-credential create --id $APP_ID --parameters '{
  "name":"gha-prod",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:'$REPO':environment:prod",
  "audiences":["api://AzureADTokenExchange"]
}'

# 3c. Foundation apply — Bicep uses environment "apply"
az ad app federated-credential create --id $APP_ID --parameters '{
  "name":"gha-apply",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:'$REPO':environment:apply",
  "audiences":["api://AzureADTokenExchange"]
}'

# 3d. Management Groups apply (TF + Bicep) — environment "apply-mg"
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
| `AZURE_TENANT_ID`        | Your Entra tenant ID                              | All workflows                           |
| `AZURE_SUBSCRIPTION_ID`  | Target subscription                               | All workflows                           |
| `AZURE_DEFAULT_LOCATION` | e.g. `westcentralus`                              | Bicep (subscription-scoped deployments) |
| `TFSTATE_RG`             | From `bootstrap-state.sh` output                  | Terraform foundation                    |
| `TFSTATE_SA`             | From `bootstrap-state.sh` output                  | Terraform foundation                    |
| `TFSTATE_CONTAINER`      | `tfstate`                                         | Terraform foundation                    |
| `TFSTATE_MG_RG`          | From a separate `bootstrap-state.sh` run, if used | Terraform management groups (optional)  |
| `TFSTATE_MG_SA`          | "                                                 | Terraform management groups (optional)  |
| `TFSTATE_MG_CONTAINER`   | `tfstate-mg`                                      | Terraform management groups (optional)  |

---

## Step 5 — Create protected environments

**Settings → Environments → New environment**, create these and enable **Required reviewers** on each:

| Environment | Used by                                        |
| ----------- | ---------------------------------------------- |
| `prod`      | `terraform-apply.yml`                          |
| `apply`     | `bicep-apply.yml`                              |
| `apply-mg`  | `terraform-mg-apply.yml`, `bicep-mg-apply.yml` |

This forces a human approval click before any apply runs against your subscription or tenant.

---

## Step 6 — Deploy

### Foundation (Terraform)

1. Open a PR that adds or edits a tfvars under `infra/terraform/foundation/scenarios/` (or run the [wizard](/wizard/) and commit its output).
2. `terraform-plan.yml` runs automatically; review the plan artifact attached to the PR check.
3. Merge the PR.
4. **Actions → terraform-apply → Run workflow**, pick the scenario, click **Run**.
5. A reviewer approves the `prod` environment gate.
6. The job runs `terraform apply`. ~10–25 min depending on scenario.

### Foundation (Bicep)

1. Open a PR that adds or edits a `.bicepparam` under `infra/bicep/foundation/scenarios/`.
2. `bicep-plan.yml` runs `what-if` and posts the diff as a PR comment.
3. Merge the PR.
4. **Actions → bicep-apply → Run workflow**, pick the scenario, click **Run**.
5. A reviewer approves the `apply` environment gate.
6. The job runs `az deployment sub create`. ~10–25 min depending on scenario.

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
