#!/usr/bin/env python3
"""Image-only Rofi wallpaper picker and persistent swaybg launcher."""
import fcntl
import hashlib
import os
from pathlib import Path
import subprocess
import sys

HOME = Path.home()
WALLPAPERS = HOME / "Documentos/Wallpapers"
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "hypr-wallpaper/selected"
THEME = Path(__file__).resolve().parent.parent / "wallpaper-picker.rasi"


def files():
    return sorted(p for p in WALLPAPERS.rglob("*") if p.is_file()
                  and p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp", ".bmp"))


def main():
    if "--restore" in sys.argv:
        selected = Path(STATE.read_text().strip()) if STATE.exists() else None
        if selected is None or not selected.is_file():
            selected = next(iter(files()), None)
        args = ["swaybg", "-c", "0b0b0b"]
        if selected:
            args += ["-i", str(selected), "-m", "fill"]
        os.execvp(args[0], args)
    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    with (runtime / "wallpaper-picker.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        cache = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "wallpaper-picker"
        cache.mkdir(parents=True, exist_ok=True)
        candidates, rows = [], []
        for path in files():
            stat = path.stat()
            key = hashlib.sha256(f"{path}:{stat.st_mtime_ns}:{stat.st_size}".encode()).hexdigest()
            thumb = cache / (key + ".png")
            if not thumb.exists():
                result = subprocess.run(["magick", str(path) + "[0]", "-auto-orient",
                                         "-thumbnail", "240x135^", "-gravity", "center",
                                         "-extent", "240x135", str(thumb)], capture_output=True)
                if result.returncode:
                    continue
            rows.append(f"{len(candidates)}\0icon\x1f{thumb}\n")
            candidates.append(path)
        if not rows:
            subprocess.run(["notify-send", "Fondos de pantalla", f"Añade imágenes a {WALLPAPERS}"])
            return
        chosen = subprocess.run(["rofi", "-no-config", "-dmenu", "-show-icons", "-no-custom",
                                 "-format", "i", "-theme", str(THEME)],
                                input="".join(rows), text=True, capture_output=True)
        if chosen.returncode or not chosen.stdout.strip().isdigit():
            return
        index = int(chosen.stdout.strip())
        if not 0 <= index < len(candidates):
            return
        STATE.parent.mkdir(parents=True, exist_ok=True)
        temporary = STATE.with_suffix(".tmp")
        temporary.write_text(str(candidates[index]) + "\n")
        temporary.replace(STATE)
        subprocess.run(["systemctl", "--user", "restart", "hypr-wallpaper.service"], check=True)


if __name__ == "__main__":
    main()
