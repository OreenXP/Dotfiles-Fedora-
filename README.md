# Dotfiles Hyprland

Configuración personal de Hyprland, Waybar, SwayNotificationCenter, Mako, Rofi, Fastfetch, Kitty y los scripts auxiliares.

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

El cambio de idioma del teclado usa `us,es`. Pulsa `SUPER + CTRL + Space` para alternar entre English y Español; el idioma activo aparece en el OSD inferior.

El mismo OSD muestra volumen, brillo y estado del micrófono. `SUPER + SHIFT + P` alterna el touchpad y también muestra su estado; en hardware compatible funcionan además las teclas multimedia correspondientes.

SwayNotificationCenter conserva las notificaciones sólo durante la sesión. `SUPER + N` abre o cierra el panel, el botón `Borrar todo` limpia su contenido y Waybar muestra la campana junto al reloj. Mako queda instalado como respaldo si SwayNotificationCenter no está disponible.

Waybar muestra un bloque multimedia junto a la bandeja cuando detecta Spotify o una reproducción de YouTube en Brave. El nombre y el tiempo alternan el reproductor seleccionado al hacer clic; los botones adyacentes permiten ir a la pista anterior, pausar o continuar y avanzar.

Pulsa `SUPER + Esc` para compactar los workspaces numéricos ocupados hacia la izquierda y eliminar huecos entre ellos. Los workspaces especiales no se modifican.

Pulsa `SUPER + C` o haz clic en el icono de teclado de Waybar para abrir en Rofi una tabla buscable con todos los atajos de Hyprland.

`Impr Pant` permite seleccionar una región y copia la captura al portapapeles. Solo puede existir un selector de captura abierto a la vez.

`swayidle` ejecuta Hyprlock antes de suspender el equipo, incluido al cerrar la tapa, y también responde a las solicitudes de bloqueo de la sesión.

El logo de Fastfetch no se versiona. Si quieres conservarlo, crea `~/.local/share/dotfiles/assets/Civic.jpeg` antes de ejecutar Fastfetch.
