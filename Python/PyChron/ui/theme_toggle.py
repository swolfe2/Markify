"""Theme toggle widget component."""

import customtkinter as ctk


def create_theme_toggle(parent, current_theme, toggle_callback):
    """Create a simple, clear theme toggle switch.

    Args:
        parent: Parent frame to place the switch in
        current_theme: Current theme ("Light" or "Dark")
        toggle_callback: Function to call when switch is toggled

    Returns:
        tuple: (switch_frame, switch_var, None) for compatibility
    """
    # Main container
    switch_frame = ctk.CTkFrame(parent, fg_color="transparent")

    # Simple label
    theme_label = ctk.CTkLabel(switch_frame, text="Theme:", font=ctk.CTkFont(size=11))
    theme_label.pack(side="left", padx=(0, 5), pady=2)

    # Use standard CTkSwitch - clean and simple
    switch_var = ctk.StringVar(value="on" if current_theme == "Light" else "off")

    switch = ctk.CTkSwitch(
        switch_frame,
        text="",
        command=toggle_callback,
        variable=switch_var,
        onvalue="on",
        offvalue="off",
        width=50,
        height=24,
    )
    switch.pack(side="left", padx=0, pady=2)

    # Status label showing current theme
    status_text = "Light" if current_theme == "Light" else "Dark"
    status_label = ctk.CTkLabel(
        switch_frame,
        text=status_text,
        font=ctk.CTkFont(size=11, weight="bold"),
    )
    # Closer to toggle, more right padding
    status_label.pack(side="left", padx=(2, 8), pady=2)

    return switch_frame, switch_var, status_label
