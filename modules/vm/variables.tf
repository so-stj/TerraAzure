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

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for the VM"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "network_interface_id" {
  description = "ID of the network interface"
  type        = string
}
