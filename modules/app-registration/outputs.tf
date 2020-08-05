output "client_id" {
  depends_on = [azurerm_role_assignment.vdi-role-assignment]
  value      = "${azuread_application.vdi-application.application_id}"
}

output "client_secret" {
  depends_on = [azurerm_role_assignment.vdi-role-assignment]
  value      = "${random_password.vdi-service-principal-password.result}"
}

output "app_registration_created" {
    value      = {}
    depends_on = [azurerm_role_assignment.vdi-role-assignment]
}