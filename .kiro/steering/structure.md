# Structure — repository layout

```
homelab/
├── PLAN.md                     # original intent capture (superseded by specs)
├── README.md                   # quickstart + rollout runbook
├── CLAUDE.md / AGENTS.md       # operator rules + project section (kept identical)
├── .kiro/
│   ├── steering/               # always-true context: product, tech, structure
│   └── specs/
│       └── homelab-foundation/ # requirements.md, design.md, tasks.md
├── tofu/                       # OpenTofu — one file per container
│   ├── versions.tf providers.tf variables.tf outputs.tf templates.tf
│   ├── jellyfin.tf arr.tf samba.tf proxy.tf
│   └── terraform.tfvars.example
├── kubernetes/
│   └── charts/
│       └── arr-stack/          # Helm chart: arr apps + optional gluetun
└── ansible/
    ├── ansible.cfg
    ├── requirements.yml        # collections
    ├── inventory/
    │   ├── hosts.yml
    │   └── group_vars/all/     # main.yml (plain) + vault.yml (encrypted, ignored)
    ├── playbooks/              # bootstrap, storage, services, site, migrate-configs
    └── roles/
        ├── samba_server/  jellyfin/  k3s/  arr_stack/  proxy/
        └── <role>/{tasks,templates,handlers,defaults}/
```

## Rules of placement

- New container → new `tofu/<name>.tf` + inventory host + role/play as needed;
  update the spec (requirements/design/tasks) in the same change.
- Spec work happens in `.kiro/specs/<feature>/` — requirements before design,
  design before tasks, tasks before code. Keep tasks.md checkboxes current.
- WIP notes/analyses → `docs/wip/` (per operator rules), not `/tmp`.
- Shared tunables live once: tofu in `variables.tf`, ansible in
  `inventory/group_vars/all/main.yml`. No literals duplicated across layers
  without a comment naming the counterpart.
