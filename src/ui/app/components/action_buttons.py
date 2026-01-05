"""
Action buttons component for the main window.
Includes Convert, Options, and Help buttons.
"""
from __future__ import annotations

import tkinter as tk


def create_action_buttons(
    parent: tk.Widget,
    colors: dict[str, str],
    on_select_file: callable,
    on_toggle_options: callable,
    on_open_help: callable,
) -> tuple[tk.Button, tk.Button, tk.Button]:
    """
    Create the action buttons row (Convert, Options, Help).

    Args:
        parent: Parent widget to attach to.
        colors: Theme color dictionary.
        on_select_file: Callback for Convert button.
        on_toggle_options: Callback for Options button.
        on_open_help: Callback for Help button.

    Returns:
        Tuple of (convert_btn, options_btn, help_btn).
    """
    c = colors

    # Action Row: Main Button (left) + Options/Help (right)
    action_row = tk.Frame(parent, bg=c["bg"])
    action_row.pack(fill=tk.X, pady=(0, 10))
    action_row.columnconfigure(0, weight=1)  # Main button expands
    action_row.columnconfigure(1, weight=0)  # Buttons fixed width
    action_row.rowconfigure(0, weight=1)

    # Main Convert Button (left, takes most space)
    convert_btn = tk.Button(
        action_row,
        text="📂  SELECT FILE TO CONVERT",
        font=("Segoe UI", 12, "bold"),
        bg=c["accent"],
        fg=c.get("accent_fg", "#ffffff"),
        activebackground=c["accent_hover"],
        activeforeground=c.get("accent_fg", "#ffffff"),
        relief=tk.FLAT,
        cursor="hand2",
        command=on_select_file,
        pady=10,
    )
    convert_btn.grid(row=0, column=0, sticky="nsew", padx=(0, 10))

    # Buttons Frame (right side, stacked vertically using grid for equal sizing)
    btn_frame = tk.Frame(action_row, bg=c["bg"])
    btn_frame.grid(row=0, column=1, sticky="nsew")
    btn_frame.rowconfigure(0, weight=1)
    btn_frame.rowconfigure(1, weight=1)
    btn_frame.columnconfigure(0, weight=1)

    options_btn = tk.Button(
        btn_frame,
        text="⚙️ Options",
        font=("Segoe UI", 9),
        bg=c["secondary_bg"],
        fg=c["fg"],
        activebackground=c["border"],
        activeforeground=c["fg"],
        relief=tk.FLAT,
        cursor="hand2",
        command=on_toggle_options,
        width=10,
    )
    options_btn.grid(row=0, column=0, sticky="nsew", pady=(0, 5))

    help_btn = tk.Button(
        btn_frame,
        text="❓ Help",
        font=("Segoe UI", 9),
        bg=c["secondary_bg"],
        fg=c["fg"],
        activebackground=c["border"],
        activeforeground=c["fg"],
        relief=tk.FLAT,
        cursor="hand2",
        command=on_open_help,
        width=10,
    )
    help_btn.grid(row=1, column=0, sticky="nsew", pady=(5, 0))

    return convert_btn, options_btn, help_btn

