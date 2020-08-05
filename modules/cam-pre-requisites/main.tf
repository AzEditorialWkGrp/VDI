data "template_file" "data_cam_service_account" {
  depends_on = [var.dependency]
  template = file("${path.module}/data/service-account.json")

  vars = {
    azure_client_id       = var.client_id
    azure_client_secret   = var.client_secret
    azure_tenant_id       = var.tenant_id
    azure_subscription_id = var.subscription_id
  }
}

data "template_file" "data_cam_connector" {
  template = file("${path.module}/data/connector.json")

  vars = {
    deployment_id       = var.deployment_id
    connector_name      = local.connector_name
  }
}

resource "restapi_object" "cam_cloud_service_account" {
  path = "/deployments/${var.deployment_id}/cloudServiceAccounts"

  id_attribute = "data/id"
  data         = data.template_file.data_cam_service_account.rendered
}

resource "restapi_object" "cam_connector" {
  path = "/auth/tokens/connector"
  id_attribute = "data/token"
  data         = data.template_file.data_cam_connector.rendered
}
