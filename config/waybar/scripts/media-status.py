#!/usr/bin/env python3
"""Shared Waybar media controller for Spotify and YouTube in Brave."""

import json
import os
from pathlib import Path
import subprocess
import sys
import time


STATE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "waybar-media-player"
PLAYER_CACHE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "waybar-media-players.json"
CACHE_GRACE_SECONDS = 2.0


def command(*args: str, check: bool = True) -> str:
    result = subprocess.run(
        list(args), text=True, capture_output=True, check=check
    )
    # Preserve leading tabs: playerctl uses them for empty metadata fields.
    return result.stdout.rstrip("\n")


def browser_media_is_youtube(player_name: str) -> bool:
    """Reject browser players whose metadata clearly belongs to another site."""
    try:
        metadata = command(
            "playerctl", "-p", player_name, "metadata", "--format",
            "{{xesam:url}}\t{{album}}\t{{title}}",
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

    url, album, title = (metadata.split("\t", 2) + ["", "", ""])[:3]
    identifying_text = f"{url} {album} {title}".lower()
    if "youtube.com" in identifying_text or "youtu.be" in identifying_text:
        return True
    if album.strip().lower() == "youtube" or title.strip().lower().endswith(" - youtube"):
        return True

    # Chromium does not always publish the page URL. These suffixes identify
    # common non-YouTube media sessions without rejecting normal video titles.
    other_sites = (" / x", " | tiktok", " - twitch", " • instagram", " | facebook")
    return not title.strip().lower().endswith(other_sites)


def available_players() -> dict[str, str]:
    try:
        players = command("playerctl", "-l").splitlines()
    except (subprocess.CalledProcessError, FileNotFoundError):
        players = []

    detected: dict[str, str] = {}
    for player in players:
        lowered = player.lower()
        if "spotify" in lowered and "spotify" not in detected:
            detected["spotify"] = player
        elif (
            lowered.startswith(("brave", "chromium", "chrome", "google-chrome"))
            and browser_media_is_youtube(player)
        ):
            detected.setdefault("youtube", player)
    try:
        raw_cache = json.loads(PLAYER_CACHE.read_text())
    except (OSError, json.JSONDecodeError):
        raw_cache = {}

    # MPRIS can briefly omit a player while several Waybar modules refresh.
    # Retain its bus name only for a short grace period. Checking whether Brave
    # is running is insufficient because the browser can remain open after the
    # YouTube tab has been closed.
    now = time.time()
    cached: dict[str, dict[str, object]] = {}
    if isinstance(raw_cache, dict):
        for kind, entry in raw_cache.items():
            if isinstance(entry, dict):
                player = entry.get("player")
                last_seen = entry.get("last_seen")
                if isinstance(player, str) and isinstance(last_seen, (int, float)):
                    cached[kind] = {"player": player, "last_seen": float(last_seen)}

    found = dict(detected)
    next_cache: dict[str, dict[str, object]] = {}
    for kind, player_name in detected.items():
        next_cache[kind] = {"player": player_name, "last_seen": now}
    for kind, entry in cached.items():
        age = now - float(entry["last_seen"])
        if kind not in detected and age <= CACHE_GRACE_SECONDS:
            found[kind] = str(entry["player"])
            next_cache[kind] = entry

    try:
        PLAYER_CACHE.write_text(json.dumps(next_cache))
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
