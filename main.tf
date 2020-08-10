data "azurerm_subscription" "current" {
}

resource "time_static" "date_creation" {}

resource "azurerm_resource_group" "vdi_resource_group" {
  location = var.common_location
  name     = var.resource_group_name != "" ? var.resource_group_name : "rg-${var.base_name}-infra-${var.deployment_index}"
}

module "app-registration" {
  source = "./modules/app-registration"

  application_name = azurerm_resource_group.vdi_resource_group.name
  subscription_id  = data.azurerm_subscription.current.subscription_id
}

module "storage" {
  source = "./modules/storage"

  resource_group_name        = azurerm_resource_group.vdi_resource_group.name
  index                      = time_static.date_creation.unix
  location                   = var.common_location
  storage_name               = var.storage_name
  is_premium_storage         = var.vm_persona > 1
  diag_storage_name          = var.diag_storage_name
  file_share_quota           = var.storage_capacity != "" ? var.storage_capacity : 5120
  assets_storage_account     = var.assets_storage_account
  assets_storage_account_key = var.assets_storage_account_key
  assets_storage_container   = var.assets_storage_container
  images_storage_container   = var.images_storage_container
  os_disk_name               = local.workstation_os_disk_name
  data_disk_name             = local.workstation_data_disk_name
  tags                       = local.common_tags
}

module "network" {
  source = "./modules/network"

  resource_group_name           = azurerm_resource_group.vdi_resource_group.name
  location                      = var.common_location
  base_name                     = var.base_name
  deployment_index              = var.deployment_index
  dc_subnet_cidr                = var.dc_subnet_cidr
  cac_subnet_cidr               = var.cac_subnet_cidr
  ws_subnet_cidr                = var.ws_subnet_cidr
  dc_virtual_machine_name       = local.dc_virtual_machine_name
  cac_virtual_machine_name      = local.cac_virtual_machine_name
  dc_private_ip                 = var.dc_private_ip
  cac_private_ip                = var.cac_private_ip
  active_directory_netbios_name = var.active_directory_netbios_name
  allowed_client_cidrs          = var.allowed_client_cidrs
}

module "active-directory-domain" {
  source = "./modules/dc"

  dependency          = module.app-registration.app_registration_created
  resource_group_name = azurerm_resource_group.vdi_resource_group.name
  location            = azurerm_resource_group.vdi_resource_group.location
  deployment_index    = var.deployment_index

  virtual_machine_name          = local.dc_virtual_machine_name
  active_directory_domain_name  = "${var.active_directory_netbios_name}.dns.internal"
  active_directory_netbios_name = var.active_directory_netbios_name
  ad_admin_username             = var.ad_admin_username
  ad_admin_password             = var.ad_admin_password
  dc_machine_type               = var.dc_machine_type
  nic_id                        = module.network.dc_nic_id
  ad_pass_secret_name           = var.ad_pass_secret_name
  key_vault_id                  = var.key_vault_id
  application_id                = var.application_id
  aad_client_secret             = var.aad_client_secret
  tenant_id                     = var.tenant_id
  safe_admin_pass_secret_id     = var.safe_admin_pass_secret_id
  safe_mode_admin_password      = var.safe_mode_admin_password
  _artifactsLocation            = var._artifactsLocation

  fs_stroage_account            = module.storage.storage_account
  fs_stroage_container          = module.storage.storage_container
  fs_stroage_password           = module.storage.storage_access_key
  fs_dependancy                 = module.storage.storage_created
}

module "cam-pre-requisites" {
  source                  = "./modules/cam-pre-requisites"
  deployment_id           = var.cam_deployement_id
  subscription_id         = data.azurerm_subscription.current.subscription_id
  client_id               = module.app-registration.client_id
  client_secret           = module.app-registration.client_secret
  tenant_id               = data.azurerm_subscription.current.tenant_id
  dependency              = module.active-directory-domain.domain_users_created
}

