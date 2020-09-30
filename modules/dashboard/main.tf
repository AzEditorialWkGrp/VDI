resource "azurerm_dashboard" "dashboard" {
  name                = "Demo-Dashboard"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  dashboard_properties = templatefile("${path.module}/dashboard-properties.json",
    {
        resource_group_id          = var.resource_group_id
        resource_group_name        = var.resource_group_name
        location                   = var.location

        storage_account_id         = var.storage_account_id
        storage_account_name       = var.storage_account_name

        subscription_id            = var.subscription_id
        subscription_display_name  = var.subscription_display_name
    }
  )
}