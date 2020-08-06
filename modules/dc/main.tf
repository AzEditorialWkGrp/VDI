/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

data "azurerm_key_vault_secret" "ad-pass" {
  count        = var.key_vault_id != "" ? 1 : 0
  name         = var.ad_pass_secret_name
  key_vault_id = var.key_vault_id
}

data "template_file" "setup-script" {
  template = file("${path.module}/setup.ps1")

  vars = {
    account_name              = var.ad_admin_username
    domain_name               = var.active_directory_domain_name
    safe_mode_admin_password  = var.safe_mode_admin_password
    application_id            = var.application_id
    aad_client_secret         = var.aad_client_secret
    tenant_id                 = var.tenant_id
    safe_admin_pass_secret_id = var.safe_admin_pass_secret_id
    virtual_machine_name      = var.virtual_machine_name
  }
}

data "template_file" "new-domain-users-script" {
  template = file("${path.module}/new_domain_users.ps1")

  vars = {
    domain_name = var.active_directory_domain_name
    csv_file    = local.domain_users_list_file
  }
}

data "template_file" "gpo-script" {
  template = file("${path.module}/gpo.ps1")

  vars = {
    gpo_backups_path            = local.gpo_folder
    gpo_backups_archive_path    = local.gpo_archive
  }
}

data "template_file" "gpo-templates" {
  for_each                 = fileset(path.module, "/files/gpo/**/*.template")
  depends_on               = [var.fs_dependancy]

  template                 = file("${path.module}/${each.key}")
  vars = {
    tf_file_path           = abspath("${path.module}/${each.key}")

    fs_storage_name        = var.fs_stroage_account
    fs_container_name      = var.fs_stroage_container
    fs_account_name        = var.fs_stroage_account
    fs_storage_password    = var.fs_stroage_password
  }
}

resource "azurerm_windows_virtual_machine" "domain-controller" {
  depends_on          = [var.dependency]
  name                = var.virtual_machine_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.dc_machine_type
  admin_username      = var.ad_admin_username
  admin_password      = local.use_secret_or_not.ad_admin_password
  custom_data         = local.custom_data

  network_interface_ids = [
    var.nic_id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  additional_unattend_content {
    content = local.auto_logon_data
    setting = "AutoLogon"
  }

  additional_unattend_content {
    content = local.first_logon_data
    setting = "FirstLogonCommands"
  }
}

resource "azurerm_virtual_machine_extension" "run-sysprep-script" {
  name                 = "create-active-directory-forest"
  virtual_machine_id   = azurerm_windows_virtual_machine.domain-controller.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings           = <<SETTINGS
  {
    "fileUris": ["${var._artifactsLocation}${local.sysprep_filename}"]
  }
SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
  {
    "commandToExecute": "\"${local.powershell_command}\""
  }
PROTECTED_SETTINGS
}

resource "null_resource" "upload-scripts" {
  depends_on = [azurerm_virtual_machine_extension.run-sysprep-script]
  triggers = {
    instance_id = azurerm_windows_virtual_machine.domain-controller.id
  }

  connection {
    type     = "winrm"
    user     = var.ad_admin_username
    password = local.use_secret_or_not.ad_admin_password
    host     = azurerm_windows_virtual_machine.domain-controller.public_ip_address
    port     = "5986"
    https    = true
    insecure = true
  }

  provisioner "file" {
    content     = data.template_file.setup-script.rendered
    destination = local.setup_file
  }

  provisioner "file" {
    content     = data.template_file.new-domain-users-script.rendered
    destination = local.new_domain_users_file
  }
}

resource "local_file" "gpo-templates-process" {
    for_each    = data.template_file.gpo-templates

    content     = each.value.rendered
    filename    = replace(each.value.vars.tf_file_path, ".template", "")
}

data "archive_file" "archive-gpo" {
  depends_on = [local_file.gpo-templates-process]

  type        = "zip"
  output_path = "${path.module}/gpo.zip"

  source_dir = "${path.module}/files/gpo"
}

resource "null_resource" "upload-gpo" {
  depends_on = [null_resource.upload-scripts, data.archive_file.archive-gpo]

  triggers = {
    instance_id = azurerm_windows_virtual_machine.domain-controller.id
  }

  connection {
    type     = "winrm"
    user     = var.ad_admin_username
    password = local.use_secret_or_not.ad_admin_password
    host     = azurerm_windows_virtual_machine.domain-controller.public_ip_address
    port     = "5986"
    https    = true
    insecure = true
  }

  provisioner "file" {
    content     = data.template_file.gpo-script.rendered
    destination = local.gpo_file
  }

  provisioner "file" {
    source      = "${path.module}/gpo.zip"
    destination = local.gpo_archive
  }
}

resource "null_resource" "upload-domain-users-list" {
  depends_on = [azurerm_virtual_machine_extension.run-sysprep-script]
  triggers = {
    instance_id = azurerm_windows_virtual_machine.domain-controller.id
  }

  connection {
    type     = "winrm"
    user     = var.ad_admin_username
    password = local.use_secret_or_not.ad_admin_password
    host     = azurerm_windows_virtual_machine.domain-controller.public_ip_address
    port     = "5986"
    https    = true
    insecure = true
  }

  provisioner "file" {
    source      = "${path.root}/domain_users_list.csv"
    destination = local.domain_users_list_file
  }
}

resource "null_resource" "run-setup-script" {
  depends_on = [null_resource.upload-scripts]
  triggers = {
    instance_id = azurerm_windows_virtual_machine.domain-controller.id
  }

  connection {
    type     = "winrm"
    user     = var.ad_admin_username
    password = local.use_secret_or_not.ad_admin_password
    host     = azurerm_windows_virtual_machine.domain-controller.public_ip_address
    port     = "5986"
    https    = true
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell -file ${local.setup_file}",
      "del ${replace(local.setup_file, "/", "\\")}",
    ]
  }
}

