resource "azurerm_storage_account" "storage-account" {
  name                     = "ss${var.storage_name}${var.deployment_index}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.is_premium_storage == true ? "Premium": "Standard"
  account_replication_type = "LRS"
  account_kind             = var.is_premium_storage == true ? "FileStorage" : "StorageV2"
  access_tier              = "Hot"
  tags                     = merge(var.tags,
    map("Type", "Storage")
  )
}

resource "azurerm_storage_share" "file-share" {
  name                 = "demofileshare"
  storage_account_name =  azurerm_storage_account.storage-account.name

  quota = var.file_share_quota
}

resource "azurerm_storage_account" "diagnostic-storage-account" {
  name                     = "stdiag${var.diag_storage_name}${var.deployment_index}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"
}

resource "azurerm_storage_container" "vm-images-container" {
  name                  = local.images_container_name
  storage_account_name  = azurerm_storage_account.diagnostic-storage-account.name
  container_access_type = "private"
}

resource "null_resource" "copy-assets" {
  depends_on = [azurerm_storage_share.file-share]

  triggers = {
    instance_id = azurerm_storage_share.file-share.id
  }

  provisioner "local-exec" {
    command = "az storage file copy start-batch --destination-share ${azurerm_storage_share.file-share.name} --account-name ${azurerm_storage_account.storage-account.name} --account-key ${azurerm_storage_account.storage-account.primary_access_key} --source-account-name ${var.assets_storage_account} --source-account-key ${var.assets_storage_account_key} --source-share ${var.assets_storage_container}"
  }
}

resource "null_resource" "copy-vm-images" {
  depends_on = [azurerm_storage_container.vm-images-container]

  triggers = {
    instance_id = azurerm_storage_container.vm-images-container.id
  }

  provisioner "local-exec" {
    command = "az storage blob copy start --destination-container ${azurerm_storage_container.vm-images-container.name} --destination-blob ${var.os_disk_name} --account-name ${azurerm_storage_account.diagnostic-storage-account.name} --account-key ${azurerm_storage_account.diagnostic-storage-account.primary_access_key} --source-account-name ${var.assets_storage_account} --source-account-key ${var.assets_storage_account_key} --source-container vdidemoimageprod --source-blob ${var.os_disk_name}"
  }

  provisioner "local-exec" {
    command = "az storage blob copy start --destination-container ${azurerm_storage_container.vm-images-container.name} --destination-blob ${var.data_disk_name} --account-name ${azurerm_storage_account.diagnostic-storage-account.name} --account-key ${azurerm_storage_account.diagnostic-storage-account.primary_access_key} --source-account-name ${var.assets_storage_account} --source-account-key ${var.assets_storage_account_key} --source-container vdidemoimageprod --source-blob ${var.data_disk_name}"
  }
}
