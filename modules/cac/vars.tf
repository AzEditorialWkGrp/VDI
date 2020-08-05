/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "virtual_machine_name" {
  description = "Virtual machine name"
}

variable "deployment_index" {
  description = "The Azure Region in which all resources in this example should be created."
}

variable "resource_group_name" {
  description = "Name of the resource group"
}

variable "cam_url" {
  description = "Cloud Access Manager URL"
  default     = "https://cam.teradici.com"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type        = string
}

variable "cac_token" {
  description = "Connector Token from CAM Service"
  type        = string
}

variable "domain_name" {
  description = "Name of the domain to join"
  type        = string
}

variable "domain_controller_ip" {
  description = "Internal IP of the Domain Controller"
  type        = string
}

variable "domain_group" {
  description = "Active Directory Distinguished Name for the User Group to log into the CAM Management Interface. Default is 'Domain Admins'. (eg, 'CN=CAM Admins,CN=Users,DC=example,DC=com')"
  default     = "Domain Admins"
}

variable "ad_service_account_username" {
  description = "Active Directory Service Account username"
  type        = string
}

variable "ad_service_account_password" {
  description = "Active Directory Service Account password"
  type        = string
}

variable "location" {
  description = "Zone to deploy the Cloud Access Connector"
  default     = "centralus"
}

variable "nic_id" {
  description = "Network Interface Card ID for the Cloud Access Connector"
  type        = string
}

variable "instance_count" {
  description = "Number of Cloud Access Connectors to deploy"
  default     = 1
}

variable "host_name" {
  description = "Name to give the host"
  default     = "vm-cac"
}

variable "machine_type" {
  description = "Machine type for the Cloud Access Connector"
  default     = "Standard_DS2_v3"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Cloud Access Connector"
  default     = "50"
}

variable "cac_admin_user" {
  description = "Username of the Cloud Access Connector Administrator"
  type        = string
}

variable "cac_admin_password" {
  description = "Password for the Administrator of the Cloud Access Connector VM"
  type        = string
}

variable "cac_installer_url" {
  description = "Location of the Cloud Access Connector installer"
  default     = "https://teradici.bintray.com/cloud-access-connector/cloud-access-connector-0.1.1.tar.gz"
}

variable "ssl_key" {
  description = "SSL private key for the Connector"
  default     = ""
}

variable "ssl_cert" {
  description = "SSL certificate for the Connector"
  default     = ""
}

variable "dns_zone_id" {
  description = "Default DNS Zone ID"
}


variable "cac_ip" {
  description = "IP address of the CAC VM"
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

variable "cac_token_secret_id" {
  description = "The secret identifier in your azure key vault, follow this format https://<keyvault-name>.vault.azure.net/secrets/<secret-name>/<secret-version>"
  type        = string
}

variable "_artifactsLocation" {
  description = "The base URI where artifacts required by this template are located including a trailing '/'"
}

locals {
  startup_cac_filename = "cac-startup.sh"
  templatefile = templatefile("${path.module}/cac-startup.sh", {
    cac_installer_url           = var.cac_installer_url
    domain_controller_ip        = var.domain_controller_ip
    ad_service_account_username = var.ad_service_account_username
    ad_service_account_password = var.ad_service_account_password
    domain_name                 = var.domain_name
    cam_url                     = var.cam_url
    cac_token                   = var.cac_token
    domain_group                = var.domain_group
    pcoip_registration_code     = var.pcoip_registration_code
    ssl_key                     = var.ssl_key
    ssl_cert                    = var.ssl_cert
    application_id              = var.application_id
    aad_client_secret           = var.aad_client_secret
    tenant_id                   = var.tenant_id
    pcoip_secret_key            = var.pcoip_secret_id
    ad_pass_secret_key          = var.ad_pass_secret_id
    cac_token_secret_key        = var.cac_token_secret_id
    _artifactsLocation          = var._artifactsLocation
  })
}

variable "vm_depends_on" {}