#!/usr/bin/env bash

set -u -o pipefail

readonly SHELTER_PACKAGE="net.typeblog.shelter"
readonly SHELTER_COMPONENT="net.typeblog.shelter/net.typeblog.shelter.receivers.ShelterDeviceAdminReceiver"
readonly SHELTER_APK_URL="https://f-droid.org/repo/net.typeblog.shelter_445.apk"
readonly SHELTER_APK_PATH="/tmp/net.typeblog.shelter_445.apk"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/setup-shelter.sh

Behavior:
  - verifies adb connectivity
  - installs Shelter if needed
  - checks whether a managed profile already exists
  - if absent, starts managed-profile provisioning
  - polls for profile creation and prints the final state

This helper is idempotent.
EOF
}

strip_cr() {
  tr -d '\r'
}

require_bin() {
  local bin
  bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    printf '%s not found on PATH\n' "$bin" >&2
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

package_installed_owner() {
  local out
  out="$(adb shell pm list packages --user 0 "$SHELTER_PACKAGE" | strip_cr)"
  [ "$out" = "package:$SHELTER_PACKAGE" ]
}

has_managed_profile() {
  adb shell cmd user list -v | strip_cr | grep -Fq 'type=profile.MANAGED'
}

download_shelter() {
  if [ -f "$SHELTER_APK_PATH" ]; then
    printf 'Shelter APK already downloaded: %s\n' "$SHELTER_APK_PATH"
    return 0
  fi

  printf 'Downloading Shelter APK...\n'
  curl -L --fail --output "$SHELTER_APK_PATH" "$SHELTER_APK_URL"
}

install_shelter() {
  local result

  if package_installed_owner; then
    printf 'Shelter already installed in owner profile.\n'
    return 0
  fi

  download_shelter
  printf 'Installing Shelter...\n'
  result="$(adb install -r -g "$SHELTER_APK_PATH" 2>&1 | strip_cr)"
  printf '%s\n' "$result"

  if ! package_installed_owner; then
    printf 'Shelter installation did not complete successfully.\n' >&2
    exit 1
  fi
}

start_provisioning() {
  local result

  printf 'Starting managed-profile provisioning flow...\n'
  result="$(adb shell am start -a android.app.action.PROVISION_MANAGED_PROFILE --ecn android.app.extra.PROVISIONING_DEVICE_ADMIN_COMPONENT_NAME "$SHELTER_COMPONENT" 2>&1 | strip_cr)"
  printf '%s\n' "$result"
}

wait_for_profile() {
  local i

  for i in $(seq 1 90); do
    if has_managed_profile; then
      printf 'Managed profile detected.\n'
      return 0
    fi
    sleep 2
  done

  printf 'Managed profile not detected yet. Complete the provisioning UI on the tablet and rerun this script.\n' >&2
  return 1
}

show_state() {
  printf '\n== Users ==\n'
  adb shell cmd user list -v | strip_cr
  printf '\n== Device policy owners ==\n'
  adb shell dpm list-owners | strip_cr
}

main() {
  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
    usage
    exit 0
  fi

  require_bin adb
  require_bin curl
  verify_device
  install_shelter

  if has_managed_profile; then
    printf 'Managed profile already exists. Nothing to create.\n'
    show_state
    exit 0
  fi

  start_provisioning
  wait_for_profile || true
  show_state
}

main "$@"
