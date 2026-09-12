#!/bin/sh

# Tabla de atajos de Hyprland. La fuente monoespaciada mantiene alineadas las
# dos columnas y Rofi permite filtrar la lista escribiendo cualquier palabra.
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
exec 9>"${runtime_dir}/rofi-shortcuts.lock"
flock -n 9 || exit 0

{
    printf '%-32s %s\n' 'ATAJO' 'ACCIÓN'
    printf '%-32s %s\n' '────────────────────────────' '──────────────────────────────'
    printf '%-32s %s\n' 'SUPER + C' 'Mostrar esta tabla'
    printf '%-32s %s\n' 'SUPER + T / Enter' 'Abrir terminal'
    printf '%-32s %s\n' 'SUPER + B' 'Abrir Bluetooth'
    printf '%-32s %s\n' 'SUPER + E' 'Abrir archivos'
    printf '%-32s %s\n' 'SUPER + R' 'Abrir Hyprlauncher'
    printf '%-32s %s\n' 'SUPER + Espacio' 'Abrir aplicaciones con Rofi'
    printf '%-32s %s\n' 'SUPER + M' 'Menú de energía'
    printf '%-32s %s\n' 'SUPER + N' 'Centro de notificaciones'
    printf '%-32s %s\n' 'SUPER + U' 'Administrar Wi-Fi'
    printf '%-32s %s\n' 'SUPER + L' 'Bloquear sesión'
    printf '%-32s %s\n' 'SUPER + W' 'Cerrar ventana'
    printf '%-32s %s\n' 'SUPER + V' 'Alternar ventana flotante'
    printf '%-32s %s\n' 'SUPER + P' 'Alternar pseudotiling'
    printf '%-32s %s\n' 'SUPER + SHIFT + P' 'Bloquear o activar touchpad'
    printf '%-32s %s\n' 'SUPER + J' 'Cambiar división del layout'
    printf '%-32s %s\n' 'SUPER + Esc' 'Compactar workspaces'
    printf '%-32s %s\n' 'SUPER + 1…0' 'Cambiar al workspace 1…10'
    printf '%-32s %s\n' 'SUPER + SHIFT + 1…0' 'Mover ventana al workspace 1…10'
    printf '%-32s %s\n' 'SUPER + S' 'Mostrar workspace especial'
    printf '%-32s %s\n' 'SUPER + SHIFT + S' 'Mover ventana al workspace especial'
    printf '%-32s %s\n' 'SUPER + ←/→/↑/↓' 'Cambiar ventana enfocada'
    printf '%-32s %s\n' 'SUPER + SHIFT + ←/→/↑/↓' 'Mover ventana'
    printf '%-32s %s\n' 'SUPER + CTRL + ←/→/↑/↓' 'Redimensionar ventana'
    printf '%-32s %s\n' 'SUPER + rueda' 'Recorrer workspaces'
    printf '%-32s %s\n' 'SUPER + clic izquierdo' 'Arrastrar ventana'
    printf '%-32s %s\n' 'SUPER + clic derecho' 'Redimensionar ventana'
    printf '%-32s %s\n' 'SUPER + SHIFT + Espacio' 'Elegir fondo de pantalla'
    printf '%-32s %s\n' 'SUPER + CTRL + Espacio' 'Cambiar idioma del teclado'
    printf '%-32s %s\n' 'Impr Pant' 'Capturar región al portapapeles'
    printf '%-32s %s\n' 'Teclas de volumen/brillo' 'Ajustar volumen y brillo'
    printf '%-32s %s\n' 'Teclas multimedia' 'Controlar reproducción'
} | rofi -dmenu \
    -i \
    -no-custom \
    -p 'Atajos' \
    -mesg 'Escribe para filtrar · Esc para cerrar' \
    -theme "${HOME}/.config/rofi/themes/shortcuts.rasi" \
    >/dev/null
