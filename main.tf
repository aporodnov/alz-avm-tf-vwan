# ─────────────────────────────────────────────────────────────
# Resource Group
# ─────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "networking" {
  name     = var.networking_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "dns" {
  count    = var.dns_resource_group_name != null ? 1 : 0
  name     = var.dns_resource_group_name
  location = var.location
  tags     = var.tags
}

# ─────────────────────────────────────────────────────────────
# Virtual WAN  (AVM pattern module)
#
# The module deploys vWAN + hubs + gateways + routing intent
# in a single call — no separate bootstrap step needed.
# ─────────────────────────────────────────────────────────────

module "vwan" {
  source  = "Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm"
  version = "0.14.0"

  virtual_wan_settings = {
    enabled_resources = {
      ddos_protection_plan = var.enable_ddos_protection_plan
    }

    virtual_wan = {
      name                           = var.virtual_wan_name
      location                       = var.location
      resource_group_name            = azurerm_resource_group.networking.name
      type                           = var.virtual_wan_type
      allow_branch_to_branch_traffic = var.allow_branch_to_branch_traffic
      tags                           = var.tags
    }

    ddos_protection_plan = {
      name                = "ddos-plan-${var.virtual_wan_name}"
      location            = var.location
      resource_group_name = azurerm_resource_group.networking.name
      tags                = var.tags
    }
  }

  # Inject the resource-group ID and enforce security defaults:
  #  • internet_security_enabled  = false  on the sidecar VNet connection
  #  • default_outbound_access_enabled = false  on every sidecar subnet
  virtual_hubs = {
    for key, hub in var.virtual_hubs : key => merge(hub,
      { default_parent_id = azurerm_resource_group.networking.id },
      try(hub.sidecar_virtual_network, null) != null ? {
        sidecar_virtual_network = merge(hub.sidecar_virtual_network, {
          virtual_network_connection_settings = merge(
            try(hub.sidecar_virtual_network.virtual_network_connection_settings, {}),
            { internet_security_enabled = false }
          )
          subnets = {
            for sk, sv in try(hub.sidecar_virtual_network.subnets, {}) : sk => merge(sv, {
              default_outbound_access_enabled = false
            })
          }
        })
      } : {},
      try(hub.private_dns_zones, null) != null && var.dns_resource_group_name != null ? {
        private_dns_zones = merge(hub.private_dns_zones, {
          parent_id = azurerm_resource_group.dns[0].id
        })
      } : {},
      try(hub.private_dns_resolver, null) != null && var.dns_resource_group_name != null ? {
        private_dns_resolver = merge(hub.private_dns_resolver, {
          resource_group_name = azurerm_resource_group.dns[0].name
        })
      } : {}
    )
  }

  tags             = var.tags
  enable_telemetry = var.enable_telemetry
}
