###############################################################################
# Azure Monitor Workbook — Foundation Health (opt-in)
# A starter workbook over the Log Analytics workspace with tabs for ingestion,
# firewall denies, Key Vault ops, and backup job status.
###############################################################################

resource "azurerm_application_insights_workbook" "foundation_health" {
  count    = var.workbook_enabled ? 1 : 0
  provider = azurerm.management

  # Workbook resource names must be GUIDs. Deterministic per-suffix so re-deploys
  # don't churn the resource ID.
  name                = uuidv5("dns", "azure-launchpad-workbook-${local.suffix}")
  resource_group_name = local.rg["monitor"].name
  location            = var.location

  display_name = "Azure Launchpad — Foundation Health"
  description  = "Starter workbook over the foundation Log Analytics workspace. Edit freely."
  category     = "workbook"

  # Pin the workbook to the foundation LAW so it opens scoped to that workspace.
  source_id = lower(module.log_analytics.resource_id)

  data_json = file("${path.module}/workbooks/foundation-health.workbook.json")

  tags = local.tags
}
