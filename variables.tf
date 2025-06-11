variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "PoC-Containers"
}

variable "storage_account_name" {
  description = "The name of the storage account for Caddy volumes"
  type        = string
  default     = "caddystorageaccount8dh3"
}

variable "container_group_name" {
  description = "The name of the container group"
  type        = string
  default     = "ci-my-app-8dh36a"
}

variable "dns_name_label" {
  description = "The DNS name label for the container group"
  type        = string
  default     = "my-app-8dh36a"
}