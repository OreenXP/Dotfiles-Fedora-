#!/usr/bin/env python3
"""Shared Waybar media controller for Spotify and YouTube in Brave."""

import json
import os
from pathlib import Path
import subprocess
import sys


STATE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "waybar-media-player"
PLAYER_CACHE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "waybar-media-players.json"


def command(*args: str, check: bool = True) -> str:
    result = subprocess.run(
        list(args), text=True, capture_output=True, check=check
    )
    return result.stdout.strip()


def available_players() -> dict[str, str]:
    try:
        players = command("playerctl", "-l").splitlines()
    except (subprocess.CalledProcessError, FileNotFoundError):
        players = []

    found: dict[str, str] = {}
    for player in players:
        lowered = player.lower()
        if "spotify" in lowered and "spotify" not in found:
            found["spotify"] = player
        elif lowered.startswith(("brave", "chromium", "chrome", "google-chrome")):
            found.setdefault("youtube", player)
    try:
        cached = json.loads(PLAYER_CACHE.read_text())
    except (OSError, json.JSONDecodeError):
        cached = {}

    # MPRIS can briefly omit a player while several Waybar modules refresh.
    # Keep its last bus name while the corresponding application still exists.
    if "spotify" not in found and cached.get("spotify"):
        if subprocess.run(["pgrep", "-x", "spotify"], capture_output=True).returncode == 0:
            found["spotify"] = cached["spotify"]
    if "youtube" not in found and cached.get("youtube"):
        browser = cached["youtube"].split(".", 1)[0]
        if subprocess.run(["pgrep", "-x", browser], capture_output=True).returncode == 0:
            found["youtube"] = cached["youtube"]

    if found:
        try:
            PLAYER_CACHE.write_text(json.dumps({**cached, **found}))
        except OSError:
            pass
    return found


def selected_player(players: dict[str, str]) -> tuple[str, str] | None:
    if not players:
        return None
    try:
        selected = STATE.read_text().strip()
    except OSError:
        selected = ""
    if selected not in players:
        selected = "spotify" if "spotify" in players else next(iter(players))
        STATE.write_text(selected)
    return selected, players[selected]


def player(player_name: str, *args: str) -> str:
    return command("playerctl", "-p", player_name, *args)


def clean(value: str) -> str:
    return " ".join(value.split())


def clock(seconds: float) -> str:
    seconds = max(0, round(seconds))
    return f"{seconds // 60}:{seconds % 60:02d}"


def output(text: str, classes=None, tooltip: str = "") -> None:
    if isinstance(classes, (list, tuple)):
        css_class = "-".join(classes)
    else:
        css_class = classes or "empty"
    print(json.dumps({
        "text": text,
        "class": css_class,
        "tooltip": tooltip,
    }, ensure_ascii=False))


mode = sys.argv[1] if len(sys.argv) > 1 else "info"
players = available_players()
selected = selected_player(players)

if mode == "available":
    raise SystemExit(0 if selected else 1)

if not selected:
    if mode == "icon-plain":
        print("")
    else:
        output("")
    raise SystemExit(0)

kind, player_name = selected

if mode == "icon-plain":
    print("" if kind == "spotify" else "")
    raise SystemExit(0)

if mode == "switch":
    choices = [name for name in ("spotify", "youtube") if name in players]
    if len(choices) > 1:
        next_kind = choices[(choices.index(kind) + 1) % len(choices)]
        STATE.write_text(next_kind)
    raise SystemExit(0)

if mode.startswith("control-"):
    action = mode.removeprefix("control-")
    subprocess.run(
        ["playerctl", "-p", player_name, action],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    raise SystemExit(0)

if mode == "previous":
    output("", [kind], "Anterior")
    raise SystemExit(0)

if mode == "next":
    output("", [kind], "Siguiente")
    raise SystemExit(0)

try:
    status = player(player_name, "status")
except subprocess.CalledProcessError:
    status = "Paused"

classes = [kind, status.lower()]
label = "Spotify" if kind == "spotify" else "YouTube"

if mode == "icon":
    icon = "" if kind == "spotify" else ""
    others = ["Spotify" if name == "spotify" else "YouTube" for name in players if name != kind]
    tooltip = f"{label} activo"
    if others:
        tooltip += f"\nClic para cambiar a {others[0]}"
    output(f'<span font_family="Font Awesome 6 Brands">{icon}</span>', classes, tooltip)
    raise SystemExit(0)

if mode == "toggle":
    icon = "" if status == "Playing" else ""
    output(icon, classes, "Pausar" if status == "Playing" else "Reproducir")
    raise SystemExit(0)

try:
    metadata = player(
        player_name,
        "metadata",
        "--format",
        "{{artist}}\t{{title}}\t{{mpris:length}}",
    ).split("\t", 2)
    artist = clean(metadata[0])
    title = clean(metadata[1])
    length_us = int(metadata[2] or 0)
    position = float(player(player_name, "position"))
except (subprocess.CalledProcessError, ValueError, IndexError):
    artist, title, length_us, position = "", label, 0, 0

track = " — ".join(part for part in (artist, title) if part) or label
short_track = track if len(track) <= 38 else track[:37].rstrip() + "…"
elapsed = clock(position)
duration = clock(length_us / 1_000_000) if length_us else "--:--"
output(
    f"{short_track}  {elapsed}/{duration}",
    classes,
    f"{label}\n{track}\n{elapsed} / {duration}\nClic para cambiar de reproductor",
)
