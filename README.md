# Dotfiles Hyprland

Configuración personal de Hyprland, Waybar, Mako, Rofi, Fastfetch, Kitty y los scripts auxiliares.

## Instalación

Desde el directorio del repositorio:

```bash
./install.sh
```

Para actualizar otra PC después de subir cambios nuevos:

```bash
./install.sh
```

`install.sh` es el único script principal del repositorio. La primera ejecución instala todo; las siguientes hacen `git pull`, se relanzan si llegó una versión nueva y aplican la configuración actualizada sin duplicar archivos.

El instalador:

- instala dependencias de Fedora usando `dnf`;
- instala Impala, Bluetui e `iwd` y ofrece configurar `iwd` como gestor Wi-Fi;
- instala Font Awesome, JetBrains Mono y descarga `Symbols Nerd Font` para los iconos;
- crea una copia de seguridad únicamente cuando un archivo instalado cambia;
- instala y habilita los servicios `hypr-wallpaper.service` y `swayidle.service` para el usuario;
- conserva los fondos fuera del repositorio en `~/Documentos/Wallpapers`.

El archivo `config/hypr/hyprland.lua` es el archivo de configuración principal de Hyprland. El monitor `eDP-1`, el teclado `us` y los programas definidos reflejan la configuración actual.

El cambio de idioma del teclado usa `us,es`. Pulsa `SUPER + CTRL + Space` para alternar entre English y Español; el idioma activo aparece como una notificación OSD.

Pulsa `SUPER + Esc` para compactar los workspaces numéricos ocupados hacia la izquierda y eliminar huecos entre ellos. Los workspaces especiales no se modifican.

`swayidle` ejecuta Hyprlock antes de suspender el equipo, incluido al cerrar la tapa, y también responde a las solicitudes de bloqueo de la sesión.

El logo de Fastfetch no se versiona. Si quieres conservarlo, crea `~/.local/share/dotfiles/assets/Civic.jpeg` antes de ejecutar Fastfetch.
