resource "proxmox_virtual_environment_container" "jellyfin" {
  node_name     = var.node_name
  vm_id         = local.vmid_jellyfin
  description   = "Jellyfin media server (k3s + Helm). Managed by OpenTofu."
  tags          = ["homelab", "media"]
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = var.jellyfin_cores
  }

  memory {
    dedicated = var.jellyfin_memory
    swap      = var.jellyfin_swap
  }

  disk {
    datastore_id = var.rootfs_datastore
    size         = var.jellyfin_disk_gb
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

  # k3s/containerd inside an unprivileged CT (same as arr — keyctl isn't
  # needed for k3s/containerd, only Docker).
  features {
    nesting = true
  }

  # iGPU render nodes for QSV hardware transcoding, hostPath-mounted into the
  # jellyfin pod. World-rw mode sidesteps needing to know the pod's
  # render/video gid in advance — the gid=993/44 seen on the old Debian box
  # isn't guaranteed to match a freshly created Alpine CT.
  device_passthrough {
    path = "/dev/dri/renderD128"
    mode = "0666"
  }

  device_passthrough {
    path = "/dev/dri/card1"
    mode = "0666"
  }

  initialization {
    hostname = "jellyfin"

    dns {
      servers = var.container_dns
    }

    ip_config {
      ipv4 {
        address = var.jellyfin_ip
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
