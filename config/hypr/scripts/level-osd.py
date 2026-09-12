#!/usr/bin/env python3
"""Adjust audio/backlight and update the session OSD."""
import fcntl
import os
from pathlib import Path
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args, text=True).strip()


kind, action = sys.argv[1:]
if kind not in ("volume", "brightness", "microphone") or action not in ("up", "down", "mute", "show"):
    raise SystemExit("Usage: level-osd.py volume|brightness|microphone up|down|mute|show")
runtime = Path(os.environ["XDG_RUNTIME_DIR"])
with (runtime / "hypr-level-osd.lock").open("w") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    if kind == "microphone":
        if action not in ("mute", "show"):
            raise SystemExit("Microphone only supports mute or show")
        source = "@DEFAULT_AUDIO_SOURCE@"
        if action == "mute":
            run("wpctl", "set-mute", source, "toggle")
        status = run("wpctl", "get-volume", source)
        muted = "MUTED" in status
        state = "Silenciado" if muted else "Activo"
        icon = "" if muted else ""
        subprocess.run([
            str(Path(__file__).with_name("session-osd.py")),
            "text", "Micrófono", state, icon,
        ], check=True)
        raise SystemExit(0)
    elif kind == "volume":
        sink = "@DEFAULT_AUDIO_SINK@"
        if action in ("up", "down"):
            run("wpctl", "set-volume", "-l", "1", sink, "5%+" if action == "up" else "5%-")
        elif action == "mute":
            run("wpctl", "set-mute", sink, "toggle")
        status = run("wpctl", "get-volume", sink)
        level = round(float(status.split()[1]) * 100)
        muted = "MUTED" in status
        title = "Volumen · Silenciado" if muted else f"Volumen · {level}%"
        value = 0 if muted else level
        icon = "" if muted else ""
    else:
        if action == "mute":
            raise SystemExit("Brightness does not support mute")
        if action in ("up", "down"):
            run("brightnessctl", "-e4", "-n2", "set", "5%+" if action == "up" else "5%-")
        current = int(run("brightnessctl", "get"))
        maximum = int(run("brightnessctl", "max"))
        level = round(current * 100 / maximum)
        title, value = f"Brillo · {level}%", level
        icon = ""
    value = max(0, min(100, value))
    subprocess.run([
        str(Path(__file__).with_name("session-osd.py")),
        "level", title, str(value), icon,
    ], check=True)
