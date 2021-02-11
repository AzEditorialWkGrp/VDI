/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

data "azurerm_resource_group" "script" {
  name = var.resource_group_name
}

resource "azurerm_storage_account" "script" {
  name                     = var.storage_account_name
  resource_group_name      = data.azurerm_resource_group.script.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "script" {
  depends_on            = [azurerm_storage_account.script]
  name                  = "${var.storage_account_name}container"
  storage_account_name  = azurerm_storage_account.script.name
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "script" {
  depends_on             = [azurerm_storage_container.script]
  name                   = "${var.storage_account_name}blob"
  storage_account_name   = azurerm_storage_account.script.name
  storage_container_name = azurerm_storage_container.script.name
  type                   = "Block"
}

resource "azurerm_storage_blob" "sysprep-script" {
  depends_on             = [azurerm_storage_container.script]
  name                   = "sysprep.ps1"
  storage_account_name   = azurerm_storage_account.script.name
  storage_container_name = azurerm_storage_container.script.name
  type                   = "Block"
  source                 = "${path.module}/sysprep.ps1" 
}

resource "azurerm_storage_blob" "centos-std-script" {
  depends_on             = [azurerm_storage_container.script]
  name                   = "centos-std-startup.sh"
  storage_account_name   = azurerm_storage_account.script.name
  storage_container_name = azurerm_storage_container.script.name
  type                   = "Block"
  source                 = "${path.module}/centos-std-startup.sh" 
}

resource "azurerm_storage_blob" "windows-std-script" {
  depends_on             = [azurerm_storage_container.script]
  name                   = "DeployPCoIPAgent.ps1"
  storage_account_name   = azurerm_storage_account.script.name
  storage_container_name = azurerm_storage_container.script.name
  type                   = "Block"
  source                 = "${path.module}/DeployPCoIPAgent.ps1" 
}

resource "azurerm_storage_blob" "pcoip-agent" {
  depends_on             = [azurerm_storage_container.script]
  name                   = "pcoip-agent-graphics_21.01.2.exe"
  storage_account_name   = azurerm_storage_account.script.name
  storage_container_name = azurerm_storage_container.script.name
  type                   = "Block"
  source                 = "${path.module}/pcoip-agent-graphics_21.01.2.exe"
}

resource "azurerm_storage_blob" "background-img" {
  depends_on             = [azurerm_storage_container.script]
  name                   = "img0.jpg"
  storage_account_name   = azurerm_storage_account.script.name
  storage_container_name = azurerm_storage_container.script.name
  type                   = "Block"
  source                 = "${path.module}/img0.jpg" 
}