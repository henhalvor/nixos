#!/usr/bin/env bash
# Observational SMART/NVMe summary. This never starts tests, changes device
# settings, or attempts repairs.
set -euo pipefail

out="$1"
tmp="${out}.tmp.$$"
trap 'rm -f "$tmp"' EXIT
collector_error=0
{
  cat <<'EOF'
# HELP henhal_storage_smart_healthy 1 when smartctl reports an overall-passing device health state.
# TYPE henhal_storage_smart_healthy gauge
# HELP henhal_storage_temperature_celsius Drive temperature reported by smartctl when available.
# TYPE henhal_storage_temperature_celsius gauge
EOF
  found=0
  for device in /dev/sd? /dev/nvme?n?; do
    [[ -b "$device" ]] || continue
    found=1
    name="${device#/dev/}"
    json="$(smartctl --json=c --health "$device" 2>/dev/null || true)"
    if ! jq -e . >/dev/null 2>&1 <<<"$json"; then
      printf 'henhal_storage_smart_healthy{device="%s"} 0\n' "$name"
      collector_error=1
      continue
    fi
    passed="$(jq -r 'if (.smart_status.passed // false) or ((.nvme_smart_health_information_log.critical_warning // 1) == 0) then "true" else "false" end' <<<"$json" 2>/dev/null || printf false)"
    healthy=0
    [[ "$passed" == true ]] && healthy=1
    printf 'henhal_storage_smart_healthy{device="%s"} %s\n' "$name" "$healthy"
    temperature="$(jq -r '.temperature.current // .nvme_smart_health_information_log.temperature // empty' <<<"$json" 2>/dev/null || true)"
    if [[ "$temperature" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      printf 'henhal_storage_temperature_celsius{device="%s"} %s\n' "$name" "$temperature"
    fi
  done
  (( found )) || collector_error=1
  cat <<EOF
# HELP henhal_metric_collector_error 1 when a local metric collector could not obtain all of its data.
# TYPE henhal_metric_collector_error gauge
henhal_metric_collector_error{collector="storage_health"} ${collector_error}
EOF
} >"$tmp"
mv -f "$tmp" "$out"
