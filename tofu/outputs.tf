output "containers" {
  description = "Managed containers: vmid and static address"
  value = {
    jellyfin  = { vmid = local.vmid_jellyfin, ip = var.jellyfin_ip }
    arr       = { vmid = local.vmid_arr, ip = var.arr_ip }
    samba     = { vmid = local.vmid_samba, ip = var.samba_ip }
    proxy     = { vmid = local.vmid_proxy, ip = var.proxy_ip }
    bookorbit = { vmid = local.vmid_bookorbit, ip = var.bookorbit_ip }
    databases = { vmid = local.vmid_databases, ip = var.databases_ip }
    homepage  = { vmid = local.vmid_homepage, ip = var.homepage_ip }
  }
}
