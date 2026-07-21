resource "proxmox_virtual_environment_container" "samba" {
  node_name     = var.node_name
  vm_id         = local.vmid_samba
  description   = "Samba NAS - all bulk data and service configs (hdd-500). Managed by OpenTofu."
  tags          = ["homelab", "storage"]
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = var.samba_cores
  }

  memory {
    dedicated = var.samba_memory
    swap      = var.samba_swap
  }

  disk {
    datastore_id = var.rootfs_datastore
    size         = var.samba_disk_gb
  }

  # hdd-500 directory storage: the entire NAS payload lives here.
  mount_point {
    volume = var.hdd500_host_path
    path   = var.samba_export_path
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.alpine.id
    type             = "alpine"
  }

  initialization {
    hostname = "samba"

    dns {
      servers = var.container_dns
    }

    ip_config {
      ipv4 {
        address = var.samba_ip
        gateway = var.gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  startup {
    order = 10
  }

  lifecycle {
    # Imported container holding all data — a destructive plan must fail.
    prevent_destroy = true
    # Template lineage of an imported CT is unknowable; without this the
    # provider would propose replacement.
    ignore_changes = [operating_system]
  }
}
