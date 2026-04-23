# ─────────────────────────────────────────────────────────────
# Hybrid profile — ExpressRoute gateway + optional routing intent
# ─────────────────────────────────────────────────────────────

resource_group_name = "AVNM-RG"
location            = "canadacentral"

tags = {
  Environment  = "Prod"
  SolutionName = "Hybrid Vwan"
}

virtual_wan_name               = "vwan01"
virtual_wan_type               = "Standard"
allow_branch_to_branch_traffic = true

enable_ddos_protection_plan = false

virtual_hubs = {

  # ── Canada Central hub ────────────────────────────────────
  "cc-hub" = {
    location = "canadacentral"

    enabled_resources = {
      firewall                              = false
      firewall_policy                       = false
      bastion                               = true
      virtual_network_gateway_express_route = true
      virtual_network_gateway_vpn           = false
      private_dns_zones                     = false
      private_dns_resolver                  = true
      sidecar_virtual_network               = true
    }

    # Hub properties
    hub = {
      name                                   = "vHUB-CC-Hybrid-Fortinet"
      address_prefix                         = "10.58.128.0/21"
      hub_routing_preference                 = "ExpressRoute"
      virtual_router_auto_scale_min_capacity = 3 # router scale units
    }

    # ExpressRoute gateway
    virtual_network_gateways = {
      express_route = {
        name                          = "vHUB-CC-Hybrid-Fortinet-ERGW"
        allow_non_virtual_wan_traffic = true
        scale_units                   = 1
      }
    }

    # ── ExpressRoute circuit connections ────────────────────
    # Uncomment and supply your circuit peering ID + auth key.
    #
    # express_route_circuit_connections = {
    #   "er-connection-01" = {
    #     name                             = "er-connection-toVHUBFortinet"
    #     express_route_circuit_peering_id = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/expressRouteCircuits/<circuit>/peerings/AzurePrivatePeering"
    #     authorization_key                = ""  # inject via TF_VAR_ or a Key Vault data source
    #   }
    # }

    # ── Routing intent (Azure Firewall as next hop) ─────────
    # To enable: set firewall + firewall_policy = true above,
    # then uncomment the block below.
    #
    # routing_intents = {
    #   "default" = {
    #     name = "RoutingIntent"
    #     routing_policies = [
    #       {
    #         name                  = "PrivateTrafficPolicy"
    #         destinations          = ["PrivateTraffic"]
    #         next_hop_firewall_key = "cc-hub"
    #       },
    #       {
    #         name                  = "InternetTrafficPolicy"
    #         destinations          = ["Internet"]
    #         next_hop_firewall_key = "cc-hub"
    #       }
    #     ]
    #   }
    # }

    bastion = {
      name                  = "bas-cc-hybrid"
      subnet_address_prefix = "10.58.136.0/26"
      sku                   = "Standard"
      copy_paste_enabled    = true
      file_copy_enabled     = true
      ip_connect_enabled    = true
      tunneling_enabled     = true
      scale_units           = 2

      bastion_public_ip = {
        name = "pip-bas-cc-hybrid"
      }
    }

    private_dns_resolver = {
      name                            = "dnspr-cc-hybrid"
      subnet_name                     = "snet-dns-resolver-inbound"
      subnet_address_prefix           = "10.58.136.64/28"
      default_inbound_endpoint_enabled = false
      inbound_endpoints = {
        "default" = {
          name        = "ie-cc-hybrid"
          subnet_name = "snet-dns-resolver-inbound"
        }
      }
      outbound_endpoints = {
        "default" = {
          subnet_name = "snet-dns-resolver-outbound"
          forwarding_ruleset = {
            "default" = {
              name = "frs-cc-hybrid"
              rules = {
                "onprem-contoso" = {
                  domain_name              = "contoso.local."
                  destination_ip_addresses = {
                    "10.0.0.53" = "53"
                  }
                }
              }
            }
          }
        }
      }
    }

    sidecar_virtual_network = {
      name          = "vnet-sidecar-cc-hybrid"
      address_space = ["10.58.136.0/24"]

      virtual_network_connection_settings = {
        name = "vnet-conn-sidecar-cc-hybrid"
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
  }
}
