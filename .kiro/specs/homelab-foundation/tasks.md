# Tasks — homelab-foundation

Checked items are authored in this repo. Unchecked items are live operations
against the Proxmox node — they consume real infra and follow the operator
rules (per-instance approval for anything destructive or shared-state).

## Phase 1 — Repository scaffold

- [x] 1.1 Kiro spec set: requirements.md, design.md, tasks.md (this file)
- [x] 1.2 Steering docs: `.kiro/steering/{product,tech,structure}.md`
- [x] 1.3 Root docs: README (runbook), .gitignore (state/vault/tfvars),
      project section in CLAUDE.md/AGENTS.md, PLAN.md pointer to specs
      (_Requirements: 8.1_)

## Phase 2 — OpenTofu provisioning code

- [x] 2.1 Provider + versions + variables + tfvars example (root token note)
      (_Requirements: 1.1, 8.1; design decision 9_)
- [x] 2.2 Template downloads (Alpine, Debian 12) via
      `proxmox_virtual_environment_download_file` (_Requirements: 1.5, 1.6_)
- [x] 2.3 `samba.tf` — PCT 150, hdd-500 bind mount, prevent_destroy
      (_Requirements: 1.2, 1.3, 1.4, 2.1_)
- [x] 2.4 `jellyfin.tf` — PCT 100, /mnt/samba bind mount, prevent_destroy
      (_Requirements: 1.2, 1.3, 1.4, 2.3_)
- [x] 2.5 `arr.tf` — PCT 101, /mnt/samba bind, nesting+keyctl, /dev/net/tun
      passthrough, prevent_destroy (_Requirements: 1.2, 1.3, 1.7, 2.3_)
- [x] 2.6 `proxy.tf` — PCT 104, minimal Alpine (_Requirements: 1.2, 1.4, 6.1_)
- [x] 2.7 Outputs (name → IP)

## Phase 3 — Ansible configuration code

- [x] 3.1 ansible.cfg, inventory, group_vars, vault example, collections
      requirements (_Requirements: 8.1_)
- [x] 3.2 `bootstrap.yml` — pct exec: python3 + sshd + pubkey into all CTs
- [x] 3.3 `samba_server` role — share, tree, vault-backed passdb user
      (_Requirements: 3.1, 3.2, 3.3_)
- [x] 3.4 `storage.yml` — samba role + PVE host CIFS mount (nobrl, nofail)
      + consumer CT restart on first mount (_Requirements: 2.3, 2.4_)
- [x] 3.5 `jellyfin` role — official repo, media group, systemd override to
      share paths (_Requirements: 5.1, 5.2, 5.3_)
- [x] 3.6 `k3s` role — apk k3s + helm, /dev/kmsg shim, config.yaml with
      userns accommodations, traefik/metrics-server disabled
      (_Requirements: 4.1_)
- [x] 3.7 `arr_stack` role + `kubernetes/charts/arr-stack` Helm chart — all
      seven apps at legacy ports via servicelb, hostPath configs on share,
      independent gluetun Deployment gated by `gluetun.enabled`, Secret from
      Vault-rendered values (_Requirements: 4.2–4.8_)
- [x] 3.8 `proxy` role — dnsmasq + Traefik binary/OpenRC + routers from
      `proxy_services` (_Requirements: 6.1–6.5_)
- [x] 3.9 `migrate-configs.yml` — stop → copy-iff-empty → start; never
      deletes sources (_Requirements: 7.1, 7.2, 7.3_)
- [x] 3.10 `site.yml` orchestration

## Phase 4 — Live rollout (operator-driven, in order)

- [ ] 4.1 Create root@pam API token; put it in `tofu/terraform.tfvars`;
      set `node_name` from `pvesh get /nodes`; align size/IP variables with
      `pct config 100|101|150` (_Requirements: 1.1_)
- [ ] 4.2 Create `ansible/inventory/group_vars/all/vault.yml` from the
      example; encrypt with `ansible-vault`; rotate the samba password
      (_Requirements: 8.1, 8.2_)
- [ ] 4.3 `tofu init && tofu import` PCT 100, 101, 150
      (`tofu import proxmox_virtual_environment_container.<name> <node>/<id>`)
      (_Requirements: 1.3_)
- [ ] 4.4 `tofu plan` — gate: **zero destroy/replace** on imported containers;
      reconcile variables until clean, then `tofu apply` (creates PCT 104,
      adds mounts/tun; container restarts required for new mounts)
      (_Requirements: 1.1, 1.7, 2.1, 2.3_)
- [ ] 4.5 `ansible-playbook playbooks/bootstrap.yml`
- [ ] 4.6 `ansible-playbook playbooks/storage.yml` (_Requirements: 2.*, 3.*_)
- [ ] 4.7 `ansible-playbook playbooks/migrate-configs.yml` — **before**
      services.yml so apps don't fresh-initialize into empty share dirs, and
      so the legacy compose stack frees the ports servicelb needs
      (_Requirements: 7.*_)
- [ ] 4.8 `ansible-playbook playbooks/site.yml` (_Requirements: 4.*, 5.*, 6.*_)
- [ ] 4.9 Point LAN DHCP/clients DNS at 192.168.15.104
- [ ] 4.10 Smoke tests from design.md (dig, curl, smbclient, kubectl get
      pods/svc, app UIs)
- [ ] 4.11 Optional: set VPN creds in Vault, flip `gluetun_enabled: true`,
      re-run site.yml, point qBittorrent's in-app proxy at
      `192.168.15.103:8888`; verify exit IP (_Requirements: 4.4, 4.6, 4.7_)
- [ ] 4.12 After the k8s stack is verified: remove legacy docker from PCT 101
      (`apk del docker docker-cli-compose`) and delete the legacy compose
      files under /srv — manual, per no-wipe rule (_Requirements: 7.1_)

## Phase 5 — Follow-ups (future specs, not started)

- [ ] 5.1 Backup strategy (explicitly deferred by PLAN.md)
- [ ] 5.2 Local CA for real TLS on `*.local`
- [ ] 5.3 Jellyfin hardware transcode passthrough
