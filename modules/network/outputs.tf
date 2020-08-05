output "dc_nic_id" {
  value = azurerm_network_interface.dc_nic.id
}

output "dc_nic_private_ip" {
  value = azurerm_network_interface.dc_nic.private_ip_address
}

output "cac_nic_id" {
  value = azurerm_network_interface.cac.id
}

output "dns_id" {
  value = azurerm_private_dns_zone.dns.id
}

output "cac_public_ip" {
  value = azurerm_public_ip.cac.ip_address
}

output "virtual_network_name" {
  value = azurerm_virtual_network.vdi_virtual_network.name
}

output "nsg_id" {
  value = azurerm_network_security_group.nsg.id
}

output "subnet_workstation" {
  value = azurerm_subnet.workstation
}