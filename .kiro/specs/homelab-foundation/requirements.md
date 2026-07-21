# Requirements — homelab-foundation

## Introduction

Codify the existing single-node Proxmox homelab (Dell Latitude 7310, node API at
`https://192.168.15.101:8006`, datacenter/cluster name `central`) as reproducible
infrastructure-as-code using OpenTofu (provisioning) and Ansible (configuration).
The current fleet — jellyfin (PCT 100), arr media stack (PCT 101), samba NAS
(PCT 150) — must be brought under management **without recreation or data loss**,
and a new minimal reverse-proxy/DNS container must be added so services are
reachable as `https://<service>.local`.

Original intent capture: [PLAN.md](../../../PLAN.md). This spec is the source of
truth where the two diverge.

## Requirement 1 — Declarative container provisioning (OpenTofu)

**User Story:** As the homelab operator, I want every LXC container declared in
OpenTofu against the Proxmox API, so that the whole fleet can be recreated or
audited from code.

### Acceptance Criteria

1.1. WHEN `tofu apply` runs with valid credentials THEN the system SHALL ensure
     containers `100` (jellyfin), `101` (arr), `150` (samba), and `104` (proxy)
     exist on the node with the declared CPU, memory, swap, and rootfs settings.
1.2. WHEN any container is created or managed THEN it SHALL be **unprivileged**
     (`unprivileged = true`); no privileged containers are permitted.
1.3. WHEN bringing the pre-existing containers (100, 101, 150) under management
     THEN they SHALL be imported into state, never destroyed/recreated;
     `prevent_destroy` SHALL guard them so a destructive plan fails.
1.4. WHEN a container rootfs is provisioned THEN it SHALL live on `local-lvm`
     (LVM-thin) with the minimum practical size for the OS + runtime only.
1.5. IF the required Alpine/Debian LXC templates are absent THEN `tofu apply`
     SHALL download them to the `local` storage.
1.6. WHEN container OS provisioning is needed THEN official distribution
     templates SHALL be used — community helper scripts SHALL NOT be used.
1.7. WHEN the arr container is managed THEN `/dev/net/tun` SHALL be passed
     through so a VPN tunnel (gluetun) can run inside an unprivileged container.

## Requirement 2 — Storage and data placement

**User Story:** As the operator, I want bulk data and service configuration
centralized on the samba NAS while container rootfs stays minimal, so containers
are disposable and data survives container rebuilds.

### Acceptance Criteria

2.1. WHEN the samba container is provisioned THEN the host directory backing
     `hdd-500` SHALL be bind-mounted into it as the share root (all NAS data
     lives on hdd-500).
2.2. WHEN a service stores important configuration THEN that configuration SHALL
     live under `//192.168.15.150/nas/configs/<service>/` on the samba share.
2.3. WHEN consumer containers (jellyfin, arr) need the share THEN the CIFS mount
     SHALL be performed on the **Proxmox host** at `/mnt/samba` and bind-mounted
     into the containers — unprivileged LXC cannot mount CIFS itself.
2.4. WHEN the host CIFS mount is configured THEN it SHALL preserve the existing
     uid/gid mapping (`uid=100000,gid=110000,file_mode=0660,dir_mode=0770`) and
     add `nobrl` so SQLite databases stored on the share function correctly.
2.5. The `hdd-80` disk SHALL be left untouched (unassigned in this phase).

## Requirement 3 — Samba NAS service

**User Story:** As the operator, I want the samba container configured by
Ansible, so the NAS share and its directory layout are reproducible.

### Acceptance Criteria

3.1. WHEN the samba role runs THEN the container SHALL export a `[nas]` share
     (SMB3) authenticated as user `sambauser`, writable, rooted at the hdd-500
     bind mount.
3.2. WHEN the share tree is ensured THEN
     `media/{downloads,movies,shows,test_movies,test_shows}` and
     `configs/{jellyfin,arr/<service>}` directories SHALL exist.
3.3. WHEN credentials are needed THEN the samba password SHALL come from an
     Ansible Vault variable — never from the repository in plaintext.

## Requirement 4 — Media automation stack on Kubernetes + Helm (arr)

**User Story:** As the operator, I want the arr stack to run on single-node
Kubernetes (k3s) deployed from a Helm chart in this repo, behaving exactly like
the current docker-compose stack, plus an optional VPN egress (gluetun) that I
can enable or disable with a single value without touching anything else.

### Acceptance Criteria

4.1. WHEN the k3s role runs THEN a single-node k3s server SHALL be installed on
     the Alpine arr container (PCT 101), with the bundled traefik and
     metrics-server disabled (ingress belongs to the proxy CT; RAM is scarce)
     and with the unprivileged-LXC accommodations applied
     (`KubeletInUserNamespace` feature gate, kube-proxy conntrack args,
     `/dev/kmsg` shim).
