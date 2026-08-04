resource "proxmox_virtual_environment_container" "bookorbit" {
  node_name     = var.node_name
  vm_id         = local.vmid_bookorbit
  description   = "BookOrbit ebook/audiobook library server (k3s + Helm). Managed by OpenTofu."
  tags          = ["homelab", "media"]
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = var.bookorbit_cores
  }

  memory {
    dedicated = var.bookorbit_memory
    swap      = var.bookorbit_swap
  }

  disk {
    datastore_id = var.rootfs_datastore
    size         = var.bookorbit_disk_gb
  }

  # Host-side CIFS mount of //samba/nas (books media + app-data config),
  # same bind every consumer container uses (see storage.yml).
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

  # k3s/containerd inside an unprivileged CT (same as jellyfin/arr — keyctl
  # isn't needed for k3s/containerd, only Docker).
  features {
    nesting = true
  }

  initialization {
    hostname = "bookorbit"

    dns {
      servers = var.container_dns
    }

    ip_config {
      ipv4 {
        address = var.bookorbit_ip
        gateway = var.gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  startup {
    order = 20
  }

  lifecycle {
    prevent_destroy = true
  }
}
