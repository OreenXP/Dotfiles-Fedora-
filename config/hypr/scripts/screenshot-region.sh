#!/bin/sh

# Solo permite un selector de región activo a la vez.
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
exec 9>"${runtime_dir}/hypr-screenshot-region.lock"
flock -n 9 || exit 0

region="$(slurp)" || exit 0
[ -n "${region}" ] || exit 0

grim -g "${region}" - | wl-copy
