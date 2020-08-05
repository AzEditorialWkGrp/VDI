terraform {
  required_version = ">= 0.12"
}

provider "azurerm" {
  version = "=2.2.0"

  features {}
}

provider "random" {
  version = "=2.2.1"
}

provider "restapi" {
  version = "1.13.0"
  uri                  = "https://cam.teradici.com/api/v1/"
  debug                = true
  write_returns_object = true
  rate_limit           = 0.25
  headers              = {
    Content-Type       = "application/json"
    Authorization      = "${var.cam_service_token}"
  }
}