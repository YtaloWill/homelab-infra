output "containers" {
  description = "Managed containers: vmid and static address"
  value = {
    jellyfin = { vmid = local.vmid_jellyfin, ip = var.jellyfin_ip }
    arr      = { vmid = local.vmid_arr, ip = var.arr_ip }
    samba    = { vmid = local.vmid_samba, ip = var.samba_ip }
    proxy    = { vmid = local.vmid_proxy, ip = var.proxy_ip }
  }
}
