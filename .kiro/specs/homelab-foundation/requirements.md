# Requirements — homelab-foundation

## Introduction

Codify the existing single-node Proxmox homelab (Dell Latitude 7310, node API at
`https://192.168.15.101:8006`, datacenter/cluster name `central`) as reproducible
infrastructure-as-code using OpenTofu (provisioning) and Ansible (configuration).
The current fleet — jellyfin (PCT 100), arr media stack (PCT 101), samba NAS
(PCT 150) — is being rebuilt from scratch (deleted and recreated) so it
matches this spec exactly, and a new minimal reverse-proxy/DNS container must
be added so services are reachable as `https://<service>.local`. The one
hard constraint on the rebuild: real data SHALL NOT be wiped — the hdd-500
NAS payload (currently PCT 150's own rootfs disk) and jellyfin/arr's
still-local configs (not yet on the samba share) must be migrated off each
container before it's deleted, so the fresh container reattaches to
already-populated data instead of starting empty.

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
1.3. WHEN containers 100, 101, and 150 are rebuilt THEN they SHALL be deleted
     and recreated via `tofu apply` (no import) so their config exactly
     matches this spec; once created, `prevent_destroy` SHALL guard them so a
     later destructive plan fails.
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

**User Story:** As the operator, I want jellyfin running from the official
`jellyfin/jellyfin` container image on k3s, deployed by a repo-local Helm
chart via Ansible — the same pattern as the arr stack — so PCT 100 can be
rebuilt without the community script it was originally created with.

### Acceptance Criteria

5.1. WHEN the jellyfin role runs THEN jellyfin SHALL run as the official
     `jellyfin/jellyfin` image, deployed on a single-node k3s server on the
     Alpine container via a repo-local Helm chart
     (`kubernetes/charts/jellyfin`) — not via helper scripts. (Alpine's own
     `jellyfin` apk package exists but is edge-only, incompatible with this
     fleet's stable Alpine release; see design decision 10.)
5.2. WHEN data locations are configured THEN jellyfin config and data
     directories SHALL live under `/mnt/samba/configs/jellyfin/`, while cache
     and logs stay on the container rootfs for performance.
5.3. WHEN media is served THEN libraries SHALL read from `/mnt/samba/media/`.
5.4. WHEN hardware transcoding is used THEN PCT 100 SHALL pass through the
     iGPU render nodes (`/dev/dri/renderD128`, `/dev/dri/card1`) for QSV.

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

## Requirement 9 — Configarr / TRaSH-Guides PT-BR quality-profile sync

**User Story:** As the operator, I want sonarr/radarr's quality profiles and
custom formats kept in sync with the PT-BR TRaSH-Guides fork, seeded
automatically when first deployed and refreshed whenever I trigger it.

### Acceptance Criteria

9.1. WHEN `configarr.enabled` is true (default for this homelab, gated
     independently like `gluetun.enabled`) THEN the Helm chart SHALL run a
     one-shot `batch/v1` `Job` named `configarr-sync-<syncTrigger>` in the
     `arr` namespace, using the `ghcr.io/raydak-labs/configarr` image.
9.2. WHEN `configarr.enabled` is false THEN the rendered release SHALL
     contain no Configarr objects (Secret, ConfigMaps, Job) at all.
9.3. WHEN the sync Job's name (driven by `configarr.syncTrigger`) is new to
     the release THEN Helm SHALL create and run it as part of the normal
     `helm upgrade --install` — this is what seeds the first deployment (or
     first `configarr.enabled: true`) automatically.
9.4. WHEN `configarr.syncTrigger` is unchanged from the currently-deployed
     value THEN `helm upgrade --install` SHALL leave the existing sync Job
     as-is.
9.5. WHEN the operator wants a resync THEN they SHALL bump
     `configarr_sync_trigger` (Ansible inventory var → Helm value
     `configarr.syncTrigger`) to a new value and re-apply, giving Helm a
     fresh Job name to create.
9.6. WHEN the sync Job runs THEN it SHALL talk to the existing `sonarr` and
     `radarr` in-namespace Services (`http://sonarr:8989`,
     `http://radarr:7878`).
9.7. WHEN Configarr needs API credentials THEN they SHALL flow Vault
     (`vault_configarr_environment`) → Ansible-rendered values file →
     Kubernetes Secret, the same pattern as gluetun (Requirement 4.7).
9.8. WHEN the config source is vendored THEN `kubernetes/charts/arr-stack/files/configarr/`
     SHALL hold a config.yml merged from trash-guides-ptbr's
     `config-DUBLADO-SEM-ANIMES.yaml` and `config-LEGENDADO-SEM-ANIMES.yaml`
     (no HDR-ON, no anime split — the fleet runs one sonarr/radarr instance
     each), producing two coexisting quality profiles, `HD (Dublado)` listed
     first and `HD (Legendado)` second, plus the matching
     `custom-formats/*.json` files.
9.9. WHEN the vendored config needs refreshing THEN it SHALL be regenerated
     by running `kubernetes/charts/arr-stack/scripts/update-configarr.sh`
     (git clone + `yq` merge).
9.10. WHEN Configarr needs a writable cache directory THEN it SHALL use a
      hostPath volume under `/mnt/samba/configs/arr/configarr`, consistent
      with every other app's config-storage convention (Requirement 4.3).

## Requirement 10 — BookOrbit library server

**User Story:** As the operator, I want an ebook/audiobook library
(BookOrbit) running from the official `ghcr.io/bookorbit/bookorbit` image on
k3s, deployed by a repo-local Helm chart via Ansible — the same pattern as
Jellyfin/arr — so PCT 102 is fully reproducible from this repo, not a
manual Docker Compose deploy.

### Acceptance Criteria

10.1. WHEN the bookorbit role runs THEN BookOrbit SHALL run as the official
      `ghcr.io/bookorbit/bookorbit` image, deployed on a single-node k3s
      server on the Alpine container via a repo-local Helm chart
      (`kubernetes/charts/bookorbit`) — not Docker Compose.
10.2. WHEN data locations are configured THEN BookOrbit's app data SHALL
      live under `/mnt/samba/configs/bookorbit/`.
10.3. WHEN the library is served THEN it SHALL read and write
      `/mnt/samba/media/books/` (read-write, unlike Jellyfin's read-only
      media mount — BookOrbit organizes files and writes metadata sidecars
      back into the library), with `Ebooks/`, `Audiobooks/`, and `Comics/`
      subfolders pre-created.
10.4. WHEN BookOrbit needs its database THEN it SHALL connect to the
      `databases` container's Postgres cluster over the LAN
      (`192.168.15.151:5432`) — never through the CIFS share.
10.5. WHEN BookOrbit needs secrets (`JWT_SECRET`, `SETUP_BOOTSTRAP_TOKEN`,
      `POSTGRES_PASSWORD`) THEN they SHALL flow Vault
      (`vault_bookorbit_environment`) → Ansible-rendered values file → a
      Kubernetes Secret, never hardcoded in the chart or repo.

## Requirement 11 — Databases container (Postgres/pgvector)

**User Story:** As the operator, I want a dedicated database tier so
services that need Postgres (starting with BookOrbit, which also needs
pgvector) don't have to fit this fleet's CIFS-based config-storage
convention, which Postgres doesn't tolerate.

### Acceptance Criteria

11.1. WHEN the databases container (PCT 151) is provisioned THEN the host
      directory backing `hdd-80` SHALL be bind-mounted directly into it
      (not via CIFS/samba) as its data root.
11.2. WHEN Postgres is deployed THEN it SHALL run via the CloudNativePG
      operator on a single-node k3s server on PCT 151, using a
      `cloudnative-pg/postgresql` "standard" operand image (bundles
      pgvector) — not a hand-built image, not Alpine's own postgresql
      package (no pgvector package exists for Alpine on any branch).
11.3. WHEN Postgres's data directory is configured THEN it SHALL be a
      statically-provisioned PersistentVolume backed by the hdd-80 bind
      mount (`{{ databases_export_path }}/postgres`) — no dynamic
      StorageClass is used anywhere in this fleet.
11.4. WHEN another container needs database access THEN the cluster SHALL
      be reachable over the LAN at `192.168.15.151:5432` via a
      LoadBalancer Service — never through CIFS/samba.
11.5. WHEN credentials are needed THEN they SHALL come from an Ansible
      Vault variable (`vault_bookorbit_environment.POSTGRES_PASSWORD`) —
      never hardcoded in the repo.
11.6. WHEN hdd-80 is disconnected and reconnected THEN
      `recover-hdd80-mount.yml` SHALL re-locate it by filesystem UUID and
      reboot the databases container, mirroring `recover-nas-mount.yml`'s
      pattern for hdd-500.

## Non-Goals (this phase)

- **Backups** — explicitly out of scope per PLAN.md.
- **Multi-node / HA Kubernetes** — every k3s cluster in this fleet
  (jellyfin, arr, bookorbit, databases) is single-node; samba and the proxy
  stay native LXC services.
- **Privileged containers** — forbidden, not just deferred.
- **Real TLS certificates / internal CA** — self-signed default cert only.
- **Dedicated anime sonarr/radarr instances** — Configarr syncs the
  SEM-ANIMES profile variant against the existing single sonarr/radarr;
  standing up separate anime instances is a future call, not this change.
