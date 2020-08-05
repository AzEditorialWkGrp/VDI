# Used instad of data restapi_object beacause restapi_object sends additional broken request to fetch the object by id
data "http" "users" {
  depends_on = [var.workstations]
  url = "https://cam.teradici.com/api/v1/machines/entitlements/adusers?deploymentId=${var.cam_deployment_id}&limit=100"

  request_headers = {
    Accept              = "application/json"
    Authorization      = "${var.cam_service_token}"
  }
}

data "restapi_object" "connector" {
  depends_on = [var.workstations]

  path           = "/deployments/connectors"
  query_string   = "deploymentId=${var.cam_deployment_id}"
  search_key     = "connectorName"
  search_value   = var.cam_connector_name
  results_key    = "data"
  id_attribute   = "connectorId"
}

data "template_file" "data_machine" {
  count = var.vm_count

  template = file("${path.module}/data/machine.json")
  vars = {
    azure_subscription_id = var.azure_subscription_id
    azure_resource_group  = var.azure_resource_group
    cam_deployment_id     = var.cam_deployment_id
    cam_connector_id      = data.restapi_object.connector.id
    machine_name          = "${var.vm_name}-${format("%02d", count.index + 1)}"
  }
}

data "template_file" "data_entitlement" {
  count = length(restapi_object.machine)

  template = file("${path.module}/data/entitlement.json")
  vars = {
    machine_id = restapi_object.machine[count.index].id
    user_guid  = local.users_map[local.users[count.index].username]
  }
}

resource "restapi_object" "machine" {
  path = "/machines"
  count = length(data.template_file.data_machine)

  id_attribute = "data/machineId"
  data         = data.template_file.data_machine[count.index].rendered
}

resource "restapi_object" "entitlement" {
  path = "/deployments/${var.cam_deployment_id}/entitlements"
  count = length(data.template_file.data_entitlement)

  id_attribute = "data/entitlementId"
  data         = data.template_file.data_entitlement[count.index].rendered
}