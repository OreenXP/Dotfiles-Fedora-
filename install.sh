#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${HOME}/.local/state/dotfiles/backups/$(date +%Y%m%d-%H%M%S)"

if [[ "${EUID}" -eq 0 ]]; then
  printf '%s\n' 'No ejecutes este script como root.' >&2
  exit 1
fi

install_packages() {
  # Hyprland es obligatorio: el resto acompaña a esta configuración.
  local packages=(hyprland hyprland-guiutils waybar mako rofi fastfetch hyprlock kitty nautilus swaybg grim slurp wl-clipboard playerctl brightnessctl ImageMagick libnotify)
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y "${packages[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Syu --needed "${packages[@]}"
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y "${packages[@]}"
  else
    printf '%s\n' 'No se encontró dnf, pacman ni apt-get.' >&2
    return 1
  fi
}

backup_and_install() {
  local source="$1" target="$2"
  if [[ -e "${target}" || -L "${target}" ]]; then
    mkdir -p "${BACKUP_DIR}$(dirname -- "${target#${HOME}}")"
    mv -- "${target}" "${BACKUP_DIR}${target#${HOME}}"
  fi
  mkdir -p "$(dirname -- "${target}")"
  cp -a -- "${source}" "${target}"
}

install_packages

if ! command -v Hyprland >/dev/null 2>&1 && ! command -v hyprland >/dev/null 2>&1; then
  printf '%s\n' 'Error: Hyprland no quedó instalado.' >&2
  exit 1
fi

while IFS= read -r -d '' source; do
  relative="${source#"${ROOT_DIR}/config/"}"
  case "${relative}" in
    kitty/*) target="${HOME}/.config/${relative}" ;;
    systemd/user/*) target="${HOME}/.config/${relative}" ;;
    *) target="${HOME}/.config/${relative}" ;;
  esac
  backup_and_install "${source}" "${target}"
done < <(find "${ROOT_DIR}/config" -type f -print0)

chmod +x "${HOME}/.config/hypr/scripts/"*.py "${HOME}/.config/waybar/scripts/"*.sh
systemctl --user daemon-reload
systemctl --user enable hypr-wallpaper.service

printf '\n%s\n' 'Configuración instalada.'
printf '%s\n' "Copias de seguridad: ${BACKUP_DIR}"
printf '%s\n' 'Hyprland y sus componentes fueron instalados o ya estaban disponibles.'
printf '%s\n' 'Coloca tus fondos en ~/Documentos/Wallpapers.'
printf '%s\n' 'El logo de Fastfetch esperado es ~/.local/share/dotfiles/assets/Civic.jpeg.'
