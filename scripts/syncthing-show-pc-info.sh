#!/usr/bin/env bash

set -u -o pipefail

require_bin() {
  local bin
  bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    printf '%s not found on PATH\n' "$bin" >&2
    exit 1
  fi
}

main() {
  require_bin syncthing

  printf '== PC Syncthing Device ID ==\n'
  syncthing cli show system | python3 -c 'import json,sys; print(json.load(sys.stdin)["myID"])'

  printf '\n== Planned Folders ==\n'
  printf '%s\n' 'mystuff -> /home/sergio/mystuff -> /storage/emulated/0/Sync/mystuff'
  printf '%s\n' 'i2cat   -> /home/sergio/i2cat   -> /storage/emulated/0/Sync/i2cat'
  printf '%s\n' 'phd     -> /home/sergio/phd     -> /storage/emulated/0/Sync/phd'

  printf '\nOn the tablet, open Syncthing-Fork and share the tablet device ID so pairing can be completed.\n'
}

main "$@"
