#!/usr/bin/env bash

set -u -o pipefail

readonly REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
readonly IMPORT_FILE="$REPO_DIR/profiles/obtainium-import.json"
readonly DEVICE_DEST="/sdcard/Download/obtainium-import.json"

verify_device() {
  local devices serial status line

  devices="$(adb devices | tr -d '\r')"
  line="$(printf '%s\n' "$devices" | sed '/^List of devices attached$/d' | sed '/^$/d' | head -n 1)"

  if [ -z "$line" ]; then
    printf 'No ADB device detected. Connect the tablet and enable USB debugging.\n' >&2
    exit 1
  fi

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

main() {
  if [ ! -f "$IMPORT_FILE" ]; then
    printf 'Import file not found: %s\n' "$IMPORT_FILE" >&2
    exit 1
  fi

  verify_device

  printf 'Pushing Obtainium import file to tablet...\n'
  adb push "$IMPORT_FILE" "$DEVICE_DEST"

  printf 'Done. On the tablet, open Obtainium -> Import/Export and select the file from Downloads.\n'
}

main "$@"
