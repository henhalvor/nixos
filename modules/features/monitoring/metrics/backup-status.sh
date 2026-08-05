#!/usr/bin/env bash
# Convert the existing HP backup status files into bounded Prometheus metrics.
# This collector does not run Restic or decrypt credentials.
set -euo pipefail

out="$1"
status_dir="${HENHAL_RESTIC_STATUS_DIR:-/var/lib/restic-status}"
github_status="${HENHAL_GITHUB_MIRROR_STATUS:-/var/lib/github-mirrors/status.json}"
last_success="${HENHAL_RESTIC_LAST_SUCCESS:-${status_dir}/last-success}"
last_check_success="${HENHAL_RESTIC_LAST_CHECK_SUCCESS:-${status_dir}/last-check-success}"
last_heartbeat_success="${HENHAL_BACKUP_HEARTBEAT_LAST_SUCCESS:-${status_dir}/last-backup-heartbeat-success}"
heartbeat_status="${HENHAL_BACKUP_HEARTBEAT_STATUS:-${status_dir}/last-backup-heartbeat-status.json}"
tmp="${out}.tmp.$$"
trap 'rm -f "$tmp"' EXIT

now="$(date +%s)"
collector_error=0
snapshot_timestamp=0
if [[ -r "$last_success" ]]; then
  value="$(tr -d '\n' <"$last_success")"
  snapshot_timestamp="$(date --date="$value" +%s 2>/dev/null || printf 0)"
fi
if [[ ! "$snapshot_timestamp" =~ ^[1-9][0-9]*$ ]]; then
  snapshot_timestamp=0
  collector_error=1
fi
snapshot_age="$(( now - snapshot_timestamp ))"
(( snapshot_timestamp > 0 )) || snapshot_age=0

check_timestamp=0
if [[ -r "$last_check_success" ]]; then
  check_value="$(tr -d '\n' <"$last_check_success")"
  check_timestamp="$(date --date="$check_value" +%s 2>/dev/null || printf 0)"
fi
if [[ ! "$check_timestamp" =~ ^[1-9][0-9]*$ ]]; then
  check_timestamp=0
  collector_error=1
fi

heartbeat_timestamp=0
if [[ -r "$last_heartbeat_success" ]]; then
  heartbeat_value="$(tr -d '\n' <"$last_heartbeat_success")"
  heartbeat_timestamp="$(date --date="$heartbeat_value" +%s 2>/dev/null || printf 0)"
fi
[[ "$heartbeat_timestamp" =~ ^[0-9]+$ ]] || heartbeat_timestamp=0
heartbeat_healthy=0
if [[ -r "$heartbeat_status" ]] && jq -e '.result == "healthy"' "$heartbeat_status" >/dev/null 2>&1; then
  heartbeat_healthy=1
fi

{
  cat <<EOF
# HELP henhal_backup_last_success_timestamp_seconds Completion time of the latest successful HP offsite Restic backup.
# TYPE henhal_backup_last_success_timestamp_seconds gauge
henhal_backup_last_success_timestamp_seconds{repository="hp-offsite"} ${snapshot_timestamp}
# HELP henhal_backup_snapshot_age_seconds Current age of the latest successful HP offsite Restic backup.
# TYPE henhal_backup_snapshot_age_seconds gauge
henhal_backup_snapshot_age_seconds{repository="hp-offsite"} ${snapshot_age}
# HELP henhal_backup_repository_check_last_success_timestamp_seconds Completion time of the latest successful sampled repository check.
# TYPE henhal_backup_repository_check_last_success_timestamp_seconds gauge
henhal_backup_repository_check_last_success_timestamp_seconds{repository="hp-offsite"} ${check_timestamp}
# HELP henhal_backup_heartbeat_last_success_timestamp_seconds Latest confirmed external backup-heartbeat delivery.
# TYPE henhal_backup_heartbeat_last_success_timestamp_seconds gauge
henhal_backup_heartbeat_last_success_timestamp_seconds{repository="hp-offsite"} ${heartbeat_timestamp}
# HELP henhal_backup_heartbeat_delivery_healthy 1 when the latest configured backup heartbeat delivery succeeded.
# TYPE henhal_backup_heartbeat_delivery_healthy gauge
henhal_backup_heartbeat_delivery_healthy{repository="hp-offsite"} ${heartbeat_healthy}
# HELP henhal_backup_source_healthy 1 when a staged backup source has healthy status.
# TYPE henhal_backup_source_healthy gauge
# HELP henhal_backup_source_status_timestamp_seconds Timestamp of a staged backup source status record.
# TYPE henhal_backup_source_status_timestamp_seconds gauge
EOF
  for source in opencloud-source opencloud-identity vault shared hermes github-mirror; do
    file="${status_dir}/${source}.json"
    [[ "$source" == github-mirror ]] && file="$github_status"
    healthy=0
    timestamp=0
    if [[ -r "$file" ]] && json="$(<"$file")" && jq -e . >/dev/null 2>&1 <<<"$json"; then
      result="$(jq -r '.result // empty' <<<"$json")"
      raw_timestamp="$(jq -r '.timestamp // .createdAt // empty' <<<"$json")"
      timestamp="$(date --date="$raw_timestamp" +%s 2>/dev/null || printf 0)"
      [[ "$result" == healthy && "$timestamp" =~ ^[1-9][0-9]*$ ]] && healthy=1
      (( healthy )) || collector_error=1
    else
      collector_error=1
    fi
    printf 'henhal_backup_source_healthy{source="%s"} %s\n' "$source" "$healthy"
    printf 'henhal_backup_source_status_timestamp_seconds{source="%s"} %s\n' "$source" "$timestamp"
  done
  cat <<EOF
# HELP henhal_metric_collector_error 1 when a local metric collector could not obtain all of its data.
# TYPE henhal_metric_collector_error gauge
henhal_metric_collector_error{collector="backup_status"} ${collector_error}
EOF
} >"$tmp"
mv -f "$tmp" "$out"
