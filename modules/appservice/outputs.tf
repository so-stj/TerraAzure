output "app_service_plan_id" {
  description = "ID of the App Service Plan"
  value       = azurerm_app_service_plan.plan.id
}

output "app_service_id" {
  description = "ID of the App Service"
  value       = azurerm_app_service.app.id
}

output "app_service_url" {
  description = "URL of the App Service"
  value       = azurerm_app_service.app.default_site_hostname
}

output "app_service_name" {
  description = "Name of the App Service"
  value       = azurerm_app_service.app.name
}
