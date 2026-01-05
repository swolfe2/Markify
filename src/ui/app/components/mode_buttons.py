"""
Mode buttons component for the main window.
Includes Clipboard, Watch, MD→DOCX, and Diff buttons.
"""
from __future__ import annotations

import tkinter as tk


def create_mode_buttons(
    parent: tk.Widget,
    colors: dict[str, str],
    on_clipboard: callable,
    on_watch: callable,
    on_md_to_docx: callable,
    on_diff: callable,
) -> tuple[tk.Button, tk.Button, tk.Button, tk.Button]:
    """
    Create the mode buttons grid (Clipboard, Watch, MD→DOCX, Diff).

    Args:
        parent: Parent widget to attach to.
        colors: Theme color dictionary.
        on_clipboard: Callback for Clipboard button.
        on_watch: Callback for Watch Mode button.
        on_md_to_docx: Callback for MD→DOCX button.
        on_diff: Callback for Diff View button.

    Returns:
        Tuple of (clipboard_btn, watch_btn, reverse_btn, diff_btn).
    """
    c = colors

    # Mode Buttons (Grid Layout - Scalable)
    mode_frame = tk.Frame(parent, bg=c["bg"])
    mode_frame.pack(fill=tk.X, padx=40, pady=(0, 15))
    mode_frame.columnconfigure(0, weight=1)
    mode_frame.columnconfigure(1, weight=1)
    mode_frame.rowconfigure(0, weight=1)
    mode_frame.rowconfigure(1, weight=1)

    # Row 0, Col 0: Clipboard Mode
    clipboard_container = tk.Frame(mode_frame, bg=c["bg"])
    clipboard_container.grid(row=0, column=0, sticky="nsew", padx=(0, 5), pady=(0, 10))

    clipboard_btn = tk.Button(
        clipboard_container,
        text="📋 CLIPBOARD",
        font=("Segoe UI", 10, "bold"),
        bg=c["secondary_bg"],
        fg=c["fg"],
        activebackground=c["border"],
        activeforeground=c["fg"],
        relief=tk.FLAT,
        cursor="hand2",
        command=on_clipboard,
        pady=8,
    )
    clipboard_btn.pack(fill=tk.X)

    tk.Label(
        clipboard_container,
        text="Paste text → Markdown",
        bg=c["bg"],
        fg=c.get("fg_secondary", c["fg"]),
        font=("Segoe UI", 8),
    ).pack(pady=(3, 0))

    # Row 0, Col 1: Watch Mode
    watch_container = tk.Frame(mode_frame, bg=c["bg"])
    watch_container.grid(row=0, column=1, sticky="nsew", padx=(5, 0), pady=(0, 10))

    watch_btn = tk.Button(
        watch_container,
        text="👁 WATCH MODE",
        font=("Segoe UI", 10, "bold"),
        bg=c["secondary_bg"],
        fg=c["fg"],
        activebackground=c["border"],
        activeforeground=c["fg"],
        relief=tk.FLAT,
        cursor="hand2",
        command=on_watch,
        pady=8,
    )
    watch_btn.pack(fill=tk.X)

    tk.Label(
        watch_container,
        text="Auto-convert folder",
        bg=c["bg"],
        fg=c.get("fg_secondary", c["fg"]),
        font=("Segoe UI", 8),
    ).pack(pady=(3, 0))

    # Row 1, Col 0: MD → DOCX
    reverse_container = tk.Frame(mode_frame, bg=c["bg"])
    reverse_container.grid(row=1, column=0, sticky="nsew", padx=(0, 5))

    reverse_btn = tk.Button(
        reverse_container,
        text="📝 MD → DOCX",
        font=("Segoe UI", 10, "bold"),
        bg=c["secondary_bg"],
        fg=c["fg"],
        activebackground=c["border"],
        activeforeground=c["fg"],
        relief=tk.FLAT,
        cursor="hand2",
        command=on_md_to_docx,
        pady=8,
    )
    reverse_btn.pack(fill=tk.X)

    tk.Label(
        reverse_container,
        text="Markdown → Word",
        bg=c["bg"],
        fg=c.get("fg_secondary", c["fg"]),
        font=("Segoe UI", 8),
    ).pack(pady=(3, 0))

    # Row 1, Col 1: Diff View
    diff_container = tk.Frame(mode_frame, bg=c["bg"])
    diff_container.grid(row=1, column=1, sticky="nsew", padx=(5, 0))

    diff_btn = tk.Button(
        diff_container,
        text="🔍 DIFF VIEW",
        font=("Segoe UI", 10, "bold"),
        bg=c["secondary_bg"],
        fg=c["fg"],
        activebackground=c["border"],
        activeforeground=c["fg"],
        relief=tk.FLAT,
        cursor="hand2",
        command=on_diff,
        pady=8,
    )
    diff_btn.pack(fill=tk.X)

    tk.Label(
        diff_container,
        text="Compare files",
        bg=c["bg"],
        fg=c.get("fg_secondary", c["fg"]),
        font=("Segoe UI", 8),
    ).pack(pady=(3, 0))

    return clipboard_btn, watch_btn, reverse_btn, diff_btn

