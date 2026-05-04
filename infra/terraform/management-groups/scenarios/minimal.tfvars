# Minimal SMB hierarchy: root → platform/{management,connectivity} +
# landingzones/{corp,online,local} + decommissioned + sandboxes.
# No Identity/Security MGs. No policy assignments.

# subscription_id and tenant_id must be supplied via -var or env (TF_VAR_*).

name_prefix         = "contoso"
display_name_prefix = "Contoso"

enable_identity_mg       = false
enable_security_mg       = false
enable_local_mg          = true
enable_decommissioned_mg = true
enable_sandboxes_mg      = true

enable_policies = false
