"""
Recent files component for the main window.
Displays a table of recently converted files.
"""
from __future__ import annotations

import os
import subprocess  # nosec B404
import tkinter as tk
from datetime import datetime


def create_recent_files_section(
    parent: tk.Widget,
    colors: dict[str, str],
    recent_files: list[dict[str, str]],
) -> tk.Frame:
    """
    Create the recent files section as a table.

    Args:
        parent: Parent widget to attach to.
        colors: Theme color dictionary.
        recent_files: List of recent file dicts with 'source', 'output', 'timestamp' keys.

    Returns:
        Frame containing the recent files table.
    """
    c = colors

    recent_frame = tk.Frame(parent, bg=c["bg"])
    recent_frame.pack(fill=tk.X, pady=(0, 10))

    # Handle old format (list of strings) - skip
    if recent_files and isinstance(recent_files[0], str):
        return recent_frame

    # Filter to valid entries with existing files
    valid_recents = []
    for r in recent_files:
        if isinstance(r, dict) and r.get("source") and os.path.exists(r.get("source", "")):
            valid_recents.append(r)

    if not valid_recents:
        return recent_frame

    # Header
    tk.Label(
        recent_frame,
        text="Recent Conversions:",
        bg=c["bg"],
        fg=c["muted"],
        font=("Segoe UI", 9, "bold"),
    ).pack(anchor=tk.W, pady=(0, 5))

    # Table frame
    table = tk.Frame(recent_frame, bg=c["bg"])
    table.pack(fill=tk.X)

    # Column headers
    tk.Label(
        table,
        text="Date",
        bg=c["bg"],
        fg=c["muted"],
        font=("Segoe UI", 8),
        width=10,
        anchor=tk.W,
    ).grid(row=0, column=0, sticky="w")
    tk.Label(
        table,
        text="Source",
        bg=c["bg"],
        fg=c["muted"],
        font=("Segoe UI", 8),
        anchor=tk.W,
    ).grid(row=0, column=1, sticky="w", padx=(5, 0))
    tk.Label(
        table,
        text="Output",
        bg=c["bg"],
        fg=c["muted"],
        font=("Segoe UI", 8),
        anchor=tk.W,
    ).grid(row=0, column=2, sticky="w", padx=(5, 0))

    for i, entry in enumerate(valid_recents[:5], start=1):
        # Parse date
        try:
            dt = datetime.fromisoformat(entry.get("timestamp", ""))
            date_str = dt.strftime("%m/%d/%Y")
        except Exception:
            date_str = "Unknown"

        source_path = entry.get("source", "")
        output_path = entry.get("output", "")

        # Date label
        tk.Label(
            table,
            text=date_str,
            bg=c["bg"],
            fg=c["fg"],
            font=("Segoe UI", 8),
            anchor=tk.W,
        ).grid(row=i, column=0, sticky="w")

        # Source link (opens folder in explorer)
        source_name = (
            os.path.basename(source_path)[:40] + "..."
            if len(os.path.basename(source_path)) > 40
            else os.path.basename(source_path)
        )
        src_lbl = tk.Label(
            table,
            text=source_name,
            bg=c["bg"],
            fg=c["accent"],
            cursor="hand2",
            font=("Segoe UI", 8, "underline"),
            anchor=tk.W,
        )
        src_lbl.grid(row=i, column=1, sticky="w", padx=(5, 0))
        src_folder = os.path.dirname(source_path)
        src_lbl.bind(
            "<Button-1>",
            lambda e, f=src_folder: subprocess.Popen(
                ["explorer", f]
            ),  # nosec B603 B607 - Safe: user-selected folder path
        )

        # Output link (opens folder in explorer)
        if output_path and os.path.exists(output_path):
            out_name = (
                os.path.basename(output_path)[:40] + "..."
                if len(os.path.basename(output_path)) > 40
                else os.path.basename(output_path)
            )
            out_lbl = tk.Label(
                table,
                text=out_name,
                bg=c["bg"],
                fg=c["accent"],
                cursor="hand2",
                font=("Segoe UI", 8, "underline"),
                anchor=tk.W,
            )
            out_lbl.grid(row=i, column=2, sticky="w", padx=(5, 0))
            out_folder = os.path.dirname(output_path)
            out_lbl.bind(
                "<Button-1>",
                lambda e, f=out_folder: subprocess.Popen(
                    ["explorer", f]
                ),  # nosec B603 B607 - Safe: user-selected folder path
            )
        else:
            tk.Label(
                table,
                text="-",
                bg=c["bg"],
                fg=c["muted"],
                font=("Segoe UI", 8),
                anchor=tk.W,
            ).grid(row=i, column=2, sticky="w", padx=(5, 0))

    return recent_frame


