resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# Network Module (only if VM is deployed)
module "network" {
  count  = contains(["vm", "both"], var.resource_type) ? 1 : 1
  source = "./modules/network"

  prefix              = var.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  vnet_cidr           = var.vnet_cidr
  subnet_cidr         = var.subnet_cidr
}

# VM Module (only if resource_type is vm or both)
module "vm" {
  count  = contains(["vm", "both"], var.resource_type) ? 1 : 0
  source = "./modules/vm"

  prefix               = var.prefix
  location             = var.location
  resource_group_name  = azurerm_resource_group.rg.name
  admin_username       = var.admin_username
  ssh_public_key       = var.ssh_public_key
  vm_size              = var.vm_size
  network_interface_id = module.network[0].network_interface_id
}

# App Service Module (only if resource_type is appservice or both)
module "appservice" {
  count  = contains(["appservice", "both"], var.resource_type) ? 1 : 0
  source = "./modules/appservice"

  prefix              = var.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_tier            = var.app_service_sku_tier
  sku_size            = var.app_service_sku_size
  linux_fx_version    = var.app_service_linux_fx_version
  app_settings        = var.app_service_settings
}


