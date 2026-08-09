#!/usr/bin/env bash
# Report systemd unit state for a reviewed unit allowlist. Unit names are
# positional arguments after the output filename; they are never derived from
# unbounded systemd data.
set -euo pipefail

out="$1"
shift
tmp="${out}.tmp.$$"
trap 'rm -f "$tmp"' EXIT

failed_units="$(systemctl --failed --no-legend --no-pager 2>/dev/null | awk 'NF {count++} END {print count + 0}' || printf '0')"
collector_error=0
{
  cat <<EOF
# HELP henhal_system_failed_units Number of systemd units currently in failed state.
# TYPE henhal_system_failed_units gauge
henhal_system_failed_units ${failed_units}
# HELP henhal_service_probe_success 1 when the reviewed systemd service is active.
# TYPE henhal_service_probe_success gauge
# HELP henhal_service_restart_count systemd NRestarts for a reviewed service.
# TYPE henhal_service_restart_count gauge
EOF
  for unit in "$@"; do
    label="${unit//\\/\\\\}"
    label="${label//\"/\\\"}"
    active=0
    load_state="$(systemctl show --property=LoadState --value "$unit" 2>/dev/null || true)"
    active_state="$(systemctl show --property=ActiveState --value "$unit" 2>/dev/null || true)"
    result="$(systemctl show --property=Result --value "$unit" 2>/dev/null || true)"
    # Long-running services must be active. Successful completed oneshots are
    # healthy while inactive; a missing unit or failed result remains unhealthy.
    if [[ "$load_state" == loaded ]] && {
      [[ "$active_state" == active ]] ||
      [[ "$active_state" == inactive && "$result" == success ]]
    }; then
      active=1
    fi
    restarts="$(systemctl show --property=NRestarts --value "$unit" 2>/dev/null || true)"
    if [[ ! "$restarts" =~ ^[0-9]+$ ]]; then
      restarts=0
      collector_error=1
    fi
    printf 'henhal_service_probe_success{service="%s"} %s\n' "$label" "$active"
    printf 'henhal_service_restart_count{service="%s"} %s\n' "$label" "$restarts"
  done
  cat <<EOF
# HELP henhal_metric_collector_error 1 when a local metric collector could not obtain all of its data.
# TYPE henhal_metric_collector_error gauge
henhal_metric_collector_error{collector="service_health"} ${collector_error}
EOF
} >"$tmp"
mv -f "$tmp" "$out"
