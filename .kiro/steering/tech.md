# Tech — stack and commands

## Stack

- **OpenTofu** ≥ 1.6 with `bpg/proxmox` (~> 0.66) — container lifecycle via the
  Proxmox API (`https://192.168.15.101:8006`, root@pam token required for
  bind mounts).
- **Ansible** (core ≥ 2.15) with `community.general` + `ansible.posix` —
  in-container configuration and the PVE-host CIFS mount. Vault for secrets.
- **LXC guests**: Alpine (arr, samba, proxy), Debian 12 (jellyfin). Official
  templates only, downloaded by tofu to `local` storage.
- **Kubernetes**: single-node k3s inside PCT 101 (Alpine package, bundled
  traefik/metrics-server disabled) running the arr stack from the repo-local
  Helm chart `kubernetes/charts/arr-stack`; native packages elsewhere;
  Traefik as a static binary under OpenRC on PCT 104.

## Commands

```sh
# provisioning (from tofu/)
tofu init
tofu fmt -check && tofu validate     # static gate
tofu plan                            # review: no destroy/replace on 100/101/150
tofu apply

# configuration (from ansible/)
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/site.yml --check --diff   # dry-run first
ansible-playbook playbooks/site.yml

# chart (from kubernetes/charts/)
helm lint arr-stack
helm template arr-stack --set gluetun.enabled=true   # render check
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
- Never run `tofu destroy`; imported containers carry `prevent_destroy`.
