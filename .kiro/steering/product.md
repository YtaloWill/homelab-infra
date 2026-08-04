# Product — what this homelab is

A single-node Proxmox homelab on a Dell Latitude 7310 laptop serving one
household's media stack, fully reproducible from this repository.

## Services

| Service       | Where            | Purpose                                  |
|---------------|------------------|------------------------------------------|
| Jellyfin      | PCT 100          | Media streaming server                    |
| arr stack     | PCT 101 (k3s + Helm) | prowlarr, qbittorrent, flaresolverr, radarr, sonarr, bazarr, jellyseerr |
| gluetun       | PCT 101 (k3s, optional `gluetun.enabled`) | Independent VPN egress proxy (:8888); apps opt in individually |
| BookOrbit     | PCT 102 (k3s + Helm) | Ebook/audiobook library server            |
| Samba NAS     | PCT 150          | All bulk data (media) + service configs on hdd-500 |
| databases     | PCT 151 (k3s + CloudNativePG) | Database tier, currently backing BookOrbit, on hdd-80 |
| Traefik + dnsmasq | PCT 104      | `https://<service>.local` for the LAN     |

## Principles

- **Reproducible**: `tofu apply` + `ansible-playbook site.yml` rebuilds
  everything except the data on the NAS.
- **Unprivileged only**: no privileged LXC containers, ever.
- **Data outlives containers**: rootfs is disposable and minimal (local-lvm);
  anything worth keeping lives on the samba share (hdd-500).
- **No community helper scripts**: official templates and packages only.
- **Independent failure domains**: the proxy/DNS container does not depend on
  the NAS; gluetun's health never affects other services.

## Users

One operator (Marko) plus household LAN clients consuming Jellyfin and the
`*.local` service UIs.
