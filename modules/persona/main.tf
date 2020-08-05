/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

resource "null_resource" "wait-for-images" {
  depends_on      = [var.vm_depends_on]

  provisioner "local-exec" {
    command = "VdiVhdWatcher --name ${var.images_storage_account} --container vm-images --access-key ${var.images_container_access_key} --blob ${var.os_disk_name} --blob ${var.data_disk_name}"
  }
}

resource "azurerm_image" "workstation" {
  depends_on      = [var.vm_depends_on, null_resource.wait-for-images]

  name                = "ARMTemplate-windows-std-image"
  location            = var.azure_region
  resource_group_name = var.resource_group_name

  os_disk {
    os_type  = "Windows"
    os_state = "Generalized"
    blob_uri = "${var.images_container_uri}/${var.os_disk_name}"
  }

  data_disk {
    blob_uri = "${var.images_container_uri}/${var.data_disk_name}"
    lun = 0
  }
}

resource "azurerm_template_deployment" "windows" {
  count               = var.instance_count
  name                = "ARMTemplate-windows-std-${count.index}"
  resource_group_name = var.resource_group_name
  template_body       = file("${path.module}/mainTemplate.json")
  parameters = {
    "base_name"                   = "${var.base_name}"
    "count_index"                 = "${format("%02d", count.index + 1)}"
    "location"                    = "${var.azure_region}"
    "vmSize"                      = "${var.vm_size}"
    "application_id"              = "${var.application_id}"
    "aad_client_secret"           = "${var.aad_client_secret}"
    "tenant_id"                   = "${var.tenant_id}"
    "pcoip_secret_id"             = "${var.pcoip_secret_id}"
    "ad_pass_secret_id"           = "${var.ad_pass_secret_id}"
    "ad_service_account_password" = "${var.ad_service_account_password}"
    "ad_service_account_username" = "${var.ad_service_account_username}"
    "domain_name"                 = "${var.domain_name}"
    "vmName"                      = "${var.vm_name}-${format("%02d", count.index + 1)}"
    "nsgID"                       = "${var.nsgID}"
    "subnetID"                    = "${var.subnetID}"
    "adminName"                   = "${var.admin_name}"
    "adminPass"                   = "${var.admin_password}"
    "storage_account"             = "${var.storage_account}"
    "storage_container"           = "${var.storage_container}"
    "storage_access_key"          = "${var.storage_access_key}"
    "diagnostic_storage_url"      = "${var.diagnostic_storage_url}"
    "TeradiciRegKey"              = "${var.pcoip_registration_code}"
    "_artifactsLocation"          = "${var._artifactsLocation}"
    "_artifactsLocationSasToken"  = "${var._artifactsLocationSasToken}"
    image_id                      = azurerm_image.workstation.id
    "pcoip_agent_exe"             = "pcoip-agent-graphics_20.07.0.exe"
    "vmTags"                      = "${jsonencode(merge(var.tags, map(
        "Type", "workstation",
        "OS", "Windows10",
        "Build", "2004"
    )))}"
  }
  deployment_mode = "Incremental"
  depends_on      = [var.vm_depends_on, azurerm_image.workstation]
}

resource "azurerm_template_deployment" "shutdown_schedule_template" {
  count               = var.instance_count
  name                = "${var.base_name}-${var.host_name}-shutdown-schedule-template-${count.index}"
  resource_group_name = var.resource_group_name
  deployment_mode     = "Incremental"

  parameters = {
    "location"                       = var.azure_region
    "virtualMachineName"             = element(azurerm_template_deployment.windows.*.parameters.vmName, count.index)
    "autoShutdownStatus"             = "Enabled"
    "autoShutdownTime"               = "18:00"
    "autoShutdownTimeZone"           = "Pacific Standard Time"
    "autoShutdownNotificationStatus" = "Disabled"
    "autoShutdownNotificationLocale" = "en"
  }

  template_body = <<DEPLOY
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
      "parameters": {
          "location": {
              "type": "string"
          },
          "virtualMachineName": {
              "type": "string"
          },
          "autoShutdownStatus": {
              "type": "string"
          },
          "autoShutdownTime": {
              "type": "string"
          },
          "autoShutdownTimeZone": {
              "type": "string"
          },
          "autoShutdownNotificationStatus": {
              "type": "string"
          },
          "autoShutdownNotificationLocale": {
              "type": "string"
          }
      },
      "resources": [
        {
            "name": "[concat('shutdown-computevm-', parameters('virtualMachineName'))]",
            "type": "Microsoft.DevTestLab/schedules",
            "apiVersion": "2018-09-15",
            "location": "[parameters('location')]",
            "properties": {
                "status": "[parameters('autoShutdownStatus')]",
                "taskType": "ComputeVmShutdownTask",
                "dailyRecurrence": {
                    "time": "[parameters('autoShutdownTime')]"
                },
                "timeZoneId": "[parameters('autoShutdownTimeZone')]",
                "targetResourceId": "[resourceId('Microsoft.Compute/virtualMachines', parameters('virtualMachineName'))]",
                "notificationSettings": {
                    "status": "[parameters('autoShutdownNotificationStatus')]",
                    "notificationLocale": "[parameters('autoShutdownNotificationLocale')]",
                    "timeInMinutes": "30"
                }
            }
        }
    ]
  }
  DEPLOY
}