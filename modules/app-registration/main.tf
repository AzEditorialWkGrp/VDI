resource "azuread_application" "vdi-application" {
  name                       = "${var.application_name}-service-principal"
  available_to_other_tenants = false
}

resource "azuread_service_principal" "vdi-service-principal" {
  application_id               = azuread_application.vdi-application.application_id
  app_role_assignment_required = false
}

resource "random_password" "vdi-service-principal-password" {
  length = 34
  special = true
}

resource "azuread_application_password" "vdi-service-principal-app-secret" {
  application_object_id = azuread_application.vdi-application.object_id
  value                 = random_password.vdi-service-principal-password.result
  end_date              = "2040-01-01T00:00:00Z"
}

resource "azurerm_role_assignment" "vdi-role-assignment" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azuread_service_principal.vdi-service-principal.object_id
}