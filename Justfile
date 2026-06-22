# Azure Launchpad — common task aliases.
# Install just: brew install just  |  cargo install just  |  see just.systems
# List recipes:  just --list

set shell := ["bash", "-uc"]

tf_dir := "infra/terraform/foundation"
bicep_main := "infra/bicep/foundation/main.bicep"
sub := env_var_or_default("ARM_SUBSCRIPTION_ID", "")

# Show all recipes.
default:
    @just --list

# --------------------------------------------------------------------------- #
# Terraform
# --------------------------------------------------------------------------- #

# Format every Terraform file in the repo.
fmt:
    terraform -chdir={{tf_dir}} fmt -recursive ../..

# Validate the foundation module (no backend init required).
validate:
    cd {{tf_dir}} && terraform init -backend=false -upgrade && terraform validate

# Run all native Terraform tests (plan-mode, no Azure required).
test:
    cd {{tf_dir}} && terraform test

# Lint Terraform with tflint.
tflint:
    cd {{tf_dir}} && tflint --init && tflint --recursive

# Plan a scenario (baseline | firewall | vpn | full). Requires Azure auth + bootstrapped state.
plan scenario:
    ./scripts/deploy.sh plan --iac terraform --mode single --scenario {{scenario}} \
        --subscription {{sub}} --config {{tf_dir}}/scenarios/{{scenario}}.tfvars

# Apply a scenario.
apply scenario plan_file:
    ./scripts/deploy.sh apply --iac terraform --mode single --scenario {{scenario}} \
        --subscription {{sub}} --config {{tf_dir}}/scenarios/{{scenario}}.tfvars \
        --plan-file {{plan_file}}

# Destroy a scenario.
destroy scenario:
    cd {{tf_dir}} && terraform workspace select {{scenario}} && \
        terraform destroy -var-file=scenarios/{{scenario}}.tfvars -var "subscription_id={{sub}}"

# --------------------------------------------------------------------------- #
# Bicep
# --------------------------------------------------------------------------- #

# Build all Bicep templates (catches lint + compile errors).
bicep-build:
    az bicep build --file {{bicep_main}}
    for s in baseline firewall vpn full; do \
      az bicep build-params --file infra/bicep/foundation/scenarios/$s.bicepparam ; \
    done

# What-if a Bicep scenario against the current subscription.
bicep-whatif scenario region="westcentralus":
    ./scripts/deploy.sh plan --iac bicep --mode single --scenario {{scenario}} \
      --subscription {{sub}} --region {{region}} \
      --config infra/bicep/foundation/scenarios/{{scenario}}.bicepparam

# Deploy a Bicep scenario.
bicep-deploy scenario region="westcentralus":
    ./scripts/deploy.sh apply --iac bicep --mode single --scenario {{scenario}} \
      --subscription {{sub}} --region {{region}} \
      --config infra/bicep/foundation/scenarios/{{scenario}}.bicepparam

# --------------------------------------------------------------------------- #
# Docs site
# --------------------------------------------------------------------------- #

# Run the docs site locally (http://localhost:4321/azure-launchpad/).
docs:
    cd site && npm run dev

# Build the docs site (CI parity).
docs-build:
    cd site && npm install && npm run build

# Run configuration generator (wizard) unit tests.
wizard-test:
    node --test site/public/scripts/wizard.test.js

# --------------------------------------------------------------------------- #
# Quality gates
# --------------------------------------------------------------------------- #

# Run every pre-commit hook against every file.
pre-commit:
    pre-commit run --all-files

# Run the same checks CI does, locally.
ci: fmt validate test bicep-build wizard-test docs-build
    @echo "All local CI checks passed."
