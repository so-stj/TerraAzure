# VM Outputs (only if VM is deployed)
output "public_ip" {
  description = "Public IP address of the VM"
  value       = contains(["vm", "both"], var.resource_type) ? module.network[0].public_ip_address : null
}

output "vm_id" {
  description = "ID of the provisioned VM"
  value       = contains(["vm", "both"], var.resource_type) ? module.vm[0].vm_id : null
}

output "admin_username" {
  description = "Admin username configured on the VM"
  value       = contains(["vm", "both"], var.resource_type) ? module.vm[0].admin_username : null
}

# App Service Outputs (only if App Service is deployed)
output "app_service_url" {
  description = "URL of the App Service"
  value       = contains(["appservice", "both"], var.resource_type) ? module.appservice[0].app_service_url : null
}

output "app_service_id" {
  description = "ID of the App Service"
  value       = contains(["appservice", "both"], var.resource_type) ? module.appservice[0].app_service_id : null
}

output "app_service_name" {
  description = "Name of the App Service"
  value       = contains(["appservice", "both"], var.resource_type) ? module.appservice[0].app_service_name : null
}


