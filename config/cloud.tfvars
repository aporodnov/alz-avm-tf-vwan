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

    # Disable all optional sub-resources for a lean cloud-only hub.
    enabled_resources = {
      firewall                              = false
      firewall_policy                       = false
      bastion                               = false
      virtual_network_gateway_express_route = false
      virtual_network_gateway_vpn           = false
      private_dns_zones                     = false
      private_dns_resolver                  = false
      sidecar_virtual_network               = false
    }

    hub = {
      name                                   = "vHUB-CC-Cloud"
      address_prefix                         = "10.58.128.0/21"
      hub_routing_preference                 = "ExpressRoute"
      virtual_router_auto_scale_min_capacity = 2
    }
  }
}
