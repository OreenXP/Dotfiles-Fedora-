#!/usr/bin/env python3
"""Toggle the laptop touchpad and report its state through the session OSD."""

import fcntl
import os
from pathlib import Path
import subprocess
import sys


DEVICE = "elan0001:00-04f3:31ad-touchpad"
runtime = Path(os.environ["XDG_RUNTIME_DIR"])
state_file = runtime / "hypr-touchpad-disabled"


def show(enabled: bool) -> None:
    subprocess.run([
        str(Path(__file__).with_name("session-osd.py")),
        "text",
        "Touchpad",
        "Activo" if enabled else "Bloqueado",
        "" if enabled else "",
    ], check=True)


action = sys.argv[1] if len(sys.argv) == 2 else "toggle"
if action not in ("toggle", "on", "off", "show"):
    raise SystemExit(f"Uso: {sys.argv[0]} [toggle|on|off|show]")

with (runtime / "hypr-touchpad.lock").open("w") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    enabled = not state_file.exists()

    if action != "show":
        if action == "toggle":
            enabled = not enabled
        else:
            enabled = action == "on"
        lua_enabled = "true" if enabled else "false"
        code = (
            "return hl.device({ "
            f'name = "{DEVICE}", enabled = {lua_enabled}'
            " })"
        )
        subprocess.run(["hyprctl", "eval", code], check=True)
        if enabled:
            state_file.unlink(missing_ok=True)
        else:
            state_file.touch()

    show(enabled)
