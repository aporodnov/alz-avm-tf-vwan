output "virtual_wan_name" {
  value       = module.vwan.name
  description = "Name of the Virtual WAN."
}

output "virtual_wan_resource_id" {
  value       = module.vwan.resource_id
  description = "Resource ID of the Virtual WAN."
}

output "virtual_hub_resource_ids" {
  value       = module.vwan.virtual_hub_resource_ids
  description = "Resource IDs of the virtual hubs."
}

output "virtual_hub_resource_names" {
  value       = module.vwan.virtual_hub_resource_names
  description = "Names of the virtual hubs."
}

output "express_route_gateway_resource_ids" {
  value       = module.vwan.express_route_gateway_resource_ids
  description = "Resource IDs of the ExpressRoute gateways."
}

output "firewall_resource_ids" {
  value       = module.vwan.firewall_resource_ids
  description = "Resource IDs of the Azure Firewalls."
}

output "networking_resource_group_name" {
  value       = azurerm_resource_group.networking.name
  description = "Name of the networking resource group."
}

output "dns_resource_group_name" {
  value       = try(azurerm_resource_group.dns[0].name, null)
  description = "Name of the DNS resource group."
}
