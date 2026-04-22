# ─────────────────────────────────────────────────────────────
# Cloud profile — cloud-only (no on-prem connectivity)
# ─────────────────────────────────────────────────────────────

resource_group_name = "AVNM-RG"
location            = "canadacentral"

tags = {
  Environment  = "Prod"
  SolutionName = "Cloud Vwan"
}

virtual_wan_name               = "vwan01"
virtual_wan_type               = "Standard"
allow_branch_to_branch_traffic = true

enable_ddos_protection_plan = false
virtual_hubs = {

  # ── Canada Central hub (minimal) ──────────────────────────
  "cc-hub" = {
    location = "canadacentral"

    # Toggle which sub-resources get created in this hub.
    enabled_resources = {
      firewall                              = false
      firewall_policy                       = false
      bastion                               = false
      virtual_network_gateway_express_route = false
      virtual_network_gateway_vpn           = false
      private_dns_zones                     = false
      private_dns_resolver                  = false
      sidecar_virtual_network               = true
    }

    hub = {
      name                                   = "vHUB-CC-Cloud"
      address_prefix                         = "10.58.128.0/21"
      hub_routing_preference                 = "ExpressRoute"
      virtual_router_auto_scale_min_capacity = 2
    }

    # ── Sidecar Virtual Network ─────────────────────────────
    # A /24 VNet peered to the hub for Azure Bastion and
    # Private DNS Resolver (inbound + outbound endpoints).
    sidecar_virtual_network = {
      name          = "vnet-sidecar-cc-cloud"
      address_space = ["10.58.136.0/24"]

      virtual_network_connection_settings = {
        name                      = "vnet-conn-sidecar-cc-cloud"
        internet_security_enabled = false
      }

      subnets = {
        # Azure Bastion requires /26 minimum and the exact name
        # "AzureBastionSubnet".
        "bastion" = {
          name                            = "AzureBastionSubnet"
          address_prefixes                = ["10.58.136.0/26"]
          default_outbound_access_enabled = false
        }

        # Private DNS Resolver inbound endpoint — /28 minimum,
        # delegation to Microsoft.Network/dnsResolvers required.
        "dns-resolver-inbound" = {
          name                            = "snet-dns-resolver-inbound"
          address_prefixes                = ["10.58.136.64/28"]
          default_outbound_access_enabled = false
          delegations = [{
            name = "Microsoft.Network.dnsResolvers"
            service_delegation = {
              name    = "Microsoft.Network/dnsResolvers"
              actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
            }
          }]
        }

        # Private DNS Resolver outbound endpoint — /28 minimum,
        # delegation to Microsoft.Network/dnsResolvers required.
        "dns-resolver-outbound" = {
          name                            = "snet-dns-resolver-outbound"
          address_prefixes                = ["10.58.136.80/28"]
          default_outbound_access_enabled = false
          delegations = [{
            name = "Microsoft.Network.dnsResolvers"
            service_delegation = {
              name    = "Microsoft.Network/dnsResolvers"
              actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
            }
          }]
        }
      }
    }
  }
}
