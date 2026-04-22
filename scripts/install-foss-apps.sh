#!/usr/bin/env bash

set -u -o pipefail

readonly APPS_DIR="/tmp/samsung-s9-fe-apps"
readonly LOG_FILE="/tmp/samsung-s9-fe-apps-install.log"
readonly FDROID_INDEX_PATH="/tmp/samsung-s9-fe-fdroid-index-v2.json"
readonly FDROID_INDEX_URL="https://f-droid.org/repo/index-v2.json"

mkdir -p "$APPS_DIR"

strip_cr() {
  tr -d '\r'
}

log() {
  printf '%s\n' "$1" | tee -a "$LOG_FILE"
}

require_bin() {
  local bin
  bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    printf '%s not found on PATH\n' "$bin" >&2
    exit 1
  fi
}

package_installed() {
  local pkg out
  pkg="$1"
  out="$(adb shell pm list packages --user 0 "$pkg" | strip_cr)"
  [ "$out" = "package:$pkg" ]
}

device_abis() {
  adb shell getprop ro.product.cpu.abilist | strip_cr
}

ensure_fdroid_index() {
  if [ ! -f "$FDROID_INDEX_PATH" ]; then
    log "Downloading F-Droid package index..."
    curl -L --fail --output "$FDROID_INDEX_PATH" "$FDROID_INDEX_URL" 2>&1 | tee -a "$LOG_FILE"
    return
  fi

  if find "$FDROID_INDEX_PATH" -mmin +360 >/dev/null 2>&1; then
    log "Refreshing stale F-Droid package index..."
    curl -L --fail --output "$FDROID_INDEX_PATH" "$FDROID_INDEX_URL" 2>&1 | tee -a "$LOG_FILE"
  fi
}

resolve_fdroid_url() {
  local pkg abi_list
  pkg="$1"
  abi_list="$(device_abis)"

  PKG="$pkg" ABI_LIST="$abi_list" INDEX_PATH="$FDROID_INDEX_PATH" python3 - <<'PY'
import json
import os
import sys

pkg = os.environ['PKG']
abi_list = [abi for abi in os.environ['ABI_LIST'].split(',') if abi]
index_path = os.environ['INDEX_PATH']

with open(index_path, 'r', encoding='utf-8') as fh:
    data = json.load(fh)

pkg_data = data['packages'].get(pkg)
if not pkg_data:
    sys.exit(1)

best = None
best_key = None

for key, version in pkg_data['versions'].items():
    manifest = version.get('manifest', {})
    native = manifest.get('nativecode', [])
    version_code = manifest.get('versionCode', -1)
    file_name = version.get('file', {}).get('name')
    if not file_name:
        continue

    if native:
        abi_rank = None
        for idx, abi in enumerate(abi_list):
            if abi in native:
                abi_rank = idx
                break
        if abi_rank is None:
            continue
    else:
        abi_rank = len(abi_list)

    candidate = (abi_rank, -version_code, file_name)
    if best is None or candidate < best:
        best = candidate
        best_key = file_name

if best_key is None:
    sys.exit(1)

print('https://f-droid.org/repo' + best_key)
PY
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
  fi

  log "$name installation may have failed"
  return 1
}

fdroid_install() {
  local name pkg url
  name="$1"
  pkg="$2"

  url="$(resolve_fdroid_url "$pkg")" || {
    log "FAILED to resolve F-Droid APK for $name ($pkg)"
    return 1
  }

  download_and_install "$name" "$pkg" "$url"
}

main() {
  : > "$LOG_FILE"

  require_bin adb
  require_bin curl
  require_bin python3

  log "=== Starting app installation ==="
  log "Timestamp: $(date)"

  ensure_fdroid_index

  fdroid_install "Fossify Contacts" "org.fossify.contacts"
  fdroid_install "Fossify Calendar" "org.fossify.calendar"
  fdroid_install "Fossify Calculator" "org.fossify.math"
  fdroid_install "Fossify Clock" "org.fossify.clock"
  fdroid_install "AVES Gallery" "deckers.thibault.aves.libre"

  download_and_install \
    "Brave Browser" \
    "com.brave.browser" \
    "https://github.com/brave/brave-browser/releases/download/v1.89.141/BraveMonoarm64.apk"

  fdroid_install "Nextcloud" "com.nextcloud.client"
  fdroid_install "KOReader" "org.koreader.launcher.fdroid"
  fdroid_install "NewsBlur" "com.newsblur"
  fdroid_install "Logseq" "com.logseq.app"
  fdroid_install "Aegis" "com.beemdevelopment.aegis"
  fdroid_install "Aurora Store" "com.aurora.store"
  fdroid_install "Binary Eye" "de.markusfisch.android.binaryeye"
  fdroid_install "Breezy Weather" "org.breezyweather"
  fdroid_install "DAVx5" "at.bitfire.davdroid"
  fdroid_install "GitNex" "org.mian.gitnex"
  fdroid_install "Home Assistant" "io.homeassistant.companion.android.minimal"
  fdroid_install "ICSx5" "at.bitfire.icsdroid"
  fdroid_install "Immich" "app.alextran.immich"
  fdroid_install "Jellyfin" "org.jellyfin.mobile"
  fdroid_install "Invoice Ninja" "com.invoiceninja.app"
  fdroid_install "Jitsi Meet" "org.jitsi.meet"
  fdroid_install "LocalSend" "org.localsend.localsend_app"
  fdroid_install "Lissen" "org.grakovne.lissen"
  fdroid_install "Mastodon" "org.joinmastodon.android"
  fdroid_install "Nextcloud Notes" "it.niedermann.owncloud.notes"
  fdroid_install "Proton VPN" "ch.protonvpn.android"
  fdroid_install "Geo Share" "page.ooooo.geoshare"
  fdroid_install "Thunderbird" "net.thunderbird.android"
  fdroid_install "Wallabag" "fr.gaulupeau.apps.InThePoche"
  fdroid_install "Obtainium" "dev.imranr.obtainium.fdroid"

  log "=== Installation complete ==="
  log "Log saved to: $LOG_FILE"
}

main "$@"
