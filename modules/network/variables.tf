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
