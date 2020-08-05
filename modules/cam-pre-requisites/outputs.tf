output "connector_name" {
  value = local.connector_name
}

output "cac_token" {
  value = restapi_object.cam_connector.id
}

output "service_account_created" {
    value      = {}
    depends_on = [restapi_object.cam_cloud_service_account]
}