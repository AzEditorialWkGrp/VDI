/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "_artifactsLocation" {
  value = "https://${azurerm_storage_account.script.name}.blob.core.windows.net/${azurerm_storage_container.script.name}/"
}
