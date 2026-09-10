#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${HOME}/.local/state/dotfiles"
REVISION_FILE="${STATE_DIR}/deployed-revision"

cd -- "${ROOT_DIR}"
if ! git diff --quiet || ! git diff --cached --quiet; then
  printf '%s\n' 'Hay cambios locales sin guardar. Se cancela la actualización.' >&2
  exit 1
fi

old_revision=""
if [[ -f "${REVISION_FILE}" ]]; then
  old_revision="$(<"${REVISION_FILE}")"
fi

git pull --ff-only
new_revision="$(git rev-parse HEAD)"

if [[ -z "${old_revision}" ]]; then
  changed_files="$(git ls-files -- 'config/*')"
else
  changed_files="$(git diff --name-only --diff-filter=ACMR "${old_revision}" "${new_revision}" -- 'config/*')"
  deleted_files="$(git diff --name-only --diff-filter=D "${old_revision}" "${new_revision}" -- 'config/*')"
  while IFS= read -r relative; do
    [[ -z "${relative}" ]] && continue
    rm -f -- "${HOME}/.config/${relative#config/}"
  done <<< "${deleted_files}"
fi

while IFS= read -r relative; do
  [[ -z "${relative}" ]] && continue
  source="${ROOT_DIR}/${relative}"
  target="${HOME}/.config/${relative#config/}"
  mkdir -p -- "$(dirname -- "${target}")"
  cp -a -- "${source}" "${target}"
done <<< "${changed_files}"

chmod +x "${HOME}/.config/hypr/scripts/"*.py "${HOME}/.config/waybar/scripts/"*.sh 2>/dev/null || true
mkdir -p "${STATE_DIR}"
systemctl --user daemon-reload
hyprctl reload 2>/dev/null || true

printf '%s\n' 'Dotfiles actualizados: solo se aplicaron los cambios nuevos.'
