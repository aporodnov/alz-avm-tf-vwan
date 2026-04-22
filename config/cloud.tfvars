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

  "cc-hub" = {
    location = "canadacentral"

    enabled_resources = {
      firewall                              = false
      firewall_policy                       = false
      bastion                               = true
      virtual_network_gateway_express_route = false
      virtual_network_gateway_vpn           = false
      private_dns_zones                     = false
      private_dns_resolver                  = true
      sidecar_virtual_network               = true
    }

    hub = {
      name                                   = "vHUB-CC-Cloud"
      address_prefix                         = "10.58.128.0/21"
      hub_routing_preference                 = "ExpressRoute"
      virtual_router_auto_scale_min_capacity = 2
    }
    sidecar_virtual_network = {
      name          = "vnet-sidecar-cc-cloud"
      address_space = ["10.58.136.0/24"]

      virtual_network_connection_settings = {
        name = "vnet-conn-sidecar-cc-cloud"
      }

      subnets = {
        "dns-resolver-outbound" = {
          name             = "snet-dns-resolver-outbound"
          address_prefixes = ["10.58.136.80/28"]
          delegations = [{
            name = "Microsoft.Network.dnsResolvers"
            service_delegation = {
              name = "Microsoft.Network/dnsResolvers"
            }
          }]
        }
      }
    }

    bastion = {
      name                  = "bas-cc-cloud"
      subnet_address_prefix = "10.58.136.0/26"
      sku                   = "Standard"
      copy_paste_enabled    = true
      file_copy_enabled     = true
      ip_connect_enabled    = true
      tunneling_enabled     = true
      scale_units           = 2
    }

    private_dns_resolver = {
      name                  = "dnspr-cc-cloud"
      subnet_name           = "snet-dns-resolver-inbound"
      subnet_address_prefix = "10.58.136.64/28"
      outbound_endpoints = {
        "default" = {
          subnet_name = "snet-dns-resolver-outbound"
        }
      }
    }
  }
}
