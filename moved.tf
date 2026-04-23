# ─────────────────────────────────────────────────────────────
# Moved blocks — rename hub key "cc-hub" → "cc-hub01"
#
# These tell Terraform to update the state keys without
# destroying / recreating any Azure resources.
# Safe to remove after a successful apply.
# ─────────────────────────────────────────────────────────────

# ── Top-level module instances (for_each keyed by hub key) ──

moved {
  from = module.vwan.module.virtual_network_side_car["cc-hub"]
  to   = module.vwan.module.virtual_network_side_car["cc-hub01"]
}

moved {
  from = module.vwan.module.bastion_public_ip["cc-hub"]
  to   = module.vwan.module.bastion_public_ip["cc-hub01"]
}

moved {
  from = module.vwan.module.bastion_host["cc-hub"]
  to   = module.vwan.module.bastion_host["cc-hub01"]
}

moved {
  from = module.vwan.module.private_dns_zones["cc-hub"]
  to   = module.vwan.module.private_dns_zones["cc-hub01"]
}

moved {
  from = module.vwan.module.private_dns_resolver["cc-hub"]
  to   = module.vwan.module.private_dns_resolver["cc-hub01"]
}

# ── Virtual Hub (inside the virtual-wan sub-module) ─────────

moved {
  from = module.vwan.module.virtual_wan[0].module.virtual_hubs.azurerm_virtual_hub.virtual_hub["cc-hub"]
  to   = module.vwan.module.virtual_wan[0].module.virtual_hubs.azurerm_virtual_hub.virtual_hub["cc-hub01"]
}

# ── Express Route Gateway ──────────────────────────────────

moved {
  from = module.vwan.module.virtual_wan[0].module.express_route_gateways.azurerm_express_route_gateway.express_route_gateway["cc-hub"]
  to   = module.vwan.module.virtual_wan[0].module.express_route_gateways.azurerm_express_route_gateway.express_route_gateway["cc-hub01"]
}

# ── VPN Gateway ─────────────────────────────────────────────

moved {
  from = module.vwan.module.virtual_wan[0].module.vpn_gateway.azurerm_vpn_gateway.vpn_gateway["cc-hub"]
  to   = module.vwan.module.virtual_wan[0].module.vpn_gateway.azurerm_vpn_gateway.vpn_gateway["cc-hub01"]
}

# ── VPN Sites (composite key: "${hub_key}-${site_key}") ────

moved {
  from = module.vwan.module.virtual_wan[0].module.vpn_site.azurerm_vpn_site.vpn_site["cc-hub-branch-toronto"]
  to   = module.vwan.module.virtual_wan[0].module.vpn_site.azurerm_vpn_site.vpn_site["cc-hub01-branch-toronto"]
}

# ── VPN Site Connections (composite key: "${hub_key}-${conn_key}") ──

moved {
  from = module.vwan.module.virtual_wan[0].module.vpn_site_connection.azurerm_vpn_gateway_connection.vpn_site_connection["cc-hub-conn-branch-toronto"]
  to   = module.vwan.module.virtual_wan[0].module.vpn_site_connection.azurerm_vpn_gateway_connection.vpn_site_connection["cc-hub01-conn-branch-toronto"]
}

# ── VNet Connection — sidecar (key: "private_dns_vnet_${hub_key}") ──

moved {
  from = module.vwan.module.virtual_wan[0].module.virtual_network_connections.azurerm_virtual_hub_connection.hub_connection["private_dns_vnet_cc-hub"]
  to   = module.vwan.module.virtual_wan[0].module.virtual_network_connections.azurerm_virtual_hub_connection.hub_connection["private_dns_vnet_cc-hub01"]
}
