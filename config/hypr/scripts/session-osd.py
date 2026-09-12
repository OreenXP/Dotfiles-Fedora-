#!/usr/bin/env python3
"""Small session-only Hyprland OSD for levels and keyboard layout."""

import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time


RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
SOCKET = RUNTIME / "hypr-session-osd.sock"


def send(payload: dict) -> None:
    data = json.dumps(payload).encode()
    client = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    try:
        client.sendto(data, str(SOCKET))
        return
    except OSError:
        pass
    finally:
        client.close()

    subprocess.Popen(
        [sys.executable, __file__, "--daemon"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    for _ in range(20):
        time.sleep(0.025)
        client = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        try:
            client.sendto(data, str(SOCKET))
            return
        except OSError:
            pass
        finally:
            client.close()


def daemon() -> None:
    import gi

    gi.require_version("Gtk", "3.0")
    gi.require_version("GtkLayerShell", "0.1")
    from gi.repository import GLib, Gtk, GtkLayerShell

    try:
        SOCKET.unlink()
    except FileNotFoundError:
        pass

    server = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    server.bind(str(SOCKET))
    server.setblocking(False)

    window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
    window.set_name("session-osd")
    window.set_decorated(False)
    window.set_accept_focus(False)
    window.set_size_request(340, 80)

    GtkLayerShell.init_for_window(window)
    GtkLayerShell.set_namespace(window, "hypr-session-osd")
    GtkLayerShell.set_layer(window, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.BOTTOM, True)
    GtkLayerShell.set_margin(window, GtkLayerShell.Edge.BOTTOM, 60)
    GtkLayerShell.set_keyboard_mode(window, GtkLayerShell.KeyboardMode.NONE)

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    box.set_border_width(12)
    title = Gtk.Label()
    title.set_name("osd-title")
    title.set_xalign(0.5)
    progress = Gtk.ProgressBar()
    progress.set_name("osd-progress")
    subtitle = Gtk.Label()
    subtitle.set_name("osd-subtitle")
    subtitle.set_xalign(0.5)
    box.pack_start(title, False, False, 0)
    box.pack_start(progress, False, False, 0)
    box.pack_start(subtitle, False, False, 0)
    window.add(box)

    css = b"""
      #session-osd {
        background-color: #0b0b0b;
        border: 1px solid #2a2a2a;
        border-radius: 0;
      }
      #osd-title, #osd-subtitle {
        color: #e6e6e6;
        font-family: "JetBrains Mono", "Symbols Nerd Font Mono", "Font Awesome 6 Free";
        font-size: 12px;
        font-weight: 400;
      }
      #osd-subtitle { color: #9a9a9a; }
      #osd-progress { min-height: 4px; }
      #osd-progress trough {
        min-height: 4px;
        background-color: #2a2a2a;
        border: 0;
        border-radius: 0;
      }
      #osd-progress progress {
        min-height: 4px;
        background-color: #d1d5db;
        border: 0;
        border-radius: 0;
      }
    """
    provider = Gtk.CssProvider()
    provider.load_from_data(css)
    Gtk.StyleContext.add_provider_for_screen(
        window.get_screen(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    hide_source = 0

    def hide():
        window.hide()
        return GLib.SOURCE_REMOVE

    def receive(_source, _condition):
        nonlocal hide_source
        try:
            payload = json.loads(server.recv(4096).decode())
        except (BlockingIOError, json.JSONDecodeError):
            return True

        icon = payload.get("icon", "")
        heading = payload.get("title", "")
        title.set_text(f"{icon}  {heading}" if icon else heading)
        if payload.get("kind") == "level":
            progress.set_fraction(max(0, min(100, int(payload.get("value", 0)))) / 100)
            progress.show()
            subtitle.hide()
            window.set_size_request(340, 80)
        else:
            subtitle.set_text(payload.get("text", ""))
            subtitle.show()
            progress.hide()
            window.set_size_request(340, 80)

        window.show_all()
        if payload.get("kind") == "text":
            progress.hide()
        else:
            subtitle.hide()
        if hide_source:
            GLib.source_remove(hide_source)
        hide_source = GLib.timeout_add(1500, hide)
        return True

    GLib.io_add_watch(server.fileno(), GLib.IO_IN, receive)
    try:
        Gtk.main()
    finally:
        server.close()
        try:
            SOCKET.unlink()
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--daemon":
        daemon()
    elif len(sys.argv) in (4, 5) and sys.argv[1] == "level":
        send({
            "kind": "level",
            "title": sys.argv[2],
            "value": int(sys.argv[3]),
            "icon": sys.argv[4] if len(sys.argv) == 5 else "",
        })
    elif len(sys.argv) in (4, 5) and sys.argv[1] == "text":
        send({
            "kind": "text",
            "title": sys.argv[2],
            "text": sys.argv[3],
            "icon": sys.argv[4] if len(sys.argv) == 5 else "",
        })
    else:
        raise SystemExit(f"Uso: {sys.argv[0]} level TITULO VALOR | text TITULO TEXTO")
