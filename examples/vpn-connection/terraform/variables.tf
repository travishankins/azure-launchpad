variable "subscription_id" {
  description = "Azure subscription ID where the foundation VPN Gateway lives."
  type        = string
}

variable "vpn_gateway_id" {
  description = "Resource ID of the foundation VPN Gateway (output `vpn_gateway_id`)."
  type        = string
}

variable "connection_name" {
  description = "Short name used to derive the LNG and connection resource names (e.g. `hq` -> lng-hq, cn-hq)."
  type        = string
  default     = "onprem"
}

variable "peer_ip" {
  description = "Public IP address of the on-premises VPN device."
  type        = string
}

variable "peer_address_spaces" {
  description = "On-premises CIDR blocks reachable through the tunnel."
  type        = list(string)
}

variable "shared_key" {
  description = "Pre-shared key for the IPsec tunnel. Pull from Key Vault, do not commit."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to the LNG and connection."
  type        = map(string)
  default     = {}
}
