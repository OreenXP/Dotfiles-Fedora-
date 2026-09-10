# Dotfiles Hyprland

Configuración personal de Hyprland, Waybar, Mako, Rofi, Fastfetch, Kitty y los scripts auxiliares.

## Instalación

Desde el directorio del repositorio:

```bash
./install.sh
```

El instalador:

- instala dependencias usando `dnf`, `pacman` o `apt-get`;
- crea una copia de seguridad de cualquier configuración existente;
- instala el servicio `hypr-wallpaper.service` y lo habilita para el usuario;
- conserva los fondos fuera del repositorio en `~/Documentos/Wallpapers`.

El archivo `config/hypr/hyprland.lua` es el archivo de configuración principal de Hyprland. El monitor `eDP-1`, el teclado `us` y los programas definidos reflejan la configuración actual.

El cambio de idioma del teclado usa `us,es`. Pulsa `SUPER + CTRL + Space` para alternar entre English y Español; el idioma activo aparece como una notificación OSD.

El logo de Fastfetch no se versiona. Si quieres conservarlo, crea `~/.local/share/dotfiles/assets/Civic.jpeg` antes de ejecutar Fastfetch.
