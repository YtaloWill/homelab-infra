# Tech — stack and commands

## Stack

- **OpenTofu** ≥ 1.6 with `bpg/proxmox` (~> 0.66) — container lifecycle via the
  Proxmox API (`https://192.168.15.101:8006`, root@pam ticket auth
  (username/password) required for bind mounts — a token's authuser never
  matches PVE's literal `root@pam` check).
- **Ansible** (core ≥ 2.15) with `community.general` + `ansible.posix` —
  in-container configuration and the PVE-host CIFS mount. Vault for secrets.
- **LXC guests**: Alpine, all four (jellyfin, arr, samba, proxy). Official
  template only, downloaded by tofu to `local` storage.
- **Kubernetes**: four independent single-node k3s clusters (Alpine package,
  1.31.3, bundled traefik/metrics-server disabled), one per app-hosting
  container — PCT 100 runs jellyfin from the repo-local Helm chart
  `kubernetes/charts/jellyfin` (Alpine's own `jellyfin` apk package is
  edge-only — see design decision 10), PCT 101 runs the arr stack from
  `kubernetes/charts/arr-stack`, PCT 102 runs BookOrbit from
  `kubernetes/charts/bookorbit`, PCT 151 runs Postgres/pgvector via the
  **CloudNativePG operator** (`kubectl apply`, not Helm — see design
  decisions 12/13; pinned to v1.29.2 to match this fleet's k3s version). No
  cross-node clustering. samba and proxy run natively; Traefik as a static
  binary under OpenRC on PCT 104.

## Commands

```sh
# provisioning (from tofu/)
tofu init
tofu fmt -check && tofu validate     # static gate
tofu plan                            # 100/101/150 created fresh (deleted first, not imported)
tofu apply

# configuration (from ansible/)
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/site.yml --check --diff   # dry-run first
ansible-playbook playbooks/site.yml

# charts (from kubernetes/charts/)
helm lint arr-stack && helm lint jellyfin && helm lint bookorbit
helm template arr-stack --set gluetun.enabled=true   # render check
helm template jellyfin
helm template bookorbit
```

Playbook order for first rollout: `bootstrap.yml` → `storage.yml` →
`migrate-configs.yml` → `site.yml` (see spec tasks.md Phase 4).

## Conventions

- Secrets only via git-ignored `terraform.tfvars` / `ansible-vault`-encrypted
  `vault.yml`; `.example` files show the shape.
- Static IPs on 192.168.15.0/24; VMIDs and IPs are declared in
  `tofu/variables.tf` and `ansible/inventory/` — change them there, nowhere else.
- Validation is the cheapest thing that answers the question:
  `tofu validate` / `--syntax-check` before any live run; `--check --diff`
  before any real Ansible run.
- Never run `tofu destroy`. PCT 100/101/150 are deleted manually (outside
  tofu, after the pre-delete data migration — spec tasks.md Phase 4) and
  recreated via `tofu apply`; once created, `prevent_destroy` guards them.
