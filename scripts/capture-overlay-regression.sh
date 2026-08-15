#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  capture-overlay-regression.sh \
    --label LABEL \
    --phase PHASE \
    --target-app PATH|none \
    --orathor-app PATH \
    --start "YYYY-MM-DD HH:MM:SS" \
    --end "YYYY-MM-DD HH:MM:SS" \
    --sessions COUNT \
    --visible-result RESULT \
    --output DIR

Captures a fixed local-time unified-log window and writes a Markdown summary,
raw matching log lines, and a tail of Orathor's diagnostic log. The observed
display mode is read from system_profiler at capture time.
EOF
}

label=""
phase=""
target_app=""
orathor_app=""
start_time=""
end_time=""
session_count=""
visible_result=""
output_root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --label) label="${2:-}"; shift 2 ;;
    --phase) phase="${2:-}"; shift 2 ;;
    --target-app) target_app="${2:-}"; shift 2 ;;
    --orathor-app) orathor_app="${2:-}"; shift 2 ;;
    --start) start_time="${2:-}"; shift 2 ;;
    --end) end_time="${2:-}"; shift 2 ;;
    --sessions) session_count="${2:-}"; shift 2 ;;
    --visible-result) visible_result="${2:-}"; shift 2 ;;
    --output) output_root="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for required in label phase target_app orathor_app start_time end_time session_count visible_result output_root; do
  eval "value=\${$required}"
  if [ -z "$value" ]; then
    echo "Missing required value: $required" >&2
    usage >&2
    exit 2
  fi
done

if [ ! -d "$orathor_app" ]; then
  echo "Orathor app does not exist: $orathor_app" >&2
  exit 2
fi
if [ "$target_app" != "none" ] && [ ! -d "$target_app" ]; then
  echo "Target app does not exist: $target_app" >&2
  exit 2
fi
case "$session_count" in
  ''|*[!0-9]*) echo "Session count must be a non-negative integer" >&2; exit 2 ;;
esac

start_epoch=$(date -j -f '%Y-%m-%d %H:%M:%S' "$start_time" '+%s' 2>/dev/null || true)
end_epoch=$(date -j -f '%Y-%m-%d %H:%M:%S' "$end_time" '+%s' 2>/dev/null || true)
if [ -z "$start_epoch" ] || [ -z "$end_epoch" ] || [ "$end_epoch" -le "$start_epoch" ]; then
  echo "Start/end must be valid local timestamps with end after start" >&2
  exit 2
fi
duration=$((end_epoch - start_epoch))

safe_label=$(printf '%s' "$label" | tr -cs 'A-Za-z0-9._-' '-')
result_dir="$output_root/$safe_label"
if [ -e "$result_dir" ]; then
  echo "Refusing to overwrite existing result directory: $result_dir" >&2
  exit 2
fi
mkdir -p "$result_dir"

display_json=$(system_profiler SPDisplaysDataType -json)
display_mode=$(printf '%s' "$display_json" | plutil -extract SPDisplaysDataType.0.spdisplays_ndrvs.0._spdisplays_resolution raw -o - - 2>/dev/null || echo "unknown")
gpu_model=$(printf '%s' "$display_json" | plutil -extract SPDisplaysDataType.0.sppci_model raw -o - - 2>/dev/null || echo "unknown")
hardware_model=$(sysctl -n hw.model 2>/dev/null || echo "unknown")
macos_version=$(sw_vers -productVersion)
macos_build=$(sw_vers -buildVersion)
timezone=$(date '+%Z (%z)')
git_commit=$(git -C "$(dirname "$0")/.." rev-parse --short HEAD 2>/dev/null || echo "unknown")

bundle_value() {
  local app_path="$1"
  local key="$2"
  defaults read "$app_path/Contents/Info.plist" "$key" 2>/dev/null || echo "unknown"
}

orathor_version=$(bundle_value "$orathor_app" CFBundleShortVersionString)
orathor_build=$(bundle_value "$orathor_app" CFBundleVersion)
if [ "$target_app" = "none" ]; then
  target_name="none"
  target_version="n/a"
