#!/usr/bin/env bash

set -u

case "${1:-toggle}" in
  daemon)
    if command -v swaync >/dev/null 2>&1; then
      exec swaync
    fi
    exec mako
    ;;
  toggle)
    if command -v swaync-client >/dev/null 2>&1; then
      exec swaync-client --toggle-panel --skip-wait
    fi
    notify-send "Centro de notificaciones" "Instala SwayNotificationCenter para activar el dock."
    ;;
  clear)
    if command -v swaync-client >/dev/null 2>&1; then
      exec swaync-client --close-all --skip-wait
    fi
    exec makoctl dismiss --all
    ;;
  *)
    printf 'Uso: %s {daemon|toggle|clear}\n' "$0" >&2
    exit 2
    ;;
esac
