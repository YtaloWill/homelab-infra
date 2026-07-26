# homelab

Single-node Proxmox homelab (Dell Latitude 7310, `https://192.168.15.101:8006`)
as reproducible infrastructure-as-code: **OpenTofu** provisions the LXC fleet,
**Ansible** configures it, and the arr media stack runs on **k3s** deployed
from a repo-local **Helm** chart.

Spec-driven repo: start at [.kiro/steering/](.kiro/steering/) for context and
[.kiro/specs/homelab-foundation/](.kiro/specs/homelab-foundation/) for the
active spec (requirements → design → tasks). [PLAN.md](PLAN.md) is the original
intent capture; the spec supersedes it.

Agent operator rules live in [AGENTS.md](AGENTS.md) (opencode convention).
Claude Code looks for `CLAUDE.md` specifically, so symlink it locally rather
than committing a duplicate:

```sh
ln -s AGENTS.md CLAUDE.md          # macOS/Linux
```

```powershell
New-Item -ItemType SymbolicLink -Path CLAUDE.md -Target AGENTS.md  # Windows
```

## Fleet

| PCT | Name     | IP              | Runs |
|-----|----------|-----------------|------|
| 100 | jellyfin | 192.168.15.102  | Jellyfin (Alpine, k3s + Helm release `jellyfin`) |
| 101 | arr      | 192.168.15.103  | k3s + Helm release `arr` (prowlarr, qbittorrent, flaresolverr, radarr, sonarr, bazarr, jellyseerr; optional gluetun) |
| 104 | proxy    | 192.168.15.104  | dnsmasq + Traefik → `https://<service>.local` |
| 150 | samba    | 192.168.15.150  | Samba NAS on hdd-500 (media + all service configs) |

All containers are unprivileged. Bulk data and stateful configs live on the
samba share; container rootfs is disposable.

## Prerequisites

- OpenTofu ≥ 1.6, Ansible core ≥ 2.15 on your workstation.
- A **root@pam** API token (host-path bind mounts require root):
  `pveum user token add root@pam tofu --privsep 0`
- SSH key access to the PVE host as root (Ansible + tofu ssh fallback).
- `tofu/terraform.tfvars` from the [example](tofu/terraform.tfvars.example)
  (token, node name, your pubkey) — verify template URLs against
  `pveam available` and sizes against `pct config 100|101|150`.
- `ansible/inventory/group_vars/all/vault.yml` from the
  [example](ansible/inventory/group_vars/all/vault.yml.example), then
  `ansible-vault encrypt` it.

## Rollout (first time)

Order matters; details in [tasks.md Phase 4](.kiro/specs/homelab-foundation/tasks.md).

```sh
cd tofu
tofu init
# bring the existing containers under management — never recreate them
tofu import proxmox_virtual_environment_container.jellyfin <node>/100
tofu import proxmox_virtual_environment_container.arr      <node>/101
tofu import proxmox_virtual_environment_container.samba    <node>/150
tofu plan   # gate: ZERO destroy/replace on 100/101/150
tofu apply  # creates PCT 104, adds mounts + /dev/net/tun

cd ../ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/bootstrap.yml        # sshd/python into the CTs (via pct)
ansible-playbook playbooks/storage.yml          # samba + host CIFS mount
ansible-playbook playbooks/migrate-configs.yml  # copy legacy configs (no wipe)
ansible-playbook playbooks/site.yml             # jellyfin, k3s+arr, proxy
```

Then point your LAN clients (or the router's DHCP DNS option) at
`192.168.15.104` and open `https://jellyfin.local` (self-signed cert — accept
the browser warning once).

## Enabling the VPN proxy (gluetun)

gluetun is fully independent: no workload depends on it, and toggling it
changes nothing else.

1. Put provider credentials in `vault.yml` (`vault_gluetun_environment`).
2. Set `gluetun_enabled: true` in `ansible/inventory/group_vars/all/main.yml`.
3. `ansible-playbook playbooks/site.yml`
4. Opt apps in via their own settings, e.g. qBittorrent → Options →
   Connection → Proxy → HTTP `192.168.15.103:8888`.
   Verify: `curl -x http://192.168.15.103:8888 https://ifconfig.me`.

Disabling: set the flag back to `false`, re-run site.yml, and unset the in-app
proxy settings of anything that opted in.

## Day-2

```sh
# infra drift check
cd tofu && tofu plan

# config drift / changes
cd ansible && ansible-playbook playbooks/site.yml --check --diff

# chart hygiene
helm lint kubernetes/charts/arr-stack
```

Smoke tests live in the spec's
[design.md](.kiro/specs/homelab-foundation/design.md#testing-strategy).
