#!/usr/bin/env bash

set -u -o pipefail

readonly DEFAULT_PROFILE="profiles/owner-degoogle-work-profile-ready.txt"

readonly PROTECTED_PACKAGES=(
  "android"
  "com.android.systemui"
  "com.samsung.android.systemui"
  "com.sec.android.app.launcher"
  "com.samsung.android.spen"
  "com.sec.android.app.camera"
  "com.samsung.android.provider.filterprovider"
  "com.samsung.android.app.smartcapture"
  "com.sec.android.app.myfiles"
  "com.samsung.android.app.notes"
  "com.samsung.android.honeyboard"
  "com.samsung.android.service.aircommand"
  "com.samsung.android.aircommandmanager"
  "com.samsung.android.service.pentastic"
  "com.android.managedprovisioning"
  "com.samsung.android.mdm"
  "com.samsung.android.container"
  "com.samsung.android.knox.sandbox"
  "com.samsung.android.knox.containercore"
)

usage() {
  cat <<'EOF'
Usage:
  ./scripts/debloat.sh apply [profile-file]
  ./scripts/debloat.sh restore <package>
  ./scripts/debloat.sh restore-file [profile-file]

Defaults:
  profile-file: profiles/owner-degoogle-work-profile-ready.txt

Notes:
  - Uses only: adb shell pm uninstall -k --user 0 <package>
  - Preserves core UI, camera, S Pen, and work-profile plumbing.
  - Continues when a package is missing or cannot be removed.
EOF
}

strip_cr() {
  tr -d '\r'
}

require_adb() {
  if ! command -v adb >/dev/null 2>&1; then
    printf 'adb not found on PATH\n' >&2
    exit 1
  fi
}

verify_device() {
  local devices lines serial status line

  devices="$(adb devices | strip_cr)"
  lines="$(printf '%s\n' "$devices" | sed '/^List of devices attached$/d' | sed '/^$/d')"

  if [ -z "$lines" ]; then
    printf 'No ADB device detected. Connect the tablet and enable USB debugging.\n' >&2
    exit 1
  fi

  line="$(printf '%s\n' "$lines" | head -n 1)"
  serial="${line%%[[:space:]]*}"
  status="$(printf '%s' "$line" | awk '{print $2}')"

  if [ "$status" = "unauthorized" ]; then
    printf 'Device %s is unauthorized. Accept the RSA prompt on the tablet.\n' "$serial" >&2
    exit 1
  fi

  if [ "$status" != "device" ]; then
    printf 'Device %s is in state %s. Resolve that before continuing.\n' "$serial" "$status" >&2
    exit 1
  fi

  printf 'Using device: %s\n' "$serial"
}

is_protected() {
  local pkg protected
  pkg="$1"
  for protected in "${PROTECTED_PACKAGES[@]}"; do
    if [ "$pkg" = "$protected" ]; then
      return 0
    fi
  done
  return 1
}

package_present() {
  local pkg out
  pkg="$1"
  out="$(adb shell pm list packages "$pkg" | strip_cr)"
  [ "$out" = "package:$pkg" ]
}

apply_profile() {
  local profile pkg result
  local -a removed failed skipped_missing skipped_protected

  profile="${1:-$DEFAULT_PROFILE}"
  if [ ! -f "$profile" ]; then
    printf 'Profile file not found: %s\n' "$profile" >&2
    exit 1
  fi

  while IFS= read -r pkg || [ -n "$pkg" ]; do
    pkg="${pkg%%#*}"
    pkg="$(printf '%s' "$pkg" | xargs)"

    if [ -z "$pkg" ]; then
      continue
    fi

    if is_protected "$pkg"; then
      skipped_protected+=("$pkg")
      continue
    fi

    if ! package_present "$pkg"; then
      skipped_missing+=("$pkg")
      continue
    fi

    result="$(adb shell pm uninstall -k --user 0 "$pkg" 2>&1 | strip_cr)"
    if printf '%s' "$result" | grep -Fq 'Success'; then
      removed+=("$pkg")
    else
      failed+=("$pkg :: $result")
    fi
  done < "$profile"

  printf '\n== Removed (%s) ==\n' "${#removed[@]}"
  printf '%s\n' "${removed[@]:-}"

  printf '\n== Missing / Already absent (%s) ==\n' "${#skipped_missing[@]}"
  printf '%s\n' "${skipped_missing[@]:-}"

  printf '\n== Protected / Skipped (%s) ==\n' "${#skipped_protected[@]}"
  printf '%s\n' "${skipped_protected[@]:-}"

  printf '\n== Failed (%s) ==\n' "${#failed[@]}"
  printf '%s\n' "${failed[@]:-}"
}

restore_packages() {
  local pkg result
  shift

  if [ "$#" -eq 0 ]; then
    printf 'No packages provided to restore.\n' >&2
    exit 1
  fi

  for pkg in "$@"; do
    result="$(adb shell cmd package install-existing "$pkg" 2>&1 | strip_cr)"
    printf '%s :: %s\n' "$pkg" "$result"
  done
}

restore_profile() {
  local profile pkg
  profile="${1:-$DEFAULT_PROFILE}"
  if [ ! -f "$profile" ]; then
    printf 'Profile file not found: %s\n' "$profile" >&2
    exit 1
  fi

  while IFS= read -r pkg || [ -n "$pkg" ]; do
    pkg="${pkg%%#*}"
    pkg="$(printf '%s' "$pkg" | xargs)"
    if [ -n "$pkg" ]; then
      adb shell cmd package install-existing "$pkg" | strip_cr
    fi
  done < "$profile"
}

main() {
  local command
  command="${1:-apply}"

  case "$command" in
    apply)
      require_adb
      verify_device
      apply_profile "${2:-$DEFAULT_PROFILE}"
      ;;
    restore)
      require_adb
      verify_device
      restore_packages "$@"
      ;;
    restore-file)
      require_adb
      verify_device
      restore_profile "${2:-$DEFAULT_PROFILE}"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