resource "null_resource" "run-gpo-script" {
  depends_on = [null_resource.upload-gpo, null_resource.wait-for-reboot]
  triggers = {
    instance_id = azurerm_windows_virtual_machine.domain-controller.id
  }

  connection {
    type     = "winrm"
    user     = var.ad_admin_username
    password = local.use_secret_or_not.ad_admin_password
    host     = azurerm_windows_virtual_machine.domain-controller.public_ip_address
    port     = "5986"
    https    = true
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell -file ${local.gpo_file}",
      "powershell -file ${local.new_domain_users_file}",
      "del ${replace(local.new_domain_users_file, "/", "\\")}",
      "del ${replace(local.domain_users_list_file, "/", "\\")}",
      "del ${replace(local.gpo_file, "/", "\\")}",
      "del ${replace(local.gpo_archive, "/", "\\")}",
      "rd /S /Q ${replace(local.gpo_folder, "/", "\\")}"
    ]
  }
}


resource "null_resource" "wait-for-reboot" {
  depends_on = [null_resource.run-setup-script]
  triggers = {
    instance_id = azurerm_windows_virtual_machine.domain-controller.id
  }

  provisioner "local-exec" {
    # This command is written this way to make it work regardless of whether the
    # user runs Terraform in Windows (where local-exec is the command prompt) or
    # Linux (where the local-exec is e.g. bash shell).
    command = "sleep 600 || powershell sleep 600"
  }
}

resource "azurerm_template_deployment" "shutdown_schedule_template" {
  name                = "${azurerm_windows_virtual_machine.domain-controller.name}-shutdown-schedule-template"
  resource_group_name = var.resource_group_name
  deployment_mode     = "Incremental"

  parameters = {
    "location"                       = var.location
    "virtualMachineName"             = azurerm_windows_virtual_machine.domain-controller.name
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