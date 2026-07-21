resource "proxmox_virtual_environment_container" "proxy" {
  node_name     = var.node_name
  vm_id         = local.vmid_proxy
  description   = "Traefik + dnsmasq: *.local DNS and reverse proxy. Managed by OpenTofu."
  tags          = ["homelab", "network"]
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = var.proxy_cores
  }

  memory {
    dedicated = var.proxy_memory
    swap      = var.proxy_swap
  }

  disk {
    datastore_id = var.rootfs_datastore
    size         = var.proxy_disk_gb
  }

  # Deliberately no NAS mount: DNS/proxy must not depend on the samba CT.

  network_interface {
    name   = "eth0"
    bridge = var.bridge
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.alpine.id
    type             = "alpine"
  }

  initialization {
    hostname = "proxy"

    dns {
      servers = var.container_dns
    }

    ip_config {
      ipv4 {
        address = var.proxy_ip
        gateway = var.gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  startup {
    order = 15
  }
}
