variable "cam_service_token" {
  type    = string
}

variable "cam_deployment_id" {
  type    = string
}

variable "cam_connector_name" {
  type    = string
}

variable "azure_subscription_id" {
  type = string
}

variable "azure_resource_group" {
  type = string
}

variable "vm_name" {
  type = string
}

variable "vm_count" {
}

variable "workstations" {
}

locals {
  users = csvdecode(file("${path.root}/domain_users_list.csv"))
  users_map = {
    for user in jsondecode(data.http.users.body).data:
      user.userName => user.userGuid
  }
}