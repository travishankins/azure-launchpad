###############################################################################
# Optional: Subscription budget + email/webhook alerts.
#
# Disabled by default. Enable by setting `var.budget_enabled = true` and
# providing at least one entry in `var.budget_alert_emails`.
#
# Creates:
# - 1 subscription-scoped consumption budget (monthly) at var.budget_amount
# - Notifications at 50% / 80% / 100% (default) of either Actual or Forecasted
#   spend, sent to all addresses in var.budget_alert_emails
#
# Cost impact: $0 — Cost Management is free.
###############################################################################

resource "azurerm_consumption_budget_subscription" "this" {
  count           = var.budget_enabled ? 1 : 0
  name            = "budget-${local.suffix}"
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    # First of the current month, in UTC. Required by the API.
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", timestamp())
  }

  dynamic "filter" {
    # Optional: scope the budget to a subset of resource groups (by name).
    # Empty list => budget covers the whole subscription.
    for_each = length(var.budget_resource_group_names) > 0 ? [1] : []
    content {
      dimension {
        name   = "ResourceGroupName"
        values = var.budget_resource_group_names
      }
    }
  }

  dynamic "notification" {
    for_each = var.budget_thresholds
    content {
      enabled        = true
      threshold      = notification.value
      threshold_type = "Actual"
      operator       = "GreaterThan"
      contact_emails = var.budget_alert_emails
    }
  }

  # Forecasted overrun gives the team lead time to react before real spend
  # blows the budget. Single threshold at 100% of forecast.
  notification {
    enabled        = true
    threshold      = 100
    threshold_type = "Forecasted"
    operator       = "GreaterThan"
    contact_emails = var.budget_alert_emails
  }

  lifecycle {
    # `start_date` regenerates on every plan because of `timestamp()`. Ignore
    # it after creation — the API only validates start_date on create.
    ignore_changes = [time_period]
  }
}
