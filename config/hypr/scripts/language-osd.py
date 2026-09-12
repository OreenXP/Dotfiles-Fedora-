#!/usr/bin/env python3
"""Switch the keyboard layout and show it in the session OSD."""
import json
from pathlib import Path
import subprocess


def run(*args):
    return subprocess.check_output(args, text=True).strip()


subprocess.run(["hyprctl", "switchxkblayout", "current", "next"], check=True)
devices = json.loads(run("hyprctl", "-j", "devices"))
keyboards = devices.get("keyboards", [])
layout = next((keyboard.get("active_keymap", "") for keyboard in keyboards if keyboard.get("main")), "")

if "Spanish" in layout or "es" in layout.lower():
    language = "Español"
elif "English" in layout or "us" in layout.lower():
    language = "English"
else:
    language = layout or "Desconocido"

subprocess.run([
    str(Path(__file__).with_name("session-osd.py")),
    "text", "Idioma", language, "",
], check=True)
