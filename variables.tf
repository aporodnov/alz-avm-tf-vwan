variable "networking_resource_group_name" {
  type        = string
  description = "Name of the resource group for networking resources (vWAN, hubs, sidecar VNet, Bastion)."
}

variable "location" {
  type        = string
  default     = "canadacentral"
  description = "Azure region for the vWAN and default hub location."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources."
}

# ── Virtual WAN settings ─────────────────────────────────────

variable "virtual_wan_name" {
  type        = string
  description = "Name of the Virtual WAN resource."
}

variable "virtual_wan_type" {
  type        = string
  default     = "Standard"
  description = "Virtual WAN type — Standard or Basic."
}

variable "allow_branch_to_branch_traffic" {
  type        = bool
  default     = true
  description = "Allow branch-to-branch traffic through the vWAN."
}

# ── Virtual Hubs ──────────────────────────────────────────────

variable "virtual_hubs" {
  type        = any
  default     = {}
  description = "Map of virtual hubs to create. See config/*.tfvars for examples."
}

# ── Private DNS Zones ─────────────────────────────────────────

variable "dns_resource_group_name" {
  type        = string
  default     = null
  description = "Name of a dedicated resource group for DNS resources (Private DNS Zones, DNS Resolver, forwarding rulesets). Created automatically when set."
}

# ── DDoS Protection ───────────────────────────────────────────

variable "enable_ddos_protection_plan" {
  type        = bool
  default     = false
  description = "Deploy an Azure DDoS Protection Plan and associate it with hub virtual networks."
}

# ── Telemetry ─────────────────────────────────────────────────

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = "Enable Azure Verified Modules telemetry collection."
}
