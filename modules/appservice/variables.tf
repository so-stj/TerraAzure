variable "prefix" {
  description = "Prefix to use for all resource names"
  type        = string
}

variable "location" {
  description = "Azure region to deploy resources into"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "kind" {
  description = "The kind of the App Service Plan"
  type        = string
  default     = "Linux"
}

variable "reserved" {
  description = "Is this App Service Plan reserved"
  type        = bool
  default     = true
}

variable "sku_tier" {
  description = "Specifies the plan's pricing tier"
  type        = string
  default     = "Standard"
}

variable "sku_size" {
  description = "Specifies the plan's instance size"
  type        = string
  default     = "S1"
}

variable "linux_fx_version" {
  description = "Linux App Framework and version for the App Service"
  type        = string
  default     = "DOCKER|nginx:latest"
}

variable "app_command_line" {
  description = "App command line to launch"
  type        = string
  default     = null
}

variable "app_settings" {
  description = "A key-value pair of App Settings"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
