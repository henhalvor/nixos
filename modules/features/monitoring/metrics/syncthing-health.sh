#!/usr/bin/env bash
# Read only the local Syncthing REST API. The API key is never emitted or
# logged; absent or invalid credentials become explicit unhealthy metrics.
set -euo pipefail

out="$1"
config_file="${HENHAL_SYNCTHING_CONFIG:-/home/henhal/.config/syncthing/config.xml}"
tmp="${out}.tmp.$$"
trap 'rm -f "$tmp"' EXIT

collector_error=0
api_key=""
if [[ -r "$config_file" ]]; then
  api_key="$(xmllint --xpath 'string(configuration/gui/apikey)' "$config_file" 2>/dev/null || true)"
fi
[[ -n "$api_key" ]] || collector_error=1

{
  cat <<'EOF'
# HELP henhal_syncthing_folder_in_sync 1 when a reviewed Syncthing folder is idle with no pending items or errors.
# TYPE henhal_syncthing_folder_in_sync gauge
# HELP henhal_syncthing_pending_items Pending item count for a reviewed Syncthing folder.
# TYPE henhal_syncthing_pending_items gauge
EOF
  for folder in vault shared; do
    synced=0
    pending=0
    if [[ -n "$api_key" ]]; then
      json="$(curl --fail --silent --show-error -H "X-API-Key: $api_key" "http://127.0.0.1:8384/rest/db/status?folder=$folder" 2>/dev/null || true)"
      if jq -e . >/dev/null 2>&1 <<<"$json"; then
        state="$(jq -r '.state // empty' <<<"$json")"
        needed="$(jq -r '.needTotalItems // 0' <<<"$json")"
        errors="$(jq -r '.pullErrors // 0' <<<"$json")"
        if [[ "$needed" =~ ^[0-9]+$ && "$errors" =~ ^[0-9]+$ ]]; then
          pending="$needed"
          [[ "$state" == idle && "$needed" == 0 && "$errors" == 0 ]] && synced=1
        else
          collector_error=1
        fi
      else
        collector_error=1
      fi
    fi
    (( synced )) || collector_error=1
    printf 'henhal_syncthing_folder_in_sync{folder="%s"} %s\n' "$folder" "$synced"
    printf 'henhal_syncthing_pending_items{folder="%s"} %s\n' "$folder" "$pending"
  done
  cat <<EOF
# HELP henhal_metric_collector_error 1 when a local metric collector could not obtain all of its data.
# TYPE henhal_metric_collector_error gauge
henhal_metric_collector_error{collector="syncthing_health"} ${collector_error}
EOF
} >"$tmp"
mv -f "$tmp" "$out"
