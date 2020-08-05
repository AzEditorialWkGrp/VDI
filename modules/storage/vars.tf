variable "resource_group_name" {
  description = "Basename of the Resource Group to deploy the workstation"
}

variable "deployment_index" {
  description = "Number (index) of the deployment"
}

variable "location" {
  description = "Zone to deploy storages"
}

variable "storage_name" {
  description = "Base name for Standard/Premium storage. Will be prefixed with 'ss'"
}

variable "is_premium_storage" {
  description = "Type (account tier) of storage"
  default = false
}

variable "diag_storage_name" {
  description = "Base name for diagnostic storage. Will be prefixed with 'stdiag'"
}

variable "file_share_quota" {
  description = "Provisioned capacity of file share in GiB. Possible values 100-102400"
}

variable "assets_storage_account" {
  description = "Source storage name account for downloading assets to file share"
  type        = string
}

variable "assets_storage_account_key" {
  type    = string
  description = "Access key for storage account containing demo assets and VM images"
}

variable "assets_storage_container" {
  description = "Source storage container for downloading assets to file share"
  type        = string
}

variable "os_disk_name" {
  type = string
}

variable "data_disk_name" {
  type = string
}

variable "tags" {
  description = "Common tags for storage resource"
}

locals {
  images_container_name = "vm-images"
}