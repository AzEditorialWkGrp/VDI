/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default     = "centralus"
}

variable "resource_group_name" {
  description = "The name of the resource group"
}

variable "storage_account_name" {
  description = "The name of the storage account"
}
