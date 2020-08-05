/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "virtual_machine_name" {
  description = "Virtual machine name"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
}

variable "deployment_index" {
  description = "The Azure Region in which all resources in this example should be created."
}

variable "resource_group_name" {
  description = "The name of the resource group"
}

variable "active_directory_domain_name" {
  description = "the domain name for Active Directory, for example `consoto.local`"
}

variable "active_directory_netbios_name" {
  description = "The netbios name of the Active Directory domain, for example `consoto`"
}

variable "ad_admin_username" {
  description = "Username for the Domain Administrator user"
}

variable "ad_admin_password" {
  description = "Password for the Adminstrator user"
}

variable "nic_id" {
  description = "Network Interafce Card Id"
}

variable "dc_machine_type" {
  description = "Machine type for Domain Controller"
  default     = "Standard_F2"
}

variable "ad_pass_secret_name" {
  description = "The name of the Active Directory secret password"
  type        = string
}

variable "key_vault_id" {
  description = "The key vault resource ID"
  type        = string
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

variable "safe_admin_pass_secret_id" {
  description = "The secret identifier in your azure key vault, follow this format https://<keyvault-name>.vault.azure.net/secrets/<secret-name>/<secret-version>"
  type        = string
}

variable "safe_mode_admin_password" {
  description = "Safe Mode Admin Password (Directory Service Restore Mode - DSRM)"
  type        = string
}

variable "_artifactsLocation" {
  description = "The base URI where artifacts required by this template are located including a trailing '/'"
  default     = ""
}

variable "fs_stroage_account" {
  type        = string
}

variable "fs_stroage_container" {
  type        = string
}

variable "fs_stroage_password" {
  type        = string
}

variable "fs_dependancy" {
}

variable "dependency" {
}

locals {
  use_secret_or_not    = var.ad_admin_password != "" ? { ad_admin_password = var.ad_admin_password } : { ad_admin_password = tostring(data.azurerm_key_vault_secret.ad-pass[0].value) }
  ad_admin_password_escaped = replace(replace(replace(replace(replace(local.use_secret_or_not.ad_admin_password, "&", "&amp;"), ">", "&gt;"), "<", "&lt;"), "'", "&apos;"), "\"", " &quot;")
  virtual_machine_fqdn = join(".", [var.virtual_machine_name, var.active_directory_domain_name])
  auto_logon_data      = "<AutoLogon><Password><Value>${local.ad_admin_password_escaped}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.ad_admin_username}</Username></AutoLogon>"
  first_logon_data     = file("${path.module}/files/FirstLogonCommands.xml")
  custom_data_params   = "Param($RemoteHostName = \"${local.virtual_machine_fqdn}\", $ComputerName = \"${var.virtual_machine_name}\")"
  custom_data          = base64encode(join(" ", [local.custom_data_params, file("${path.module}/files/winrm.ps1")]))

  sysprep_filename           = "sysprep.ps1"
  setup_file                 = "C:/Temp/setup.ps1"
  gpo_file                   = "C:/Temp/gpo.ps1"
  gpo_folder                 = "C:/Temp/gpo"
  gpo_archive                = "C:/Temp/gpo.zip"
  new_domain_admin_user_file = "C:/Temp/new_domain_admin_user.ps1"
  new_domain_users_file      = "C:/Temp/new_domain_users.ps1"
  domain_users_list_file     = "C:/Temp/domain_users_list.csv"
  setup_script               = "setup.ps1"
  password_command           = "$password = ConvertTo-SecureString ${local.use_secret_or_not.ad_admin_password} -AsPlainText -Force"
  install_ad_command         = "Add-WindowsFeature -name ad-domain-services -IncludeManagementTools"
  configure_ad_command       = "Install-ADDSForest -CreateDnsDelegation:$false -DomainMode Win2012R2 -DomainName ${var.active_directory_domain_name} -DomainNetbiosName ${var.active_directory_netbios_name} -ForestMode Win2012R2 -InstallDns:$true -SafeModeAdministratorPassword $password -Force:$true"
  shutdown_command           = "shutdown -r -t 10"
  exit_code_hack             = "exit 0"
  powershell_arguments = " -admin_password ${local.use_secret_or_not.ad_admin_password} -admin_username ${var.ad_admin_username}"
  powershell_command   = "powershell.exe -ExecutionPolicy Unrestricted -File ${local.sysprep_filename}${local.powershell_arguments}"
}
