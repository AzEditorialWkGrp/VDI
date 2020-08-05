variable "subscription_id" {
  type        = string
}

variable "client_id" {
  type        = string
}

variable "client_secret" {
  type        = string
}

variable "tenant_id" {
  type        = string
}

variable "deployment_id" {
  type        = string
}

variable "dependency" {
}

locals {
  connector_name  = "cac-${lower(formatdate("MMMM-DD", timestamp()))}"
}