module "cam-post-deployment" {
  source                 = "./modules/cam-post-deployment"
  cam_service_token      = var.cam_service_token
  cam_deployment_id      = var.cam_deployement_id
  cam_connector_name     = module.cam-pre-requisites.connector_name
  azure_subscription_id  = data.azurerm_subscription.current.subscription_id
  azure_resource_group   = azurerm_resource_group.vdi_resource_group.name
  vm_name                = local.vm_names[var.vm_persona]
  vm_count               = local.vm_count
  workstations           = local.workstations
}

module "cac" {
  source = "./modules/cac"

  resource_group_name = azurerm_resource_group.vdi_resource_group.name
  location            = azurerm_resource_group.vdi_resource_group.location
  deployment_index    = var.deployment_index

  virtual_machine_name        = local.cac_virtual_machine_name
  cam_url                     = var.cam_url
  pcoip_registration_code     = var.pcoip_registration_code
  cac_token                   = module.cam-pre-requisites.cac_token
  domain_name                 = "${var.active_directory_netbios_name}.dns.internal"
  domain_controller_ip        = module.network.dc_nic_private_ip
  domain_group                = var.domain_group
  ad_service_account_username = var.ad_admin_username
  ad_service_account_password = var.ad_admin_password
  nic_id                      = module.network.cac_nic_id
  instance_count              = var.instance_count
  host_name                   = var.cac_host_name
  machine_type                = var.cac_machine_type
  disk_size_gb                = var.cac_disk_size_gb
  cac_admin_user              = var.cac_admin_username
  cac_admin_password          = var.cac_admin_password
  cac_installer_url           = var.cac_installer_url
  ssl_key                     = var.ssl_key
  ssl_cert                    = var.ssl_cert
  dns_zone_id                 = module.network.dns_id
  cac_ip                      = module.network.cac_public_ip
  application_id              = var.application_id
  aad_client_secret           = var.aad_client_secret
  tenant_id                   = var.tenant_id
  pcoip_secret_id             = var.pcoip_secret_id
  ad_pass_secret_id           = var.ad_pass_secret_id
  cac_token_secret_id         = var.cac_token_secret_id
  _artifactsLocation          = var._artifactsLocation
  vm_depends_on               = module.cam-pre-requisites.service_account_created
}

module "persona-1" {
  source = "./modules/persona"

  resource_group_name = azurerm_resource_group.vdi_resource_group.name
  azure_region        = azurerm_resource_group.vdi_resource_group.location

  vm_name                     = local.vm_names[1]
  base_name                   = var.base_name
  pcoip_registration_code     = var.pcoip_registration_code
  domain_name                 = "${var.active_directory_netbios_name}.dns.internal"
  ad_service_account_username = var.ad_admin_username
  ad_service_account_password = var.ad_admin_password
  admin_name                  = var.windows_std_admin_username
  admin_password              = var.windows_std_admin_password
  host_name                   = var.windows_std_hostname
  instance_count              = var.vm_persona == 1 ? local.vm_count : 0
  pcoip_agent_location        = var.pcoip_agent_location
  os_disk_name                = local.workstation_os_disk_name
  data_disk_name              = local.workstation_data_disk_name
  images_storage_account      = module.storage.images_storage_account
  images_container_access_key = module.storage.images_container_access_key
  images_container_uri        = module.storage.images_container_uri
  storage_account             = module.storage.storage_account
  storage_container           = module.storage.storage_container
  storage_access_key          = module.storage.storage_access_key
  diagnostic_storage_url      = module.storage.diag_storage_blob_endpoint
  vnet_name                   = module.network.virtual_network_name
  nsgID                       = module.network.nsg_id
  subnetID                    = module.network.subnet_workstation.id
  subnet_name                 = module.network.subnet_workstation.name
  vm_size                     = "Standard_NV6"
  application_id              = var.application_id
  aad_client_secret           = var.aad_client_secret
  tenant_id                   = var.tenant_id
  pcoip_secret_id             = var.pcoip_secret_id
  ad_pass_secret_id           = var.ad_pass_secret_id
  _artifactsLocation          = var._artifactsLocation
  _artifactsLocationSasToken  = var._artifactsLocationSasToken
  tags                        = local.common_tags
  vm_depends_on               = module.cac.cac_created
}

