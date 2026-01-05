"""
Header component for the main window.
Includes app icon, title, version, and links.
"""
from __future__ import annotations

import os
import subprocess  # nosec B404
import sys
import tkinter as tk
from tkinter import ttk


def get_resource_path(relative_path: str) -> str:
    """Get absolute path to resource, works for dev and for PyInstaller."""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        # In dev mode, navigate from components -> app -> ui -> src -> project root
        script_dir = os.path.dirname(os.path.abspath(__file__))
        # components -> app -> ui -> src -> root
        root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(script_dir))))
        base_path = root_dir

    path = os.path.join(base_path, relative_path)
    if not os.path.exists(path):
        # Try parent directory (for resources in root)
        parent_path = os.path.join(os.path.dirname(base_path), relative_path)
        if os.path.exists(parent_path):
            return parent_path
    return path


def create_header(
    parent: tk.Widget,
    colors: dict[str, str],
    on_changelog_click: callable,
) -> tk.Frame:
    """
    Create the header section with icon, title, version, and links.

    Args:
        parent: Parent widget to attach to.
        colors: Theme color dictionary.
        on_changelog_click: Callback when changelog link is clicked.

    Returns:
        Frame containing the header.
    """
    c = colors

    # Header Row: Icon + Title + Version side by side
    header_frame = tk.Frame(parent, bg=c["bg"])
    header_frame.pack(pady=(0, 5))

    # App Icon (PNG) - shown to left of title
    try:
        png_path = get_resource_path(os.path.join("resources", "markify_icon.png"))
        if os.path.exists(png_path):
            app_icon_image = tk.PhotoImage(file=png_path)
            # Subsample to make it ~40px (smaller for inline with title)
            app_icon_image = app_icon_image.subsample(3, 3)
            icon_label = tk.Label(header_frame, image=app_icon_image, bg=c["bg"])
            icon_label.pack(side=tk.LEFT, padx=(0, 10))
            # Keep reference to prevent garbage collection
            icon_label.image = app_icon_image
    except Exception:  # nosec B110 - Safe: icon loading is optional, gracefully degrade
        pass  # If icon fails, just skip it

    # Title (to right of icon)
    title_label = ttk.Label(header_frame, text="Markify", style="Title.TLabel")
    title_label.pack(side=tk.LEFT)

    # Version (to right of title)
    ver_label = ttk.Label(header_frame, text="v1.0.0", style="Sub.TLabel")
    ver_label.pack(side=tk.LEFT, padx=(10, 0))

    # GitHub Link
    github_link = tk.Label(
        parent,
        text="github.com/swolfe2/Markify",
        bg=colors["bg"],
        fg=colors["accent"],
        font=("Segoe UI", 9, "underline"),
        cursor="hand2",
    )
    github_link.pack(pady=(0, 5))
    github_link.bind(
        "<Button-1>",
        lambda e: subprocess.Popen(  # nosec B602 B607 - Safe: fixed URL, user-initiated action
            ["start", "https://github.com/swolfe2/Markify"], shell=True
        ),
    )

    # What's New link (clickable text)
    whatsnew_link = tk.Label(
        parent,
        text="📋 What's New in v1.0.0",
        bg=colors["bg"],
        fg=colors["muted"],
        font=("Segoe UI", 9, "underline"),
        cursor="hand2",
    )
    whatsnew_link.pack(pady=(0, 15))
    whatsnew_link.bind("<Button-1>", lambda e: on_changelog_click())

    return header_frame

