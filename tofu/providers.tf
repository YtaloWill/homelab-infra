provider "proxmox" {
  endpoint  = var.pve_endpoint
  api_token = var.pve_api_token
  # Self-signed PVE certificate on the LAN.
  insecure = var.pve_insecure

  ssh {
    agent    = true
    username = "root"
  }
}
