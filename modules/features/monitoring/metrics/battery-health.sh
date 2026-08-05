#!/usr/bin/env bash
# Export the first available Linux power-supply battery. Missing fields are
# explicit collector errors rather than stale values from an earlier run.
set -euo pipefail

out="$1"
tmp="${out}.tmp.$$"
trap 'rm -f "$tmp"' EXIT

collector_error=0
ratio=0
found=0
for battery in /sys/class/power_supply/BAT*; do
  [[ -d "$battery" ]] || continue
  found=1
  full=""
  design=""
  for pair in charge_full:charge_full_design energy_full:energy_full_design; do
    current="${pair%%:*}"
    maximum="${pair##*:}"
    if [[ -r "$battery/$current" && -r "$battery/$maximum" ]]; then
      full="$(<"$battery/$current")"
      design="$(<"$battery/$maximum")"
      break
    fi
  done
  if [[ "$full" =~ ^[1-9][0-9]*$ && "$design" =~ ^[1-9][0-9]*$ ]]; then
    ratio="$(awk -v full="$full" -v design="$design" 'BEGIN { printf "%.8f", full / design }')"
  else
    collector_error=1
  fi
  break
done
(( found )) || collector_error=1

cat >"$tmp" <<EOF
# HELP henhal_battery_capacity_ratio Full-charge capacity divided by design capacity.
# TYPE henhal_battery_capacity_ratio gauge
henhal_battery_capacity_ratio ${ratio}
# HELP henhal_metric_collector_error 1 when a local metric collector could not obtain all of its data.
# TYPE henhal_metric_collector_error gauge
henhal_metric_collector_error{collector="battery_health"} ${collector_error}
EOF
mv -f "$tmp" "$out"