else
  target_name=$(bundle_value "$target_app" CFBundleName)
  target_version=$(bundle_value "$target_app" CFBundleShortVersionString)
fi

raw_log="$result_dir/unified.log"
predicate='eventMessage CONTAINS[c] "IOSurface" OR eventMessage CONTAINS[c] "backdrop-aware vibrant color matrix filter" OR eventMessage CONTAINS[c] "fence" OR eventMessage CONTAINS[c] "_CGXPackagesSetWindowConstraints" OR eventMessage CONTAINS[c] "Invalid window" OR eventMessage CONTAINS[c] "Cursor disabled" OR eventMessage CONTAINS[c] "singular matrix"'
/usr/bin/log show --style compact --start "$start_time" --end "$end_time" --predicate "$predicate" > "$raw_log" 2>/dev/null

diagnostic_log="$HOME/Library/Application Support/segbedji.Orathor/diagnostics.log"
if [ -f "$diagnostic_log" ]; then
  tail -500 "$diagnostic_log" > "$result_dir/orathor-diagnostics-tail.log"
fi

count_matching() {
  local expression="$1"
  awk -v expression="$expression" '
    BEGIN { count = 0 }
    {
      line = tolower($0)
      if (expression == "iosurface_all" && index(line, "iosurface")) count++
      if (expression == "iosurface_malformed" && index(line, "iosurface") &&
          (index(line, "sid: 0x0") || index(line, "null buffer") || index(line, "client task"))) count++
      if (expression == "backdrop" && index(line, "backdrop-aware vibrant color matrix filter")) count++
      if (expression == "timed_fence" && index(line, "fence") &&
          (index(line, "timed out") || index(line, "timeout"))) count++
      if (expression == "invalid_window" &&
          (index(line, "_cgxpackagessetwindowconstraints") || index(line, "invalid window"))) count++
      if (expression == "cursor_disabled" && index(line, "cursor disabled")) count++
      if (expression == "singular_matrix" && index(line, "singular matrix")) count++
    }
    END { print count }
  ' "$raw_log"
}

rate_for() {
  awk -v count="$1" -v seconds="$duration" 'BEGIN { printf "%.3f", count / seconds }'
}

iosurface_all=$(count_matching iosurface_all)
iosurface_malformed=$(count_matching iosurface_malformed)
backdrop=$(count_matching backdrop)
timed_fence=$(count_matching timed_fence)
invalid_window=$(count_matching invalid_window)
cursor_disabled=$(count_matching cursor_disabled)
singular_matrix=$(count_matching singular_matrix)

summary="$result_dir/summary.md"
cat > "$summary" <<EOF
# $label

| Field | Value |
|---|---|
| Phase | $phase |
| Local window | $start_time – $end_time |
| Time zone | $timezone |
| Duration | $duration seconds |
| Sessions | $session_count |
| Visible result | $visible_result |
| Display mode | $display_mode |
| Hardware | $hardware_model; $gpu_model |
| macOS | $macos_version ($macos_build) |
| Orathor | $orathor_version ($orathor_build), commit $git_commit |
| Target | $target_name $target_version |

| Diagnostic | Count | Count/second |
|---|---:|---:|
| IOSurface, all matching lines | $iosurface_all | $(rate_for "$iosurface_all") |
| Malformed IOSurface | $iosurface_malformed | $(rate_for "$iosurface_malformed") |
| Backdrop-aware vibrant filter | $backdrop | $(rate_for "$backdrop") |
| Timed-out fence | $timed_fence | $(rate_for "$timed_fence") |
| Invalid window constraint | $invalid_window | $(rate_for "$invalid_window") |
| Cursor disabled | $cursor_disabled | $(rate_for "$cursor_disabled") |
| Singular matrix | $singular_matrix | $(rate_for "$singular_matrix") |
EOF

printf '%s\n' "$summary"
