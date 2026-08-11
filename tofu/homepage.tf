resource "proxmox_virtual_environment_container" "homepage" {
  node_name     = var.node_name
  vm_id         = local.vmid_homepage
  description   = "Fleet dashboard (gethomepage/homepage, k3s + Helm). Managed by OpenTofu."
  tags          = ["homelab", "tools"]
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = var.homepage_cores
  }

  memory {
    dedicated = var.homepage_memory
    swap      = var.homepage_swap
  }

  disk {
    datastore_id = var.rootfs_datastore
    size         = var.homepage_disk_gb
  }

  # Host-side CIFS mount of //samba/nas — Homepage's /app/config hostPath
  # (Requirement 12.3), same bind every consumer container uses (see
  # storage.yml).
  mount_point {
    volume = var.host_cifs_mount
    path   = "/mnt/samba"
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.alpine.id
    type             = "alpine"
  }

  # k3s/containerd inside an unprivileged CT (same as jellyfin/arr/bookorbit).
  features {
    nesting = true
  }

  initialization {
    hostname = "homepage"

    dns {
      servers = var.container_dns
    }

    ip_config {
      ipv4 {
        address = var.homepage_ip
        gateway = var.gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  startup {
    order = 25
  }

  lifecycle {
    prevent_destroy = true
  }
}
