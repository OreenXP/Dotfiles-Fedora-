#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/dotfiles"
BACKUP_DIR="${STATE_DIR}/backups/$(date +%Y%m%d-%H%M%S)"
SKIP_PULL=false
SKIP_PACKAGES=false

for argument in "$@"; do
  case "${argument}" in
    --no-pull) SKIP_PULL=true ;;
    --no-packages) SKIP_PACKAGES=true ;;
    -h|--help)
      printf '%s\n' 'Uso: ./install.sh [--no-pull] [--no-packages]'
      exit 0
      ;;
    *) printf 'Opción desconocida: %s\n' "${argument}" >&2; exit 2 ;;
  esac
done

if [[ "${EUID}" -eq 0 ]]; then
  printf '%s\n' 'No ejecutes este script como root.' >&2
  exit 1
fi

self_update() {
  ${SKIP_PULL} && return 0
  [[ -d "${ROOT_DIR}/.git" ]] || return 0

  if ! git -C "${ROOT_DIR}" diff --quiet || ! git -C "${ROOT_DIR}" diff --cached --quiet; then
    printf '%s\n' 'Aviso: no se hizo git pull porque el repositorio tiene cambios locales.' >&2
    return 0
  fi

  local before after
  before="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
  git -C "${ROOT_DIR}" pull --ff-only
  after="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
  if [[ "${before}" != "${after}" ]]; then
    printf '%s\n' 'Se descargó una versión nueva; reiniciando el instalador...'
    exec "${ROOT_DIR}/install.sh" --no-pull "$@"
  fi
}

install_packages() {
  ${SKIP_PACKAGES} && return 0

  if command -v dnf >/dev/null 2>&1; then
    local packages=(
      hyprland hyprland-guiutils waybar mako SwayNotificationCenter rofi fastfetch hyprlock swayidle kitty
      nautilus swaybg grim slurp wl-clipboard playerctl brightnessctl
      ImageMagick libnotify python3-gobject gtk3 gtk-layer-shell
      fontawesome-6-free-fonts fontawesome-6-brands-fonts jetbrains-mono-fonts
      curl unzip cargo bluez bluez-tools iwd util-linux
    )
    sudo dnf install -y "${packages[@]}"
  else
    printf '%s\n' 'Este instalador está preparado para Fedora (no se encontró dnf).' >&2
    return 1
  fi
}

install_rust_tools() {
  mkdir -p "${HOME}/.local/bin"

  if ! command -v impala >/dev/null 2>&1; then
    cargo install --locked impala
  fi
  if ! command -v bluetui >/dev/null 2>&1; then
    cargo install --locked bluetui
  fi

  [[ ! -x "${HOME}/.cargo/bin/impala" ]] || ln -sfn "${HOME}/.cargo/bin/impala" "${HOME}/.local/bin/impala"
  [[ ! -x "${HOME}/.cargo/bin/bluetui" ]] || ln -sfn "${HOME}/.cargo/bin/bluetui" "${HOME}/.local/bin/bluetui"
}

install_icon_font() {
  local font_dir="${HOME}/.local/share/fonts/NerdFontsSymbolsOnly"
  if fc-list 2>/dev/null | grep -q 'Symbols Nerd Font'; then
    return 0
  fi
  mkdir -p "${font_dir}"
  curl -fsSL 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip' -o "${font_dir}/symbols.zip"
  unzip -oq "${font_dir}/symbols.zip" -d "${font_dir}"
  rm -f "${font_dir}/symbols.zip"
  fc-cache -f "${font_dir}"
}

install_managed_file() {
  local source="$1" target="$2" mode="$3"
  if [[ -f "${target}" ]] && cmp -s -- "${source}" "${target}"; then
    chmod "${mode}" "${target}"
    return 0
  fi

  if [[ -e "${target}" || -L "${target}" ]]; then
    local backup="${BACKUP_DIR}${target#${HOME}}"
    mkdir -p -- "$(dirname -- "${backup}")"
    cp -a -- "${target}" "${backup}"
  fi
  install -D -m "${mode}" "${source}" "${target}"
}

deploy_files() {
  local source relative target mode
  while IFS= read -r -d '' source; do
    relative="${source#${ROOT_DIR}/config/}"
    target="${HOME}/.config/${relative}"
    mode="$(stat -c '%a' "${source}")"
    install_managed_file "${source}" "${target}" "${mode}"
  done < <(find "${ROOT_DIR}/config" -type f -print0)

  while IFS= read -r -d '' source; do
    relative="${source#${ROOT_DIR}/bin/}"
    target="${HOME}/.local/bin/${relative}"
    mode="$(stat -c '%a' "${source}")"
    install_managed_file "${source}" "${target}" "${mode}"
  done < <(find "${ROOT_DIR}/bin" -type f -print0)
}

configure_iwd() {
  local desired current_answer='n'
  desired="$(mktemp)"
  printf '%s\n' '[General]' 'EnableNetworkConfiguration=true' '' '[Network]' 'NameResolvingService=systemd' > "${desired}"
  if [[ ! -f /etc/iwd/main.conf ]] || ! cmp -s "${desired}" /etc/iwd/main.conf; then
    sudo install -D -m 0644 "${desired}" /etc/iwd/main.conf
  fi
  rm -f "${desired}"

  if systemctl is-active --quiet iwd.service 2>/dev/null \
    && ! systemctl is-active --quiet NetworkManager.service 2>/dev/null \
    && ! systemctl is-active --quiet wpa_supplicant.service 2>/dev/null; then
    return 0
  fi

  printf '\n%s\n' 'Impala necesita iwd como gestor único del Wi-Fi.'
  if [[ -t 0 ]]; then
    read -r -p '¿Cambiar de NetworkManager/wpa_supplicant a iwd ahora? [s/N] ' current_answer
  fi
  if [[ "${current_answer,,}" == s || "${current_answer,,}" == si || "${current_answer,,}" == sí ]]; then
    sudo systemctl enable --now iwd.service
    sudo systemctl disable --now NetworkManager.service wpa_supplicant.service
    sudo systemctl restart iwd.service
  else
    printf '%s\n' 'Se conservará el gestor Wi-Fi actual. Impala no debe usarse al mismo tiempo que NetworkManager.'
  fi
}

finish_install() {
  if systemctl --user daemon-reload 2>/dev/null; then
    systemctl --user enable --now hypr-wallpaper.service swayidle.service 2>/dev/null || \
      printf '%s\n' 'Aviso: no se pudieron iniciar todos los servicios de usuario en esta sesión.' >&2
  else
    printf '%s\n' 'Aviso: systemd de usuario no está disponible; el servicio se activará al iniciar sesión.' >&2
  fi
  hyprctl reload >/dev/null 2>&1 || true
  mkdir -p "${STATE_DIR}"
  git -C "${ROOT_DIR}" rev-parse HEAD > "${STATE_DIR}/deployed-revision" 2>/dev/null || true

  printf '\n%s\n' 'Dotfiles instalados y actualizados.'
  [[ ! -d "${BACKUP_DIR}" ]] || printf 'Copia de seguridad: %s\n' "${BACKUP_DIR}"
  printf '%s\n' 'Vuelve a ejecutar ./install.sh cuando quieras recibir y aplicar cambios nuevos.'
}

self_update "$@"
install_packages
install_rust_tools
install_icon_font
deploy_files
configure_iwd
finish_install
exit 0
