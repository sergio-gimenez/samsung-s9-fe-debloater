#!/usr/bin/env bash

set -u -o pipefail

readonly APPS_DIR="/tmp/samsung-s9-fe-apps"
readonly LOG_FILE="/tmp/samsung-s9-fe-apps-install.log"

mkdir -p "$APPS_DIR"

strip_cr() {
  tr -d '\r'
}

log() {
  printf '%s\n' "$1" | tee -a "$LOG_FILE"
}

package_installed() {
  local pkg out
  pkg="$1"
  out="$(adb shell pm list packages --user 0 "$pkg" | strip_cr)"
  [ "$out" = "package:$pkg" ]
}

download_and_install() {
  local name pkg url apk_path result
  name="$1"
  pkg="$2"
  url="$3"
  apk_path="$APPS_DIR/$(basename "$url")"

  if package_installed "$pkg"; then
    log "$name ($pkg) already installed"
    return 0
  fi

  if [ ! -f "$apk_path" ]; then
    log "Downloading $name..."
    if ! curl -L --fail --output "$apk_path" "$url" 2>&1 | tee -a "$LOG_FILE"; then
      log "FAILED to download $name"
      return 1
    fi
  fi

  log "Installing $name..."
  result="$(adb install -r -g "$apk_path" 2>&1 | strip_cr)"
  log "$result"

  if package_installed "$pkg"; then
    log "$name installed successfully"
    return 0
  else
    log "$name installation may have failed"
    return 1
  fi
}

main() {
  : > "$LOG_FILE"

  log "=== Starting app installation ==="
  log "Timestamp: $(date)"

  # Fossify apps from F-Droid
  download_and_install \
    "Fossify Contacts" \
    "org.fossify.contacts" \
    "https://f-droid.org/repo/org.fossify.contacts_13.apk"

  download_and_install \
    "Fossify Calendar" \
    "org.fossify.calendar" \
    "https://f-droid.org/repo/org.fossify.calendar_20.apk"

  download_and_install \
    "Fossify Calculator" \
    "org.fossify.math" \
    "https://f-droid.org/repo/org.fossify.math_10.apk"

  download_and_install \
    "Fossify Clock" \
    "org.fossify.clock" \
    "https://f-droid.org/repo/org.fossify.clock_10.apk"

  # AVES Gallery from F-Droid (libre version)
  download_and_install \
    "AVES Gallery" \
    "deckers.thibault.aves.libre" \
    "https://f-droid.org/repo/deckers.thibault.aves.libre_16302.apk"

  # Brave Browser from GitHub releases
  download_and_install \
    "Brave Browser" \
    "com.brave.browser" \
    "https://github.com/brave/brave-browser/releases/download/v1.89.141/BraveMonoarm64.apk"

  log "=== Installation complete ==="
  log "Log saved to: $LOG_FILE"
}

main "$@"