4.2. WHEN the Helm chart (`kubernetes/charts/arr-stack`) is installed THEN it
     SHALL run prowlarr, qbittorrent, flaresolverr, radarr, sonarr, bazarr, and
     jellyseerr with the same images, ports, and environment as the current
     stack (`TZ=America/Sao_Paulo`, `PUID=1000`, `PGID=10000`), reachable at
     the same `192.168.15.103:<port>` endpoints (LoadBalancer services via k3s
     servicelb).
4.3. WHEN workloads declare config storage THEN they SHALL use hostPath volumes
     under `/mnt/samba/configs/arr/<service>`; media volumes SHALL keep the
     existing `/mnt/samba/media/...` paths mounted at the same in-container
     locations (`/downloads`, `/movies`, `/shows`, ...).
4.4. WHEN gluetun is deployed THEN it SHALL be an **independent** Deployment +
     Service gated by the Helm value `gluetun.enabled` (default `false`),
     exposing VPN egress as an HTTP proxy on `:8888` that any application MAY
     opt into via its own application-level proxy settings.
4.5. No workload SHALL depend on gluetun in any situation: no shared network
     namespace, no init/sidecar coupling, no readiness dependency. WHEN gluetun
     is enabled, disabled, stopped, or crashed THEN every other workload's
     manifest and operation SHALL remain unchanged.
4.6. WHEN `gluetun.enabled` is false THEN the rendered release SHALL contain no
     gluetun objects at all.
4.7. WHEN gluetun is configured THEN provider settings and credentials SHALL
     flow Vault → Ansible-rendered values file → Kubernetes Secret, never
     hardcoded in chart or repo.
4.8. WHEN the chart changes THEN `helm lint` SHALL pass; deployment is
     idempotent via `helm upgrade --install` driven by Ansible.

## Requirement 5 — Jellyfin without community scripts

**User Story:** As the operator, I want jellyfin installed from the official
Jellyfin apt repository via Ansible, so PCT 100 can be rebuilt without the
community script it was originally created with.

### Acceptance Criteria

5.1. WHEN the jellyfin role runs THEN jellyfin SHALL be installed from
     `repo.jellyfin.org` on the Debian container — not via helper scripts.
5.2. WHEN data locations are configured THEN jellyfin config and data
     directories SHALL live under `/mnt/samba/configs/jellyfin/`, while cache
     and logs stay on the container rootfs for performance.
5.3. WHEN media is served THEN libraries SHALL read from `/mnt/samba/media/`.

## Requirement 6 — Local DNS and reverse proxy

**User Story:** As a LAN user, I want to reach services at
`https://<service>.local` instead of memorizing IP:port pairs.

### Acceptance Criteria

6.1. WHEN the proxy container is provisioned THEN it SHALL be a minimal
     unprivileged Alpine LXC (PCT 104, 192.168.15.104) running dnsmasq and
     Traefik only.
6.2. WHEN a LAN client uses 192.168.15.104 as its DNS server THEN any
     `*.local` name SHALL resolve to the proxy, and all other queries SHALL be
     forwarded upstream.
6.3. WHEN an HTTPS request for a configured hostname arrives THEN Traefik SHALL
     route it to the corresponding backend (jellyfin, prowlarr, qbittorrent,
     radarr, sonarr, bazarr, jellyseerr, flaresolverr, proxmox).
6.4. WHEN a plain-HTTP request arrives THEN it SHALL be redirected to HTTPS.
6.5. TLS SHALL use Traefik's default self-signed certificate in this phase
     (browser warning accepted; documented as a known limitation).

## Requirement 7 — Config migration without data loss

**User Story:** As the operator, I want existing service configs moved to the
samba share by an Ansible playbook, so nothing is lost and nothing is wiped.

### Acceptance Criteria

7.1. WHEN the migration playbook runs THEN legacy configs SHALL be **copied**
     (not moved) to `configs/...` on the share — source data SHALL never be
     deleted by automation.
7.2. IF a destination config directory already contains files THEN the
     migration SHALL skip that service (never overwrite a populated target).
7.3. WHEN a service's config is being copied THEN that service SHALL be stopped
     first and started again afterwards.

## Requirement 8 — Secrets hygiene

**User Story:** As the operator, I want zero secrets in the repository.

### Acceptance Criteria

8.1. Secrets (Proxmox API token, samba password, VPN/gluetun credentials) SHALL
     enter only via `terraform.tfvars` / Ansible Vault, both git-ignored, with
     committed `.example` files documenting the expected shape.
8.2. The current samba password documented in PLAN.md SHALL be treated as
     compromised (it is written down in plaintext) and SHOULD be rotated.

## Non-Goals (this phase)

- **Backups** — explicitly out of scope per PLAN.md.
- **Multi-node / HA Kubernetes** — k3s runs single-node on PCT 101 for the arr
  stack only; jellyfin, samba, and the proxy stay native LXC services.
- **Privileged containers** — forbidden, not just deferred.
- **hdd-80** — remains unassigned.
- **Real TLS certificates / internal CA** — self-signed default cert only.
- **GPU/QSV transcode passthrough for jellyfin** — not configured yet.
