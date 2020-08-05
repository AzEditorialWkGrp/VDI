output "cac_created" {
    value      = {}
    depends_on = [null_resource.cac-startup-script]
}