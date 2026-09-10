#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/dotfiles"
BACKUP_DIR="${STATE_DIR}/backups/$(date +%Y%m%d-%H%M%S)"
PAYLOAD_DIR=""
SKIP_PULL=false
SKIP_PACKAGES=false

cleanup() {
  [[ -z "${PAYLOAD_DIR}" ]] || rm -rf -- "${PAYLOAD_DIR}"
}
trap cleanup EXIT

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
      hyprland hyprland-guiutils waybar mako rofi fastfetch hyprlock kitty
      nautilus swaybg grim slurp wl-clipboard playerctl brightnessctl
      ImageMagick libnotify fontawesome-6-free-fonts jetbrains-mono-fonts
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

extract_payload() {
  PAYLOAD_DIR="$(mktemp -d)"
  sed -n '/^__DOTFILES_PAYLOAD__$/,$p' "$0" | sed '1d' | base64 --decode | tar -xz -C "${PAYLOAD_DIR}"
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

deploy_payload() {
  local source relative target mode
  while IFS= read -r -d '' source; do
    relative="${source#${PAYLOAD_DIR}/}"
    case "${relative}" in
      config/*) target="${HOME}/.config/${relative#config/}" ;;
      local-bin/*) target="${HOME}/.local/bin/${relative#local-bin/}" ;;
      *) continue ;;
    esac
    mode="$(stat -c '%a' "${source}")"
    install_managed_file "${source}" "${target}" "${mode}"
  done < <(find "${PAYLOAD_DIR}" -type f -print0)
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
    systemctl --user enable --now hypr-wallpaper.service 2>/dev/null || \
      printf '%s\n' 'Aviso: no se pudo iniciar hypr-wallpaper.service en esta sesión.' >&2
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
extract_payload
deploy_payload
configure_iwd
finish_install
exit 0

__DOTFILES_PAYLOAD__
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
