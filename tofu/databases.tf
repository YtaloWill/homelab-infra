# PVE never auto-creates a mount_point's source path (pct create 403s
# otherwise). Unlike /mnt/samba and hdd-500 (created manually per tasks.md
# 4.4a, before this repo automated anything), hdd-80 is new with no
# existing manual-setup step to preserve — create it here via the
# provider's own SSH fallback (already configured in providers.tf) so
# `tofu apply` is self-contained.
resource "null_resource" "hdd80_postgres_dir" {
  triggers = {
    path = var.hdd80_host_path
  }

  connection {
    type        = "ssh"
    host        = regex("https?://([^:/]+)", var.pve_endpoint)[0]
    user        = "root"
    private_key = file(pathexpand(var.pve_ssh_private_key_file))
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p ${var.hdd80_host_path}"]
  }
}

resource "proxmox_virtual_environment_container" "databases" {
  depends_on = [null_resource.hdd80_postgres_dir]

  node_name     = var.node_name
  vm_id         = local.vmid_databases
  description   = "Database tier - CloudNativePG on k3s, hdd-80-backed. Managed by OpenTofu."
  tags          = ["homelab", "storage"]
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = var.databases_cores
  }

  memory {
    dedicated = var.databases_memory
    swap      = var.databases_swap
  }

  disk {
    datastore_id = var.rootfs_datastore
    size         = var.databases_disk_gb
  }

  # hdd-80 directory storage, bind-mounted directly (not CIFS) — Postgres
  # data doesn't tolerate network-filesystem locking, same mechanism
  # samba.tf uses to bind hdd-500 into PCT 150.
  mount_point {
    volume = var.hdd80_host_path
    path   = var.databases_export_path
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
    hostname = "databases"

    dns {
      servers = var.container_dns
    }

    ip_config {
      ipv4 {
        address = var.databases_ip
        gateway = var.gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  startup {
    order = 12
  }

  lifecycle {
    # Holds real Postgres data (hdd-80 bind) — a destructive plan must fail.
    prevent_destroy = true
  }
}
