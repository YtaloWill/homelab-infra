resource "proxmox_virtual_environment_download_file" "alpine" {
  node_name    = var.node_name
  datastore_id = var.template_datastore
  content_type = "vztmpl"
  url          = var.alpine_template_url
  overwrite    = false
}

resource "proxmox_virtual_environment_download_file" "debian12" {
  node_name    = var.node_name
  datastore_id = var.template_datastore
  content_type = "vztmpl"
  url          = var.debian_template_url
  overwrite    = false
}
