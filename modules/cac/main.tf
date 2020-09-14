/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

resource "azurerm_virtual_machine" "cac" {
  depends_on = [var.dns_zone_id, var.vm_depends_on]

  name                  = var.virtual_machine_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [var.nic_id, ]
  vm_size               = var.machine_type

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = var.disk_size_gb
  }

  os_profile {
    computer_name  = var.host_name
    admin_username = var.cac_admin_user
    admin_password = var.cac_admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
    /*ssh_keys {
        key_data = file("${path.module}/id_rsa.pub") # Azure VM only supports RSA SSH2 with at least 2048 bits
        path     = "/home/${var.cac_admin_user}/.ssh/authorized_keys"
    }*/
  }
}

resource "null_resource" "upload-scripts" {
  depends_on = [azurerm_virtual_machine.cac]

  connection {
    type     = "ssh"
    user     = var.cac_admin_user
    password = var.cac_admin_password
    host     = var.cac_ip
    port     = "22"
    #private_key = file("${path.module}/tera_private_key.ppk")
  }

  provisioner "file" {
    content     = local.templatefile
    destination = "/home/${var.cac_admin_user}/cac-startup.sh"
  }
}

resource "null_resource" "cac-startup-script" {
  triggers = {
    instance_id = null_resource.upload-scripts.id
  }

  connection {
    type     = "ssh"
    user     = var.cac_admin_user
    password = var.cac_admin_password
    host     = var.cac_ip
    port     = "22"
    #private_key = file("${path.module}/tera_private_key.ppk")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo rm /var/lib/apt/lists/*",
      "sudo apt -y update",
      "sudo lsof /var/lib/dpkg/lock-frontend",
      "sudo apt install dos2unix",
      "if [ $? -eq 1 ]; then sudo lsof /var/lib/dpkg/lock-frontend; sudo apt install dos2unix; fi",
      "sudo dos2unix ${local.startup_cac_filename}",
      "sudo bash ${local.startup_cac_filename}",
    ]
  }
}
