resource "proxmox_virtual_environment_container" "arr" {
  node_name     = var.node_name
  vm_id         = local.vmid_arr
  description   = "arr media automation stack (k3s + Helm). Managed by OpenTofu."
  tags          = ["homelab", "media"]
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = var.arr_cores
  }

  memory {
    dedicated = var.arr_memory
    swap      = var.arr_swap
  }

  disk {
    datastore_id = var.rootfs_datastore
    size         = var.arr_disk_gb
  }

  # Host-side CIFS mount of //samba/nas (media + configs), see storage.yml.
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

  # k3s/containerd inside an unprivileged CT.
  features {
    nesting = true
  }

  # For gluetun's wireguard tunnel; harmless while gluetun.enabled is false.
  device_passthrough {
    path = "/dev/net/tun"
  }

  initialization {
    hostname = "arr"

    dns {
      servers = var.container_dns
    }

    ip_config {
      ipv4 {
        address = var.arr_ip
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
