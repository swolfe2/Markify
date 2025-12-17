"""
UI styling utilities for Markify.
Handles ttk style configuration and widget tree color updates.
"""
from __future__ import annotations

import tkinter as tk
from tkinter import ttk
from typing import Dict


def configure_styles(colors: Dict[str, str]) -> None:
    """
    Configure ttk styles for the application.
    
    Args:
        colors: Theme color dictionary.
    """
    style = ttk.Style()
    try:
        style.theme_use('clam')
    except Exception:  # nosec B110
        pass  # Fallback if clam theme missing
    
    c = colors  # Shorthand
    
    # Frame Styles
    style.configure("TFrame", background=c["bg"])
    style.configure("Card.TFrame", background=c["bg"], relief=tk.RAISED, borderwidth=0)
    # Label Styles
    style.configure("TLabel", background=c["bg"], foreground=c["fg"], font=("Segoe UI", 10))
    style.configure("Title.TLabel", font=("Segoe UI", 24, "bold"), foreground=c["fg"])
    style.configure("Sub.TLabel", font=("Segoe UI", 10), foreground=c["muted"])
    style.configure("Body.TLabel", font=("Segoe UI", 11), foreground=c["fg"])
    # Dialog Styles
    style.configure("Success.TLabel", background=c["bg"], foreground=c["success"], font=("Segoe UI", 14, "bold"))
    style.configure("Path.TLabel", background=c["bg"], foreground=c["muted"], font=("Consolas", 10))


def update_widget_tree(parent: tk.Widget, old: Dict[str, str], new: Dict[str, str]) -> None:
    """
    Recursively update widget colors by matching against old theme.
    
    Args:
        parent: Parent widget to update.
        old: Old theme color dictionary.
        new: New theme color dictionary.
    """
    for widget in parent.winfo_children():
        try:
            # Update Background
            current_bg = widget.cget("bg")
            if current_bg == old["bg"]:
                widget.configure(bg=new["bg"])
            elif current_bg == old["secondary_bg"]:
                widget.configure(bg=new["secondary_bg"])
            elif current_bg == old["accent"]:
                widget.configure(bg=new["accent"])
            elif current_bg == old["border"]:
                widget.configure(bg=new["border"])
            
            # Update Foreground
            current_fg = widget.cget("fg")
            if current_fg == old["fg"]:
                widget.configure(fg=new["fg"])
            elif current_fg == old["muted"]:
                widget.configure(fg=new["muted"])
            elif current_fg == old["accent"]:
                widget.configure(fg=new["accent"])
            elif current_fg == old["error"]:
                widget.configure(fg=new["error"])
            elif current_fg == old["success"]:
                widget.configure(fg=new["success"])
            
            # Update Active Colors (for Buttons/Checkbuttons)
            if "activebackground" in widget.keys():
                current_abg = widget.cget("activebackground")
                if current_abg == old["bg"]:
                    widget.configure(activebackground=new["bg"])
                elif current_abg == old["accent"]:
                    widget.configure(activebackground=new["accent"])
                elif current_abg == old["accent_hover"]:
                    widget.configure(activebackground=new["accent_hover"])
                    
            if "activeforeground" in widget.keys():
                current_afg = widget.cget("activeforeground")
                if current_afg == old["fg"]:
                    widget.configure(activeforeground=new["fg"])
                    
            # Update Select Colors (Checkbuttons/Radiobuttons)
            if "selectcolor" in widget.keys():
                current_sc = widget.cget("selectcolor")
                if current_sc == old["bg"]:
                    widget.configure(selectcolor=new["bg"])
                    
            # Update Entry Insert Cursor
            if "insertbackground" in widget.keys():
                current_ib = widget.cget("insertbackground")
                if current_ib == old["fg"]:
                    widget.configure(insertbackground=new["fg"])
                elif current_ib == old["bg"]:
                    widget.configure(insertbackground=new["bg"]) 

        except Exception:  # nosec B110
            # Some widgets might not have bg/fg attributes or throw errors
            pass
        
        # Recurse
        if widget.winfo_children():
            update_widget_tree(widget, old, new)


def get_button_style(colors: Dict[str, str], variant: str = "primary") -> Dict:
    """
    Get button style kwargs for consistent styling.
    
    Args:
        colors: Theme color dictionary.
        variant: "primary", "secondary", or "danger".
    
    Returns:
        Dictionary of button style kwargs.
    """
    c = colors
    
    if variant == "primary":
        bg = c["accent"]
        fg = c.get("accent_fg", "#ffffff")
    elif variant == "secondary":
        bg = c["secondary_bg"]
        fg = c["fg"]
    elif variant == "danger":
        bg = c["error"]
        fg = "#ffffff"
    else:
        bg = c["accent"]
        fg = "#ffffff"
    
    return {
        "font": ("Segoe UI", 10),
        "bg": bg,
        "fg": fg,
        "activebackground": c["border"],
        "activeforeground": fg,
        "relief": tk.FLAT,
        "cursor": "hand2",
        "pady": 8
    }
