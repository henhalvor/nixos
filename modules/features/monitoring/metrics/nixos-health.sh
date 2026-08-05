#!/usr/bin/env bash
# Publish host-local NixOS health information for Node Exporter's textfile
# collector. The output filename is supplied as the first argument.
set -euo pipefail

out="$1"
tmp="${out}.tmp.$$"
trap 'rm -f "$tmp"' EXIT

generation_timestamp=0
collector_error=0
# The immutable store target carries reproducible source timestamps. The
# /run/current-system symlink itself is replaced at activation and therefore
# records when this generation actually became current.
if [[ -L /run/current-system ]]; then
  if built="$(stat -c %Y /run/current-system 2>/dev/null)"; then
    generation_timestamp="$built"
  else
    collector_error=1
  fi
else
  collector_error=1
fi

store_bytes=0
if store_bytes="$(du -sB1 /nix/store 2>/dev/null | awk '{print $1}')"; then
  :
else
  collector_error=1
fi

revision="$(sed -n 's/^VERSION_ID="\?\([^" ]*\)"\?$/\1/p' /etc/os-release 2>/dev/null | head -n1)"
revision="${revision:-unknown}"

cat >"$tmp" <<EOF
# HELP henhal_nixos_generation_timestamp_seconds Modification time of the active NixOS system generation.
# TYPE henhal_nixos_generation_timestamp_seconds gauge
henhal_nixos_generation_timestamp_seconds ${generation_timestamp}
# HELP henhal_nix_store_bytes Bytes currently used by /nix/store.
# TYPE henhal_nix_store_bytes gauge
henhal_nix_store_bytes ${store_bytes}
# HELP henhal_monitoring_config_build_info Information about the deployed NixOS release.
# TYPE henhal_monitoring_config_build_info gauge
henhal_monitoring_config_build_info{revision="${revision//\\/\\\\}"} 1
# HELP henhal_metric_collector_error 1 when a local metric collector could not obtain all of its data.
# TYPE henhal_metric_collector_error gauge
henhal_metric_collector_error{collector="nixos_health"} ${collector_error}
EOF
mv -f "$tmp" "$out"
