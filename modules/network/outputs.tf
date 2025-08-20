output "network_interface_id" {
  description = "ID of the network interface"
  value       = azurerm_network_interface.nic.id
}

output "public_ip_address" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = azurerm_subnet.subnet.id
}
