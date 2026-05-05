---
title: Quick start (Terraform)
description: Deploy the baseline scenario with Terraform in under an hour.
---

If you just want to see something work, follow these five steps. Prefer Microsoft's native IaC? See [Quick start (Bicep)](/getting-started/quick-start-bicep/) for the equivalent flow.

## 1. Bootstrap the state backend

```bash
git clone https://github.com/travishankins/azure-launchpad.git
cd azure-launchpad
az login
export ARM_SUBSCRIPTION_ID=<subscription-id>
./scripts/bootstrap-state.sh
```

Copy the `storage_account_name` printed at the end.

## 2. Initialize Terraform

```bash
cd infra/terraform/foundation
terraform init \
  -backend-config="resource_group_name=rg-tfstate-contoso-wcus" \
  -backend-config="storage_account_name=<from step 1>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=foundation.baseline.tfstate"
```

## 3. Pick a scenario (workspace)

```bash
terraform workspace select -or-create baseline
```

## 4. Plan

```bash
terraform plan \
  -var "subscription_id=$ARM_SUBSCRIPTION_ID" \
  -var-file=scenarios/baseline.tfvars \
  -out=tfplan
```

Review the plan output carefully.

## 5. Apply

```bash
terraform apply tfplan
```

That's it. To switch scenarios:

```bash
terraform workspace select -or-create firewall
terraform apply -var "subscription_id=$ARM_SUBSCRIPTION_ID" -var-file=scenarios/firewall.tfvars
```

> **Tip** — use the [deployment wizard](/wizard/) to generate a `wizard.auto.tfvars` file tailored to your customer's needs.
