> **Superseded:** this plan has been formalized as the spec in
> `.kiro/specs/homelab-foundation/` (requirements → design → tasks) and
> implemented in `tofu/`, `ansible/`, and `kubernetes/`. Kept as the original
> intent capture; where they diverge, the spec wins.

Let's start a simple homelab first configuration.

This homelab will is based on a proxmox server based on 192.168.15.101:8006, so create opentofu and ansible configuration based on it.

Current configuration:

- A laptop Dell Latitude 7310
- i5 102210U Quad-Core
- 16GB RAM
- SSD 256GB
    - local-lvm: LVM-Thin 151GB
    - local: Directory 72GB
- hdd-500: A hard drive with 500GB (mounted as directory in sda1)
- hdd-80: A hard drive with 80GB (mounted as directory in sde1)

Datacenter exists with "central" name. No one container should have privileged access.

Already exists some LXC containers, current containers are:

- PCT 100 (jellyfin) - 192.168.15.102
    - Created based on this script: https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/jellyfin.sh
- PCT 101 (arr) - 192.168.15.103
    - Alpine linux - 4 CPU - 4GB RAM - 512MB SWAP
    - That runs this docker compose file:
        ```docker-compose
        x-environment: &default-env
        PUID: 1000
        PGID: 10000
        TZ: America/Sao_Paulo

        services:
            prowlarr:
                image: lscr.io/linuxserver/prowlarr:latest
                container_name: prowlarr
                environment:
                <<: *default-env
                volumes:
                - ./prowlarr/config:/config
                ports:
                - 9696:9696
                restart: unless-stopped

            qbittorrent:
                image: lscr.io/linuxserver/qbittorrent:latest
                container_name: qbittorrent
                dns:
                - 8.8.8.8
                - 8.8.4.4
                environment:
                - PUID=1000
                - PGID=10000
                - TZ=America/Sao_Paulo
                - WEBUI_PORT=8080
                - TORRENTING_PORT=6881
                ports:
                - 8080:8080 # qBittorrent Web UI
                - 6881:6881 # qBittorrent TCP
                - 6881:6881/udp # qBittorrent UDP
                volumes:
                - ./qbittorrent/config:/config
                - /mnt/samba/media/downloads:/downloads
                - /mnt/samba/media/movies:/movies
                - /mnt/samba/media/shows:/shows
                depends_on: !reset {}  # removes the gluetun dependency
                restart: unless-stopped

            flaresolverr:
                image: ghcr.io/flaresolverr/flaresolverr:latest
                container_name: flaresolverr
                environment:
                - TZ=America/Sao_Paulo
                ports:
                - 8191:8191
                restart: unless-stopped

            radarr:
                image: lscr.io/linuxserver/radarr:latest
                container_name: radarr
                environment:
                <<: *default-env
                volumes:
                - ./radarr/config:/config
                - /mnt/samba/media/movies:/movies
                - /mnt/samba/media/test_movies:/test_movies
                - /mnt/samba/media/downloads:/downloads
                ports:
                - 7878:7878
                restart: unless-stopped

            sonarr:
                image: lscr.io/linuxserver/sonarr:latest
                container_name: sonarr
                environment:
                <<: *default-env
                volumes:
                - ./sonarr/config:/config
                - /mnt/samba/media/shows:/shows
                - /mnt/samba/media/test_shows:/test_shows
                - /mnt/samba/media/downloads:/downloads
                ports:
                - 8989:8989
                restart: unless-stopped

            bazarr:
                image: lscr.io/linuxserver/bazarr:latest
                container_name: bazarr
                environment:
                <<: *default-env
                ports:
                - 6767:6767
                volumes:
                - ./bazarr/config:/config
                - /mnt/samba/media/movies:/movies
                - /mnt/samba/media/test_movies:/test_movies
                - /mnt/samba/media/shows:/shows
                - /mnt/samba/media/test_shows:/test_shows
                restart: unless-stopped

            jellyseerr:
                image: fallenbagel/jellyseerr:latest
                container_name: jellyseerr
                environment:
                - TZ=America/Sao_Paulo
                ports:
                - 5055:5055
                volumes:
                - ./jellyseerr/config:/app/config
                restart: unless-stopped
        ```
- PCT 150 (samba) 192.168.15.150
    - Alpine linux - 4 CPU - 2GB RAM - 512MB SWAP
    - hdd-500 is all here to store everything as a pseudo NAS server
    - CIFS used to connect here from other containers:
        - //192.168.15.150/nas /mnt/samba cifs credentials=/etc/samba/credentials,vers=3.0,uid=100000,gid=110000,file_mode=0660,dir_mode=0770,nofail 0  0
            - use credentials as
                - user: sambauser
                - password: 123456

Initial build should create all files using opentofu, ansible, kubernetes, helm to match and recreate this infra easily, following steps:

- Do not use community scripts.

- Use local-thin as possible as storage for containers, but important configuration from each service store on samba server.

- Do not configure any backup strategy for now.

- Create a LXC container as proxy to have a local dns to redirect to each service, for example jellyfin should be accessible by using https://jellyfin.local instead of 192.168.15.102:8096. It should use traefik for this, tiny as possible.

- For the others containers, should keep same configuration already existent.
    - Move config files saved on internal storage of container to specific config folder inside samba server.
    - All containers should use minimal storage as possible, just for system and not cause lag.
    - Do not wipe anything, create scripts to be executed in ansible to move configs to samba if necessary