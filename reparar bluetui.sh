#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  printf '%s\n' 'Ejecuta este script como usuario normal, no como root.' >&2
  exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
  sudo dnf install -y cargo
fi

sudo dnf install -y bluez bluez-tools
systemctl --user enable --now pipewire.service pipewire-pulse.service 2>/dev/null || true
sudo systemctl enable --now bluetooth.service

cargo install --locked bluetui
mkdir -p "${HOME}/.local/bin"
if [[ -x "${HOME}/.cargo/bin/bluetui" ]]; then
  ln -sfn "${HOME}/.cargo/bin/bluetui" "${HOME}/.local/bin/bluetui"
fi

printf '%s\n' 'Bluetui instalado/actualizado correctamente.'
