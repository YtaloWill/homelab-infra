variable "pve_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://192.168.15.101:8006"
}

variable "pve_username" {
  description = "PVE login for ticket auth, e.g. root@pam (bind mounts require a root@pam ticket, not an API token)"
  type        = string
  default     = "root@pam"
}

variable "pve_password" {
  description = "PVE password for pve_username (ticket auth)"
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

variable "pve_ssh_private_key_file" {
  description = "Private key for root@<pve host> used by the hdd80_postgres_dir provisioner (databases.tf) — agent forwarding isn't assumed to be set up wherever tofu apply runs"
  type        = string
  default     = "~/.ssh/id_ed25519"
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

variable "hdd500_host_path" {
  description = "Host path of the migrated NAS data — a subdirectory of the hdd-500 storage, not its bare root, so PVE's own images/template/dump folders on that storage don't end up inside the samba share (see tasks.md 4.3)"
  type        = string
  default     = "/mnt/pve/hdd-500/nas"
}

variable "samba_export_path" {
  description = "Path inside PCT 150 where hdd-500 is bind-mounted (samba share root)"
  type        = string
  default     = "/srv/nas"
}

variable "hdd80_host_path" {
  description = "Host path of the databases container's disk — a subdirectory of hdd-80, not its bare root, same reasoning as hdd500_host_path"
  type        = string
  default     = "/mnt/pve/hdd-80/postgres"
}

variable "databases_export_path" {
  description = "Path inside PCT 151 where hdd-80 is bind-mounted"
  type        = string
  default     = "/srv/data"
}

variable "host_cifs_mount" {
  description = "PVE host mountpoint of //samba/nas, bind-mounted into consumer CTs (see ansible/playbooks/storage.yml)"
  type        = string
  default     = "/mnt/samba"
}

# --- per-container tuning ------------------------------------------------
# Sizes target each service's own recommended requirements (not whatever the
# pre-IaC containers happened to drift into — see design decision 4).

variable "jellyfin_ip" {
  type    = string
  default = "192.168.15.102/24"
}

# Matches k3s's own documented server minimum (2 cores). QSV hardware
# transcoding (device_passthrough) offloads the actual transcode work to the
# iGPU, so jellyfin itself stays light on top of that.
variable "jellyfin_cores" {
  type    = number
  default = 2
}

# Jellyfin's own hardware guide recommends ~8G for a general deployment;
# 4G here trades that down given GPU-offloaded transcode + homelab-scale
# concurrent streams, plus k3s server overhead (~700 MB, design decision 8).
variable "jellyfin_memory" {
  type    = number
  default = 4096
}

variable "jellyfin_swap" {
  type    = number
  default = 512
}

# k3s + containerd image layers + local transcode cache (kept off the samba
# share for performance, requirement 5.2) need more than a bare native
# install would.
variable "jellyfin_disk_gb" {
  type    = number
  default = 16
}

variable "arr_ip" {
  type    = string
  default = "192.168.15.103/24"
}

variable "arr_cores" {
  type    = number
  default = 4
}

# k3s server alone needs ~2G; 7 app pods (prowlarr, qbittorrent, radarr,
# sonarr, bazarr, jellyseerr, flaresolverr) on top push 4G into eviction
# territory (design decision 8) — 6G is the recommended headroom.
variable "arr_memory" {
  type    = number
  default = 6144
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

variable "bookorbit_ip" {
  type    = string
  default = "192.168.15.105/24"
}

variable "bookorbit_cores" {
  type    = number
  default = 2
}

# k3s server overhead (~700 MB) + BookOrbit's own Node heap ceiling
# (NODE_MAX_OLD_SPACE_SIZE defaults to 2048 MB) — lighter than jellyfin_memory
# since there's no local Postgres or transcoding.
variable "bookorbit_memory" {
  type    = number
  default = 2560
}

variable "bookorbit_swap" {
  type    = number
  default = 512
}

variable "bookorbit_disk_gb" {
  type    = number
  default = 10
}

variable "databases_ip" {
  type    = string
  default = "192.168.15.151/24"
}

variable "databases_cores" {
  type    = number
  default = 2
}

variable "databases_memory" {
  type    = number
  default = 2048
}

variable "databases_swap" {
  type    = number
  default = 512
}

# k3s + CNPG operator + Postgres image layers only — the real data lives on
# the hdd-80 bind mount, not the rootfs.
variable "databases_disk_gb" {
  type    = number
  default = 8
}

locals {
  vmid_jellyfin  = 100
  vmid_arr       = 101
  vmid_bookorbit = 102
  vmid_proxy     = 104
  vmid_samba     = 150
  vmid_databases = 151
}