module "persona-2" {
  source = "./modules/persona"

  resource_group_name = azurerm_resource_group.vdi_resource_group.name
  azure_region        = azurerm_resource_group.vdi_resource_group.location

  vm_name                     = local.vm_names[2]
  base_name                   = var.base_name
  pcoip_registration_code     = var.pcoip_registration_code
  domain_name                 = "${var.active_directory_netbios_name}.dns.internal"
  ad_service_account_username = var.ad_admin_username
  ad_service_account_password = var.ad_admin_password
  admin_name                  = var.windows_std_admin_username
  admin_password              = var.windows_std_admin_password
  host_name                   = var.windows_std_hostname
  instance_count              = var.vm_persona == 2 ? local.vm_count : 0
  pcoip_agent_location        = var.pcoip_agent_location
  os_disk_name                = local.workstation_os_disk_name
  data_disk_name              = local.workstation_data_disk_name
  images_storage_account      = module.storage.images_storage_account
  images_container_access_key = module.storage.images_container_access_key
  images_container_uri        = module.storage.images_container_uri
  storage_account             = module.storage.storage_account
  storage_container           = module.storage.storage_container
  storage_access_key          = module.storage.storage_access_key
  diagnostic_storage_url      = module.storage.diag_storage_blob_endpoint
  vnet_name                   = module.network.virtual_network_name
  nsgID                       = module.network.nsg_id
  subnetID                    = module.network.subnet_workstation.id
  subnet_name                 = module.network.subnet_workstation.name
  vm_size                     = "Standard_NV12s_v3"
  application_id              = var.application_id
  aad_client_secret           = var.aad_client_secret
  tenant_id                   = var.tenant_id
  pcoip_secret_id             = var.pcoip_secret_id
  ad_pass_secret_id           = var.ad_pass_secret_id
  _artifactsLocation          = var._artifactsLocation
  _artifactsLocationSasToken  = var._artifactsLocationSasToken
  tags                        = local.common_tags
  vm_depends_on               = module.cac.cac_created
}

module "persona-3" {
  source = "./modules/persona"

  resource_group_name = azurerm_resource_group.vdi_resource_group.name
  azure_region        = azurerm_resource_group.vdi_resource_group.location

  vm_name                     = local.vm_names[3]
  base_name                   = var.base_name
  pcoip_registration_code     = var.pcoip_registration_code
  domain_name                 = "${var.active_directory_netbios_name}.dns.internal"
  ad_service_account_username = var.ad_admin_username
  ad_service_account_password = var.ad_admin_password
  admin_name                  = var.windows_std_admin_username
  admin_password              = var.windows_std_admin_password
  host_name                   = var.windows_std_hostname
  instance_count              = var.vm_persona == 3 ? local.vm_count : 0
  pcoip_agent_location        = var.pcoip_agent_location
  os_disk_name                = local.workstation_os_disk_name
  data_disk_name              = local.workstation_data_disk_name
  images_storage_account      = module.storage.images_storage_account
  images_container_access_key = module.storage.images_container_access_key
  images_container_uri        = module.storage.images_container_uri
  storage_account             = module.storage.storage_account
  storage_container           = module.storage.storage_container
  storage_access_key          = module.storage.storage_access_key
  diagnostic_storage_url      = module.storage.diag_storage_blob_endpoint
  vnet_name                   = module.network.virtual_network_name
  nsgID                       = module.network.nsg_id
  subnetID                    = module.network.subnet_workstation.id
  subnet_name                 = module.network.subnet_workstation.name
  vm_size                     = "Standard_NV24s_v3"
  application_id              = var.application_id
  aad_client_secret           = var.aad_client_secret
  tenant_id                   = var.tenant_id
  pcoip_secret_id             = var.pcoip_secret_id
  ad_pass_secret_id           = var.ad_pass_secret_id
  _artifactsLocation          = var._artifactsLocation
  _artifactsLocationSasToken  = var._artifactsLocationSasToken
  tags                        = local.common_tags
  vm_depends_on               = module.cac.cac_created
}
