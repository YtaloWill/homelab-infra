variable "pve_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://192.168.15.101:8006"
}

variable "pve_api_token" {
  description = "API token (root@pam! — bind mounts require root)"
  type        = string
  sensitive   = true
}

variable "pve_insecure" {
  description = "Skip TLS verification (self-signed PVE cert)"
  type        = bool
  default     = true
}

variable "node_name" {
  description = "Proxmox node name — verify with: pvesh get /nodes"
  type        = string
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "gateway" {
  type    = string
  default = "192.168.15.1"
}

variable "container_dns" {
  description = "DNS servers for containers (upstream; LAN clients use the proxy CT instead)"
  type        = list(string)
  default     = ["192.168.15.1"]
}

variable "ssh_public_keys" {
  description = "Public keys installed for root in every container"
  type        = list(string)
}

variable "rootfs_datastore" {
  description = "LVM-thin datastore for container rootfs"
  type        = string
  default     = "local-lvm"
}

variable "template_datastore" {
  description = "Directory datastore for LXC templates"
  type        = string
  default     = "local"
}

# Verify current filenames with: pveam update && pveam available --section system
variable "alpine_template_url" {
  type    = string
  default = "http://download.proxmox.com/images/system/alpine-3.21-default_20241217_amd64.tar.xz"
}

variable "debian_template_url" {
  type    = string
  default = "http://download.proxmox.com/images/system/debian-12-standard_12.7-1_amd64.tar.zst"
}

variable "hdd500_host_path" {
  description = "Host path of the hdd-500 directory storage (NAS data)"
  type        = string
  default     = "/mnt/pve/hdd-500"
}

variable "samba_export_path" {
  description = "Path inside PCT 150 where hdd-500 is bind-mounted (samba share root)"
  type        = string
  default     = "/srv/nas"
}

variable "host_cifs_mount" {
  description = "PVE host mountpoint of //samba/nas, bind-mounted into consumer CTs (see ansible/playbooks/storage.yml)"
  type        = string
  default     = "/mnt/samba"
}

# --- per-container tuning ------------------------------------------------
# Defaults for 100/101/150 are assumptions; align with `pct config <id>`
# before first apply so the imported plan is clean (see spec tasks 4.1/4.4).

variable "jellyfin_ip" {
  type    = string
  default = "192.168.15.102/24"
}

variable "jellyfin_cores" {
  type    = number
  default = 2
}

variable "jellyfin_memory" {
  type    = number
  default = 2048
}

variable "jellyfin_swap" {
  type    = number
  default = 512
}

variable "jellyfin_disk_gb" {
  type    = number
  default = 8
}

variable "arr_ip" {
  type    = string
  default = "192.168.15.103/24"
}

variable "arr_cores" {
  type    = number
  default = 4
}

variable "arr_memory" {
  type    = number
  default = 4096
}

variable "arr_swap" {
  type    = number
  default = 512
}

variable "arr_disk_gb" {
  description = "Docker images live here — keep headroom"
  type        = number
  default     = 12
}

variable "samba_ip" {
  type    = string
  default = "192.168.15.150/24"
}

variable "samba_cores" {
  type    = number
  default = 4
}

variable "samba_memory" {
  type    = number
  default = 2048
}

variable "samba_swap" {
  type    = number
  default = 512
}

variable "samba_disk_gb" {
  type    = number
  default = 4
}

variable "proxy_ip" {
  type    = string
  default = "192.168.15.104/24"
}

variable "proxy_cores" {
  type    = number
  default = 1
}

variable "proxy_memory" {
  type    = number
  default = 512
}

variable "proxy_swap" {
  type    = number
  default = 512
}

variable "proxy_disk_gb" {
  type    = number
  default = 2
}

locals {
  vmid_jellyfin = 100
  vmid_arr      = 101
  vmid_proxy    = 104
  vmid_samba    = 150
}
