#!/usr/bin/env bash
set -Eeuo pipefail

FONT_DIR="${HOME}/.local/share/fonts/SymbolsNerdFont"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip"
TEMP_FILE="$(mktemp --suffix=.zip)"

cleanup() {
  rm -f -- "${TEMP_FILE}"
}
trap cleanup EXIT

if [[ "${EUID}" -eq 0 ]]; then
  printf '%s\n' 'Ejecuta este script como usuario normal, no como root.' >&2
  exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
  printf '%s\n' 'Este script requiere Fedora y el gestor de paquetes dnf.' >&2
  exit 1
fi

sudo dnf install -y fontawesome-6-free-fonts jetbrains-mono-fonts curl unzip

mkdir -p "${FONT_DIR}"
curl --fail --location --silent --show-error "${FONT_URL}" -o "${TEMP_FILE}"
unzip -o "${TEMP_FILE}" -d "${FONT_DIR}" >/dev/null
fc-cache -f "${HOME}/.local/share/fonts"

if command -v waybar >/dev/null 2>&1; then
  pkill waybar 2>/dev/null || true
  nohup waybar >/dev/null 2>&1 &
fi

printf '%s\n' 'Fuentes instaladas y caché actualizada.'
printf '%s\n' 'Si los iconos no cambian, cierra sesión y vuelve a entrar.'
