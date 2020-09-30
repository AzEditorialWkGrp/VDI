output "storage_account" {
  value = azurerm_storage_account.storage-account.name
}

output "storage_account_id" {
  value = azurerm_storage_account.storage-account.id
}

output "storage_container" {
  value = azurerm_storage_share.file-share.name
}

output "storage_access_key" {
  value = azurerm_storage_account.storage-account.primary_access_key
}

output "diag_storage_blob_endpoint" {
  value = azurerm_storage_account.diagnostic-storage-account.primary_blob_endpoint
}

output "images_storage_account" {
  value = azurerm_storage_account.diagnostic-storage-account.name
}

output "images_container_access_key" {
  value = azurerm_storage_account.diagnostic-storage-account.primary_access_key
}

output "images_container_uri" {
  value = "${azurerm_storage_account.diagnostic-storage-account.primary_blob_endpoint}${local.images_container_name}"
  depends_on = [null_resource.copy-vm-images]
}

output "storage_created" {
    value      = {}
    depends_on = [azurerm_storage_share.file-share, null_resource.copy-vm-images]
}
