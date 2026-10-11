#!/bin/bash
# Development helper: run the plugin straight from this checkout.
#
#   scripts/dev.sh link     symlink this repo into ~/.config/omarchy/plugins and enable it
#   scripts/dev.sh reload   restart the shell so every file is re-read
#   scripts/dev.sh watch    restart the shell on every save (needs inotify-tools)
#   scripts/dev.sh unlink   disable and remove the symlink
#   scripts/dev.sh logs     follow shell log lines mentioning the plugin
#
# Why a restart: the shell's hot reload watches the plugins dir with
# `inotifywait -r`, which does not descend into symlinks, and even when a reload
# fires, Qt keeps already-compiled sub-files (Panel.qml, ui/*.qml) cached by URL,
# and IPC handler signatures stay registered. A shell restart (~2s) re-reads
# everything.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ID="$(jq -r .id "$ROOT/manifest.json")"
LINK="$HOME/.config/omarchy/plugins/$ID"

reload() {
  omarchy restart shell >/dev/null 2>&1 || true
}

case "${1:-}" in
  link)
    omarchy plugin validate "$ROOT"
    if [[ -e $LINK && ! -L $LINK ]]; then
      echo "$LINK exists and is not a symlink (installed copy?). Remove it first: omarchy plugin remove $ID" >&2
      exit 1
    fi
    ln -sfn "$ROOT" "$LINK"
    # The registry scans asynchronously; retry until it knows the new plugin.
    omarchy-shell -q shell rescanPlugins
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      omarchy plugin enable "$ID" 2>/dev/null && exit 0
      sleep 0.5
    done
    omarchy plugin enable "$ID"
    ;;
  reload)
    reload
    ;;
  watch)
    command -v inotifywait >/dev/null || { echo "inotifywait not found: omarchy pkg add inotify-tools" >&2; exit 1; }
    echo "Watching $ROOT — Ctrl+C to stop"
    # Debounced: a burst of saves (formatter, git checkout) restarts once.
    while true; do
      path=$(inotifywait -r -q -e close_write,create,delete,move --exclude '/\.git/' --format '%w%f' "$ROOT")
      case "$path" in *.qml|*.js|*.json) ;; *) continue ;; esac
      while inotifywait -r -q -t 1 -e close_write,create,delete,move --exclude '/\.git/' "$ROOT" >/dev/null; do :; done
      echo "$(date +%T) restart shell (${path#"$ROOT"/})"
      reload
    done
    ;;
  unlink)
    omarchy plugin disable "$ID" || true
    if [[ -L $LINK ]]; then rm "$LINK"; fi
    ;;
  logs)
    qs log -f -i "$(qs list --all | awk '/^Instance/{gsub(":","",$2); print $2; exit}')" | grep --line-buffered -i -E "$ID"
    ;;
  *)
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