def refresh_recent_files(
    recent_frame: tk.Frame,
    colors: dict[str, str],
    recent_files: list[dict[str, str]],
) -> None:
    """
    Refresh the recent files display.

    Args:
        recent_frame: Frame containing recent files (will be cleared).
        colors: Theme color dictionary.
        recent_files: List of recent file dicts.
    """
    # Clear existing
    for widget in recent_frame.winfo_children():
        widget.destroy()

    # Handle old format (list of strings) - skip
    if recent_files and isinstance(recent_files[0], str):
        return

    # Filter to valid entries with existing files
    valid_recents = []
    for r in recent_files:
        if isinstance(r, dict) and r.get("source") and os.path.exists(r.get("source", "")):
            valid_recents.append(r)

    if not valid_recents:
        return

    c = colors

    # Header
    tk.Label(
        recent_frame,
        text="Recent Conversions:",
        bg=c["bg"],
        fg=c["muted"],
        font=("Segoe UI", 9, "bold"),
    ).pack(anchor=tk.W, pady=(0, 5))

    # Table frame
    table = tk.Frame(recent_frame, bg=c["bg"])
    table.pack(fill=tk.X)

    # Column headers
    tk.Label(
        table,
        text="Date",
        bg=c["bg"],
        fg=c["muted"],
        font=("Segoe UI", 8),
        width=10,
        anchor=tk.W,
    ).grid(row=0, column=0, sticky="w")
    tk.Label(
        table,
        text="Source",
        bg=c["bg"],
        fg=c["muted"],
        font=("Segoe UI", 8),
        anchor=tk.W,
    ).grid(row=0, column=1, sticky="w", padx=(5, 0))
    tk.Label(
        table,
        text="Output",
        bg=c["bg"],
        fg=c["muted"],
        font=("Segoe UI", 8),
        anchor=tk.W,
    ).grid(row=0, column=2, sticky="w", padx=(5, 0))

    for i, entry in enumerate(valid_recents[:5], start=1):
        # Parse date
        try:
            dt = datetime.fromisoformat(entry.get("timestamp", ""))
            date_str = dt.strftime("%m/%d/%Y")
        except Exception:
            date_str = "Unknown"

        source_path = entry.get("source", "")
        output_path = entry.get("output", "")

        # Date label
        tk.Label(
            table,
            text=date_str,
            bg=c["bg"],
            fg=c["fg"],
            font=("Segoe UI", 8),
            anchor=tk.W,
        ).grid(row=i, column=0, sticky="w")

        # Source link (opens folder in explorer)
        source_name = (
            os.path.basename(source_path)[:40] + "..."
            if len(os.path.basename(source_path)) > 40
            else os.path.basename(source_path)
        )
        src_lbl = tk.Label(
            table,
            text=source_name,
            bg=c["bg"],
            fg=c["accent"],
            cursor="hand2",
            font=("Segoe UI", 8, "underline"),
            anchor=tk.W,
        )
        src_lbl.grid(row=i, column=1, sticky="w", padx=(5, 0))
        src_folder = os.path.dirname(source_path)
        src_lbl.bind(
            "<Button-1>",
            lambda e, f=src_folder: subprocess.Popen(
                ["explorer", f]
            ),  # nosec B603 B607 - Safe: user-selected folder path
        )

        # Output link (opens folder in explorer)
        if output_path and os.path.exists(output_path):
            out_name = (
                os.path.basename(output_path)[:40] + "..."
                if len(os.path.basename(output_path)) > 40
                else os.path.basename(output_path)
            )
            out_lbl = tk.Label(
                table,
                text=out_name,
                bg=c["bg"],
                fg=c["accent"],
                cursor="hand2",
                font=("Segoe UI", 8, "underline"),
                anchor=tk.W,
            )
            out_lbl.grid(row=i, column=2, sticky="w", padx=(5, 0))
            out_folder = os.path.dirname(output_path)
            out_lbl.bind(
                "<Button-1>",
                lambda e, f=out_folder: subprocess.Popen(
                    ["explorer", f]
                ),  # nosec B603 B607 - Safe: user-selected folder path
            )
        else:
            tk.Label(
                table,
                text="-",
                bg=c["bg"],
                fg=c["muted"],
                font=("Segoe UI", 8),
                anchor=tk.W,
            ).grid(row=i, column=2, sticky="w", padx=(5, 0))

