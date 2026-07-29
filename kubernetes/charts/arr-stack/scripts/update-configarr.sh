#!/usr/bin/env bash
set -euo pipefail

# Vendors the Configarr config for the arr-stack chart from
# marcosviniciusi/trash-guides-ptbr (PT-BR TRaSH-Guides). Merges the
# DUBLADO-SEM-ANIMES and LEGENDADO-SEM-ANIMES (no HDR) profiles into one
# config.yml with two coexisting quality profiles — "HD (Dublado)" listed
# first, "HD (Legendado)" second — since upstream both ship a profile
# literally named "HD" that would otherwise collide on sync.
#
# Re-run this to refresh from upstream. Do not hand-edit the generated
# files under files/configarr/ — edit this script instead.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$CHART_DIR/files/configarr"
REPO_URL="https://github.com/marcosviniciusi/trash-guides-ptbr"

command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "yq (mikefarah/yq) is required" >&2; exit 1; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Cloning $REPO_URL..."
git clone --depth 1 "$REPO_URL" "$TMP_DIR/src" >/dev/null
COMMIT_SHA="$(git -C "$TMP_DIR/src" rev-parse HEAD)"
FETCH_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

DUB_SRC="$TMP_DIR/src/configarr/config-DUBLADO-SEM-ANIMES.yaml"
LEG_SRC="$TMP_DIR/src/configarr/config-LEGENDADO-SEM-ANIMES.yaml"

for f in "$DUB_SRC" "$LEG_SRC"; do
  [ -f "$f" ] || { echo "expected file missing upstream: $f" >&2; exit 1; }
done

# Rename the "HD" quality profile (in both the profile definition and every
# custom_formats[].assign_scores_to[] reference to it) so the two variants
# can coexist as distinct profiles instead of overwriting each other.
rename_profile() {
  local src="$1" dst="$2" new_name="$3"
  yq eval "
    (.radarr.movies.quality_profiles[] | select(.name == \"HD\") | .name) = \"$new_name\" |
    (.radarr.movies.custom_formats[].assign_scores_to[] | select(.name == \"HD\") | .name) = \"$new_name\" |
    (.sonarr.series.quality_profiles[] | select(.name == \"HD\") | .name) = \"$new_name\" |
    (.sonarr.series.custom_formats[].assign_scores_to[] | select(.name == \"HD\") | .name) = \"$new_name\"
  " "$src" > "$dst"
}

echo "Renaming quality profiles..."
rename_profile "$DUB_SRC" "$TMP_DIR/dublado.yaml" "HD (Dublado)"
rename_profile "$LEG_SRC" "$TMP_DIR/legendado.yaml" "HD (Legendado)"

mkdir -p "$OUT_DIR/custom-formats"
MERGED="$OUT_DIR/config.yml"

echo "Merging into $MERGED (Dublado first, Legendado second)..."
{
  echo "# Vendored — do not hand-edit. Regenerate with:"
  echo "#   kubernetes/charts/arr-stack/scripts/update-configarr.sh"
  echo "# Source: $REPO_URL"
  echo "#   configarr/config-DUBLADO-SEM-ANIMES.yaml"
  echo "#   configarr/config-LEGENDADO-SEM-ANIMES.yaml"
  echo "# Commit: $COMMIT_SHA"
  echo "# Fetched: $FETCH_DATE"
  yq eval-all '
    select(fi == 0) as $dub |
    select(fi == 1) as $leg |
    $dub |
    .radarr.movies.custom_formats = ($dub.radarr.movies.custom_formats + $leg.radarr.movies.custom_formats) |
    .radarr.movies.quality_profiles = ($dub.radarr.movies.quality_profiles + $leg.radarr.movies.quality_profiles) |
    .sonarr.series.custom_formats = ($dub.sonarr.series.custom_formats + $leg.sonarr.series.custom_formats) |
    .sonarr.series.quality_profiles = ($dub.sonarr.series.quality_profiles + $leg.sonarr.series.quality_profiles)
  ' "$TMP_DIR/dublado.yaml" "$TMP_DIR/legendado.yaml"
} > "$MERGED"

echo "Validating merged YAML..."
yq eval . "$MERGED" >/dev/null

echo "Copying custom-formats/*.json..."
rm -f "$OUT_DIR"/custom-formats/*.json
cp "$TMP_DIR"/src/custom-formats/*.json "$OUT_DIR/custom-formats/"

echo "Done. Vendored into $OUT_DIR"
echo "Review the diff (especially the two HD profile names and array order), then commit."
