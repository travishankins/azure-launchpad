terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }

  # Partial backend — supply the rest via -backend-config / backend.hcl.
  # Use a DIFFERENT key than foundation since this is tenant-scoped.
  # Example: -backend-config="key=management-groups.tfstate"
  backend "azurerm" {
    use_azuread_auth = true
  }
}
