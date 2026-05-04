locals {
  # Tenant root group ID (parent of our top-level intermediate MG).
  tenant_root_id = "/providers/Microsoft.Management/managementGroups/${var.tenant_id}"

  # ---- Hierarchy definition ---------------------------------------------
  # Static MGs (always created)
  mg_static = {
    root = {
      display = "${var.display_name_prefix}"
      parent  = local.tenant_root_id
    }
    platform = {
      display = "Platform"
      parent  = "/providers/Microsoft.Management/managementGroups/${var.name_prefix}"
    }
    management = {
      display = "Management"
      parent  = "/providers/Microsoft.Management/managementGroups/${var.name_prefix}-platform"
    }
    connectivity = {
      display = "Connectivity"
      parent  = "/providers/Microsoft.Management/managementGroups/${var.name_prefix}-platform"
    }
    landingzones = {
      display = "Landing zones"
      parent  = "/providers/Microsoft.Management/managementGroups/${var.name_prefix}"
    }
    corp = {
      display = "Corp"
      parent  = "/providers/Microsoft.Management/managementGroups/${var.name_prefix}-landingzones"
    }
    online = {
      display = "Online"
      parent  = "/providers/Microsoft.Management/managementGroups/${var.name_prefix}-landingzones"
    }
  }

  mg_optional = merge(
    var.enable_identity_mg ? {
      identity = {
        display = "Identity"
        parent  = "/providers/Microsoft.Management/managementGroups/${var.name_prefix}-platform"
      }
    } : {},
    var.enable_security_mg ? {
      security = {
        display = "Security"
        parent  = "/providers/Microsoft.Management/managementGroups/${var.name_prefix}-platform"
      }
    } : {},
    var.enable_local_mg ? {
      local = {
        display = "Local"
        parent  = "/providers/Microsoft.Management/managementGroups/${var.name_prefix}-landingzones"
      }
    } : {},
    var.enable_decommissioned_mg ? {
      decommissioned = {
        display = "Decommissioned"
        parent  = "/providers/Microsoft.Management/managementGroups/${var.name_prefix}"
      }
    } : {},
    var.enable_sandboxes_mg ? {
      sandboxes = {
        display = "Sandboxes"
        parent  = "/providers/Microsoft.Management/managementGroups/${var.name_prefix}"
      }
    } : {},
  )

  mgs = merge(local.mg_static, local.mg_optional)

  # Map MG key => the technical name used for the resource (and as the URI segment)
  mg_names = { for k, _ in local.mgs : k => (k == "root" ? var.name_prefix : "${var.name_prefix}-${k}") }

  # Subscription placements grouped by MG key for for_each on the association resource.
  # Resource for_each key is "<sub_id>:<mg_key>" so customers can move subs between MGs.
  sub_placements = {
    for sub_id, mg_key in var.subscription_placements :
    "${sub_id}:${mg_key}" => {
      subscription_id = sub_id
      mg_key          = mg_key
    }
  }
}
