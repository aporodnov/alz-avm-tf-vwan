# ─────────────────────────────────────────────────────────────
# Lab profile
# ─────────────────────────────────────────────────────────────

networking_resource_group_name = "VWAN-RG"
dns_resource_group_name = "DNS-RG"

location            = "canadacentral"

tags = {
  Environment  = "Lab"
  SolutionName = "Connectivity"
}

virtual_wan_name               = "vwan01"
virtual_wan_type               = "Standard"
allow_branch_to_branch_traffic = true

enable_ddos_protection_plan = false
enable_telemetry            = false

virtual_hubs = {

  "cc-hub01" = {
    location = "canadacentral"

    enabled_resources = {
      firewall                              = false
      firewall_policy                       = false
      bastion                               = true
      virtual_network_gateway_express_route = true
      virtual_network_gateway_vpn           = true
      private_dns_zones                     = true
      private_dns_resolver                  = true
      sidecar_virtual_network               = true
    }

    hub = {
      name                                   = "vHUB-CC-Cloud"
      address_prefix                         = "10.58.128.0/21"
      hub_routing_preference                 = "ExpressRoute"
      virtual_router_auto_scale_min_capacity = 2
    }

    virtual_network_gateways = {
      express_route = {
        name        = "ergw-cc-cloud"
        scale_units = 1
      }
      vpn = {
        name       = "vpngw-cc-cloud"
        scale_unit = 1
      }
    }
    express_route_circuit_connections = {
      # "er-conn-toronto-dc" = {
      #   name                             = "erconn-toronto-dc"
      #   express_route_circuit_peering_id = "/subscriptions/<ER-circuit-subscription-id>/resourceGroups/<ER-circuit-RG>/providers/Microsoft.Network/expressRouteCircuits/<ER-circuit-name>/peerings/AzurePrivatePeering"
      #   authorization_key                = "<authorization-key-from-er-circuit>"  # Replace with actual key
      #   enable_internet_security         = false
      #   routing_weight                   = 0
      # }
    }

    # ── VPN Sites (on-prem branch locations) ──
    vpn_sites = {
      "branch-toronto" = {
        name = "vpnsite-branch-toronto"
        links = [{
          name       = "isp-primary"
          ip_address = "203.0.113.1"      # Replace with your on-prem device public IP
          speed_in_mbps = 100
          bgp = {
            asn             = 65010
            peering_address = "10.100.0.1"  # On-prem BGP peer IP
          }
        }]
        address_cidrs = ["10.100.0.0/16"]   # On-prem address space
        device_vendor = "Cisco"
        device_model  = "ISR4451"
      }
    }

    # ── VPN Site Connections (link sites to the hub VPN gateway) ──
    vpn_site_connections = {
      "conn-branch-toronto" = {
        name                = "vpnconn-branch-toronto"
        remote_vpn_site_key = "cc-hub01-branch-toronto"
        vpn_links = [{
          name                 = "link-isp-primary"
          vpn_site_link_number = 0
          vpn_site_key         = "cc-hub01-branch-toronto"
          bandwidth_mbps       = 100
          bgp_enabled          = true
          protocol             = "IKEv2"
          shared_key           = "YourPreSharedKey123!"  # Replace with a real PSK or use Key Vault reference
          ipsec_policy = {
            dh_group                 = "DHGroup14"
            ike_encryption_algorithm = "AES256"
            ike_integrity_algorithm  = "SHA256"
            encryption_algorithm     = "AES256"
            integrity_algorithm      = "SHA256"
            pfs_group                = "PFS14"
            sa_data_size_kb          = "102400000"
            sa_lifetime_sec          = "3600"
          }
        }]
        internet_security_enabled = false
      }
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

      bastion_public_ip = {
        name = "pip-bas-cc-cloud"
      }
    }

    private_dns_zones = {
      auto_registration_zone_enabled = false

      private_link_excluded_zones = [
        "azure_power_bi_power_query",  # AVM bug: deploys privatelink.tip1.powerquery.microsoft.com instead of privatelink.prod.powerquery.microsoft.com
      ]
      private_link_private_dns_zones_additional = {
        azure_power_bi_power_query_correct = {
          zone_name = "privatelink.prod.powerquery.microsoft.com"
        }
      }
      virtual_network_link_additional_virtual_networks = {}
    }
    private_dns_resolver = {
      name                             = "dnspr-cc-cloud"
      default_inbound_endpoint_enabled = false
      subnet_name                      = "snet-dns-resolver-inbound"
      subnet_address_prefix            = "10.58.136.64/28"
      inbound_endpoints = {
        "default" = {
          name        = "ie-cc-cloud"
          subnet_name = "snet-dns-resolver-inbound"
        }
      }
      outbound_endpoints = {
        "default" = {
          name        = "oe-cc-cloud"
          subnet_name = "snet-dns-resolver-outbound"
          forwarding_ruleset = {
            "default" = {
              name                                     = "frs-cc-cloud"
              link_with_outbound_endpoint_virtual_network = true
              additional_virtual_network_links = {}
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
  }
  "ce-hub01" = {
    location = "canadaeast"

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
      name                                   = "vHUB-CE"
      address_prefix                         = "10.70.128.0/21"
      hub_routing_preference                 = "ExpressRoute"
      virtual_router_auto_scale_min_capacity = 2
    }

    sidecar_virtual_network = {
      name          = "vnet-sidecar-ce-cloud"
      address_space = ["10.77.0.0/24"]

      virtual_network_connection_settings = {
        name = "vnet-conn-sidecar-ce-cloud"
      }

      subnets = {
        "dns-resolver-outbound" = {
          name             = "snet-dns-resolver-outbound"
          address_prefixes = ["10.77.0.80/28"]
          delegations = [{
            name = "Microsoft.Network.dnsResolvers"
            service_delegation = {
              name = "Microsoft.Network/dnsResolvers"
            }
          }]
        }
      }
    }
    private_dns_resolver = {
      name                             = "dnspr-ce-cloud"
      default_inbound_endpoint_enabled = false
      subnet_name                      = "snet-dns-resolver-inbound"
      subnet_address_prefix            = "10.77.0.64/28"
      inbound_endpoints = {
        "default" = {
          name        = "ie-ce-cloud"
          subnet_name = "snet-dns-resolver-inbound"
        }
      }
      outbound_endpoints = {
        "default" = {
          name        = "oe-ce-cloud"
          subnet_name = "snet-dns-resolver-outbound"
        }
      }
    }
  }
}
