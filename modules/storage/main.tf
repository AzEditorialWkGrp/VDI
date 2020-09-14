resource "azurerm_storage_account" "storage-account" {
  name                     = "ss${var.storage_name}${var.index}"
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
  name                     = "stdiag${var.diag_storage_name}${var.index}"
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

data "azurerm_storage_account_sas" "sa_sas" {
  connection_string = azurerm_storage_account.storage-account.primary_connection_string
  https_only        = true

  resource_types {
    service   = false
    container = true
    object    = true
  }

  services {
    blob  = false
    queue = false
    table = false
    file  = true
  }

  start  = formatdate("YYYY-MM-DD", local.today)
  expiry = formatdate("YYYY-MM-DD", timeadd(local.today, "48h"))

  permissions {
    read    = true
    write   = true
    delete  = false
    list    = true
    add     = true
    create  = true
    update  = false
    process = false
  }
}

data "azurerm_storage_account_sas" "diag_sa_sas" {
  connection_string = azurerm_storage_account.diagnostic-storage-account.primary_connection_string
  https_only        = true

  resource_types {
    service   = false
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = formatdate("YYYY-MM-DD", local.today)
  expiry = formatdate("YYYY-MM-DD", timeadd(local.today, "48h"))

  permissions {
    read    = true
    write   = true
    delete  = false
    list    = false
    add     = true
    create  = true
    update  = false
    process = false
  }
}

resource "null_resource" "copy-vm-images" {
  depends_on = [azurerm_storage_container.vm-images-container]

  triggers = {
    instance_id = azurerm_storage_container.vm-images-container.id
  }

  provisioner "local-exec" {
    command = "--recursive"
    interpreter = [
      "azcopy", "copy",
      "https://${var.assets_storage_account}.file.core.windows.net/${var.assets_storage_container}/*${var.assets_storage_account_key}",
      "https://${azurerm_storage_account.storage-account.name}.file.core.windows.net/${azurerm_storage_share.file-share.name}/${data.azurerm_storage_account_sas.sa_sas.sas}"
    ]
  }

  provisioner "local-exec" {
    command = "--recursive"
    interpreter = [
      "azcopy", "copy",
      "https://${var.assets_storage_account}.blob.core.windows.net/${var.images_storage_container}/${var.os_disk_name}${var.assets_storage_account_key}",
      "https://${azurerm_storage_account.diagnostic-storage-account.name}.blob.core.windows.net/${azurerm_storage_container.vm-images-container.name}/${var.os_disk_name}${data.azurerm_storage_account_sas.diag_sa_sas.sas}"
    ]
  }

  provisioner "local-exec" {
    command = "--recursive"
    interpreter = [
      "azcopy", "copy",
      "https://${var.assets_storage_account}.blob.core.windows.net/${var.images_storage_container}/${var.data_disk_name}${var.assets_storage_account_key}",
      "https://${azurerm_storage_account.diagnostic-storage-account.name}.blob.core.windows.net/${azurerm_storage_container.vm-images-container.name}/${var.data_disk_name}${data.azurerm_storage_account_sas.diag_sa_sas.sas}"
    ]
  }
}
