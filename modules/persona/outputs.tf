/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "internal-ip" {
  value = "${azurerm_template_deployment.windows[*].outputs.private-ip}"
}

output "workstations" {
  value = azurerm_template_deployment.windows
}