#!/bin/sh

# Evita que una misma pulsación abra más de un selector. El descriptor se
# cierra explícitamente antes de wl-copy para no bloquear capturas futuras.
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
exec 9>"${runtime_dir}/hypr-screenshot-region.lock"
flock -n 9 || exit 0

region="$(slurp)" || exit 0
[ -n "${region}" ] || exit 0

pictures_dir="$(xdg-user-dir PICTURES 2>/dev/null)"
[ -n "${pictures_dir}" ] || pictures_dir="${HOME}/Pictures"
screenshot_dir="${pictures_dir}/Capturas de pantalla"
mkdir -p -- "${screenshot_dir}"

file="${screenshot_dir}/Captura desde $(date '+%Y-%m-%d %H-%M-%S').png"
if ! grim -g "${region}" "${file}"; then
    notify-send -u critical "Captura de pantalla" "No se pudo crear la captura."
    exit 1
fi

flock -u 9
exec 9>&-

if wl-copy --type image/png < "${file}"; then
    notify-send "Captura de pantalla" "Guardada y copiada al portapapeles."
else
    notify-send -u critical "Captura de pantalla" "Se guardó, pero no se pudo copiar al portapapeles."
fi
