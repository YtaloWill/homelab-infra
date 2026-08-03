# Vendored Configarr config

`config.yml` and `custom-formats/*.json` in this directory are generated —
do not hand-edit them.

Source: [marcosviniciusi/trash-guides-ptbr](https://github.com/marcosviniciusi/trash-guides-ptbr)
(`configarr/config-DUBLADO-SEM-ANIMES.yaml` + `configarr/config-LEGENDADO-SEM-ANIMES.yaml`,
merged, no HDR-ON, no anime split).

Regenerate with:

```
kubernetes/charts/arr-stack/scripts/update-configarr.sh
```

Requires `git` and `yq` (mikefarah/yq) locally. Review the diff before
committing — check the merge kept both `HD (Dublado)` and `HD (Legendado)`
quality profiles distinct and in that order.
