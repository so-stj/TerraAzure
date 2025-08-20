output "vm_id" {
  description = "ID of the provisioned VM"
  value       = azurerm_linux_virtual_machine.vm.id
}

output "admin_username" {
  description = "Admin username configured on the VM"
  value       = var.admin_username
}
