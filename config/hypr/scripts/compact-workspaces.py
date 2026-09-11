#!/usr/bin/env python3
"""Compact numeric Hyprland workspaces so the occupied ones are consecutive."""

import fcntl
import json
import subprocess
import sys


def hyprctl_json(command: str):
    result = subprocess.run(
        ["hyprctl", "-j", command],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def evaluate(code: str) -> None:
    subprocess.run(
        ["hyprctl", "eval", code],
        check=True,
        stdout=subprocess.DEVNULL,
    )


def move_window(address: str, workspace: int) -> None:
    evaluate(
        "return hl.dispatch(hl.dsp.window.move({ "
        f'workspace = {workspace}, window = "address:{address}", follow = false'
        " }))"
    )


def focus_workspace(workspace: int) -> None:
    evaluate(f"return hl.dispatch(hl.dsp.focus({{ workspace = {workspace} }}))")


def main() -> int:
    # Impide que dos pulsaciones rápidas mezclen sus movimientos.
    lock_file = open("/tmp/hypr-compact-workspaces.lock", "w", encoding="utf-8")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return 0

    clients = hyprctl_json("clients")
    active_id = int(hyprctl_json("activeworkspace").get("id", 0))

    occupied = sorted(
        {
            int(client.get("workspace", {}).get("id", 0))
            for client in clients
            if int(client.get("workspace", {}).get("id", 0)) > 0
        }
    )
    if not occupied:
        return 0

    destinations = {source: index for index, source in enumerate(occupied, 1)}

    # Mueve cada workspace de izquierda a derecha. Así se libera primero el
    # destino siguiente y Hyprland no rechaza un movimiento por estar ocupado.
    for source in occupied:
        destination = destinations[source]
        if destination == source:
            continue
        for client in clients:
            client_workspace = int(client.get("workspace", {}).get("id", 0))
            address = client.get("address")
            if client_workspace == source and address:
                move_window(address, destination)

    # Mantiene visible el grupo de ventanas que estaba usando el usuario.
    if active_id in destinations:
        destination = destinations[active_id]
    elif active_id > len(occupied):
        destination = len(occupied)
    else:
        destination = active_id

    if destination > 0 and destination != active_id:
        focus_workspace(destination)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (json.JSONDecodeError, OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"No se pudieron compactar los workspaces: {error}", file=sys.stderr)
        raise SystemExit(1)
