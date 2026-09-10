#!/bin/sh
choice=$(printf '%s\n' 'Suspender' 'Cerrar sesión' 'Reiniciar' 'Apagar' | rofi -dmenu -p 'Sesión') || exit 0
case "$choice" in
  Suspender) systemctl suspend ;;
  'Cerrar sesión'|Reiniciar|Apagar)
    confirm=$(printf '%s\n' 'Cancelar' 'Confirmar' | rofi -dmenu -p "$choice") || exit 0
    [ "$confirm" = Confirmar ] || exit 0
    case "$choice" in
      'Cerrar sesión') hyprctl dispatch 'hl.dsp.exit()' ;;
      Reiniciar) systemctl reboot ;;
      Apagar) systemctl poweroff ;;
    esac ;;
esac
