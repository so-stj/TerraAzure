variable "prefix" {
  description = "Prefix to use for all resource names"
  type        = string
  default     = "tfvm"
}

variable "location" {
  description = "Azure region to deploy resources into"
  type        = string
  default     = "japaneast"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for the VM (e.g., contents of ~/.ssh/id_rsa.pub)"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "vnet_cidr" {
  description = "CIDR for the Virtual Network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR for the Subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "resource_type" {
  description = "Type of Azure resource to deploy (vm, appservice, or both)"
  type        = string
  default     = "vm"
  validation {
    condition     = contains(["vm", "appservice", "both"], var.resource_type)
    error_message = "Resource type must be one of: vm, appservice, both."
  }
}

# App Service specific variables
variable "app_service_sku_tier" {
  description = "App Service Plan SKU tier"
  type        = string
  default     = "Standard"
}

variable "app_service_sku_size" {
  description = "App Service Plan SKU size"
  type        = string
  default     = "S1"
}

variable "app_service_linux_fx_version" {
  description = "Linux App Framework and version for the App Service"
  type        = string
  default     = "DOCKER|nginx:latest"
}

variable "app_service_settings" {
  description = "App Service application settings"
  type        = map(string)
  default     = {}
}


