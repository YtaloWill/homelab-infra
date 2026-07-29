provider "proxmox" {
  endpoint = var.pve_endpoint
  # Ticket (username/password) auth, not an API token: PVE's bind-mount
  # permission check compares authuser literally against "root@pam", and a
  # token's authuser is "root@pam!<tokenid>" — it never matches, so bind
  # mounts (mp0 on arr/jellyfin/samba) always 403 under token auth.
  username = var.pve_username
  password = var.pve_password
  # Self-signed PVE certificate on the LAN.
  insecure = var.pve_insecure

  ssh {
    agent    = true
    username = "root"
  }
}
