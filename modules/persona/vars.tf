/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "resource_group_name" {
  description = "Basename of the Resource Group to deploy the workstation. Hostname will be <prefix>-<name>.Lower case only."
  type        = string
}

variable "vm_name" {
  description = "Virtual machine name"
  type        = string
}

variable "admin_name" {
  description = "Name for the Administrator of the Workstation"
  type        = string
}

variable "admin_password" {
  description = "Password for the Administrator of the Workstation"
  type        = string
}

variable "base_name" {
  description = "Base name of new resources. Must be <= 9 characters."
  type        = string
}

variable "host_name" {
  description = "Basename of hostname of the workstation. Hostname will be <prefix>-<name>. Lower case only."
  type        = string
}

variable "pcoip_agent_location" {
  description = "URL of Teradici PCoIP Standard Agent"
  default     = "https://downloads.teradici.com/win/stable/"
}

variable "storage_account" {
  description = "File share storage account"
}

variable "storage_container" {
  description = "File share storage account"
}

variable "storage_access_key" {
  description = "File share storage account"
}

variable "diagnostic_storage_url" {
  description = "Diagnostic storage url"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code from Teradici"
  type        = string
}

variable "azure_region" {
  description = "Region to deploy the workstation"
  type        = string
  default     = "centralus"
}

variable "ad_service_account_password" {
  description = "Active Directory Service Account password"
  type        = string
}

variable "ad_service_account_username" {
  description = "Active Directory Service Account username"
  type        = string
}

variable "public_ip_allocation" {
  description = "Public IP Allocation Method. Dynamic or Static."
  type        = string
  default     = "Static"
}

variable "domain_name" {
  description = "Name of the domain to join"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Vnet to deploy the agent"
  type        = string
}

variable "nsgID" {
  description = "Enter in the name of the network security group"
  type        = string
}

variable "subnetID" {
  description = "Enter in the ID of the workstation subnet"
  type        = string
}

variable "subnet_name" {
  description = "Enter in the name of the subnet name"
  type        = string
}

variable "vm_size" {
  description = "Size of the VM to deploy"
  type        = string
  default     = "Standard_B2ms"
}

variable "application_id" {
  description = "The application (client) ID of your app registration in AAD"
  type        = string
}

variable "aad_client_secret" {
  description = "The client secret of your app registration in AAD"
  type        = string
}

variable "tenant_id" {
  description = "The directory (tenant) ID of your app registration in AAD"
  type        = string
}

variable "pcoip_secret_id" {
  description = "The secret identifier in your azure key vault, follow this format https://<keyvault-name>.vault.azure.net/secrets/<secret-name>/<secret-version>"
  type        = string
}

variable "ad_pass_secret_id" {
  description = "The secret identifier in your azure key vault, follow this format https://<keyvault-name>.vault.azure.net/secrets/<secret-name>/<secret-version>"
  type        = string
}

variable "instance_count" {
  description = "Number of Windows Standard Workstations to deploy"
  default     = 1
}

variable "_artifactsLocation" {
  description = "URL to retrieve startup scripts with a trailing /"
  type        = string
}

variable "_artifactsLocationSasToken" {
  description = "Sas Token of the URL is optional, only if required for security reasons"
  type        = string
}

variable "images_storage_account" {
  type = string
}

variable "images_container_access_key" {
  type = string
}

variable "images_container_uri" {
  type = string
}

variable "tags" {
  description = "Common tags for storage resource"
}

variable "os_disk_name" {
  type = string
}

variable "data_disk_name" {
  type = string
}

variable "vm_depends_on" {}
