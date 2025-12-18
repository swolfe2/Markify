"""
Options dialog for Markify.
Handles conversion settings, output folder, and appearance options.
"""
from __future__ import annotations

import os
import subprocess
import tkinter as tk
from tkinter import ttk, messagebox
from typing import Any, Callable, Dict

# Import config for pattern management
from config import ensure_config_exists, reset_to_defaults


class OptionsDialog:
    """
    Options dialog window.
    
    Args:
        parent: Parent Tk window.
        colors: Theme color dictionary.
        config: Dictionary containing:
            - format_dax_var: BooleanVar for DAX formatting
            - format_pq_var: BooleanVar for Power Query formatting
            - extract_images_var: BooleanVar for image extraction
            - output_mode_var: StringVar for output mode ("same" or "custom")
            - custom_path_var: StringVar for custom output path
            - theme_var: StringVar for theme selection
            - theme_names: List of available theme names
            - on_browse: Callback for browse button
            - on_mode_change: Callback for output mode change
    """
    
    def __init__(self, parent: tk.Tk, colors: Dict[str, str], config: Dict[str, Any], icon_path: str = None):
        self.parent = parent
        self.colors = colors
        self.config = config
        
        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Options")
        self.dialog.configure(bg=colors["bg"])
        self.dialog.resizable(False, False)
        
        # Set icon if provided
        if icon_path:
            try:
                self.dialog.iconbitmap(icon_path)
            except Exception:
                pass
        
        # Size and position (centered on parent)
        w, h = 450, 610
        parent.update_idletasks()
        screen_w = parent.winfo_screenwidth()
        screen_h = parent.winfo_screenheight()
        px = parent.winfo_x()
        py = parent.winfo_y()
        pw = parent.winfo_width()
        ph = parent.winfo_height()
        x = px + (pw // 2) - (w // 2)
        y = py + (ph // 2) - (h // 2)
        x = max(0, min(x, screen_w - w))
        y = max(0, min(y, screen_h - h - 40))
        self.dialog.geometry(f"{w}x{h}+{x}+{y}")
        
        self._build_ui()
    
    def _build_ui(self):
        """Build the dialog UI."""
        c = self.colors
        cfg = self.config
        
        # Main frame with padding
        main = tk.Frame(self.dialog, bg=c["bg"], padx=25, pady=20)
        main.pack(fill=tk.BOTH, expand=True)
        
        # Title
        tk.Label(main, text="Options", bg=c["bg"], fg=c["fg"],
                 font=("Segoe UI", 14, "bold")).pack(anchor=tk.W, pady=(0, 15))
        
        # --- Conversion Options ---
        tk.Label(main, text="Conversion", bg=c["bg"], fg=c["fg"],
                 font=("Segoe UI", 9, "bold")).pack(anchor=tk.W, pady=(0, 5))
        
        tk.Checkbutton(
            main, text="Format DAX Code (via daxformatter.com)",
            variable=cfg["format_dax_var"],
            bg=c["bg"], fg=c["fg"], selectcolor=c["bg"],
            activebackground=c["bg"], activeforeground=c["fg"],
            font=("Segoe UI", 10), relief=tk.FLAT
        ).pack(anchor=tk.W)
        
        tk.Checkbutton(
            main, text="Format Power Query Code (via powerqueryformatter.com)",
            variable=cfg["format_pq_var"],
            bg=c["bg"], fg=c["fg"], selectcolor=c["bg"],
            activebackground=c["bg"], activeforeground=c["fg"],
            font=("Segoe UI", 10), relief=tk.FLAT
        ).pack(anchor=tk.W)
        
        tk.Checkbutton(
            main, text="Extract Images (save to folder)",
            variable=cfg["extract_images_var"],
            bg=c["bg"], fg=c["fg"], selectcolor=c["bg"],
            activebackground=c["bg"], activeforeground=c["fg"],
            font=("Segoe UI", 10), relief=tk.FLAT
        ).pack(anchor=tk.W)
        
        tk.Checkbutton(
            main, text="Show preview before saving",
            variable=cfg["show_preview_var"],
            bg=c["bg"], fg=c["fg"], selectcolor=c["bg"],
            activebackground=c["bg"], activeforeground=c["fg"],
            font=("Segoe UI", 10), relief=tk.FLAT
        ).pack(anchor=tk.W)
        
        # Front matter checkbox (only show if variable is provided)
        if "add_front_matter_var" in cfg:
            tk.Checkbutton(
                main, text="Add YAML front matter (for Hugo/Jekyll)",
                variable=cfg["add_front_matter_var"],
                bg=c["bg"], fg=c["fg"], selectcolor=c["bg"],
                activebackground=c["bg"], activeforeground=c["fg"],
                font=("Segoe UI", 10), relief=tk.FLAT
            ).pack(anchor=tk.W)
        
        # TOC generation checkbox (only show if variable is provided)
        if "add_toc_var" in cfg:
            tk.Checkbutton(
                main, text="Generate Table of Contents",
                variable=cfg["add_toc_var"],
                bg=c["bg"], fg=c["fg"], selectcolor=c["bg"],
                activebackground=c["bg"], activeforeground=c["fg"],
                font=("Segoe UI", 10), relief=tk.FLAT
            ).pack(anchor=tk.W)
        
        # Separator
        ttk.Separator(main, orient='horizontal').pack(fill='x', pady=15)
        
        # --- Output Folder ---
        tk.Label(main, text="Output Folder", bg=c["bg"], fg=c["fg"],
                 font=("Segoe UI", 9, "bold")).pack(anchor=tk.W, pady=(0, 5))
        
        tk.Radiobutton(
            main, text="Same as input document", variable=cfg["output_mode_var"], value="same",
            bg=c["bg"], fg=c["fg"], selectcolor=c["bg"],
            activebackground=c["bg"], activeforeground=c["fg"],
            font=("Segoe UI", 10), relief=tk.FLAT
        ).pack(anchor=tk.W)
        
        custom_row = tk.Frame(main, bg=c["bg"])
        custom_row.pack(fill=tk.X, pady=(5, 0))
        
        tk.Radiobutton(
            custom_row, text="Custom:", variable=cfg["output_mode_var"], value="custom",
            bg=c["bg"], fg=c["fg"], selectcolor=c["bg"],
            activebackground=c["bg"], activeforeground=c["fg"],
            font=("Segoe UI", 10), relief=tk.FLAT
        ).pack(anchor=tk.W)
        
        self.entry_custom = tk.Entry(
            custom_row, textvariable=cfg["custom_path_var"],
            bg=c["secondary_bg"], fg=c["fg"], insertbackground=c["fg"],
            relief=tk.FLAT
        )
        self.entry_custom.pack(fill=tk.X, padx=(20, 0), pady=(2, 0))
        
        self.btn_browse_out = tk.Button(
            custom_row, text="Browse...", command=cfg.get("on_browse"),
            bg=c["border"], fg=c["fg"], relief=tk.FLAT
        )
        self.btn_browse_out.pack(anchor=tk.W, padx=(20, 0), pady=(5, 0))
        
        # Add trace to update state when mode changes
        cfg["output_mode_var"].trace_add("write", lambda *_: self._update_custom_ui_state())
        
        # Update state based on current mode
        self._update_custom_ui_state()
        
        # Separator
        ttk.Separator(main, orient='horizontal').pack(fill='x', pady=15)
        
        # --- Appearance ---
        tk.Label(main, text="Appearance", bg=c["bg"], fg=c["fg"],
                 font=("Segoe UI", 9, "bold")).pack(anchor=tk.W, pady=(0, 5))
        
        theme_row = tk.Frame(main, bg=c["bg"])
        theme_row.pack(fill=tk.X)
        
        tk.Label(theme_row, text="Theme:", bg=c["bg"], fg=c["fg"],
                 font=("Segoe UI", 10)).pack(side=tk.LEFT)
        
        theme_combo = ttk.Combobox(
            theme_row, textvariable=cfg["theme_var"],
            values=cfg.get("theme_names", []), state="readonly", width=18
        )
        theme_combo.pack(side=tk.LEFT, padx=(10, 0))
        
        # Separator
        ttk.Separator(main, orient='horizontal').pack(fill='x', pady=15)
        
        # --- Detection Patterns (Advanced) ---
        tk.Label(main, text="Detection Patterns", bg=c["bg"], fg=c["fg"],
                 font=("Segoe UI", 9, "bold")).pack(anchor=tk.W, pady=(0, 5))
        
        patterns_row = tk.Frame(main, bg=c["bg"])
        patterns_row.pack(fill=tk.X)
        
        tk.Button(
            patterns_row, text="Edit Patterns...", command=self._open_patterns_file,
            bg=c["border"], fg=c["fg"], font=("Segoe UI", 9),
            relief=tk.FLAT, cursor="hand2", padx=10, pady=3
        ).pack(side=tk.LEFT)
        
        tk.Button(
            patterns_row, text="Reset to Defaults", command=self._reset_patterns,
            bg=c["border"], fg=c["fg"], font=("Segoe UI", 9),
            relief=tk.FLAT, cursor="hand2", padx=10, pady=3
        ).pack(side=tk.LEFT, padx=(10, 0))
        
        tk.Label(main, text="Customize code detection (DAX, Python, Power Query keywords)",
                 bg=c["bg"], fg=c["fg_secondary"], font=("Segoe UI", 8)).pack(anchor=tk.W, pady=(3, 0))
        
        # Close button
        tk.Button(
            main, text="Close", command=self.dialog.destroy,
            bg=c["accent"], fg="#ffffff", font=("Segoe UI", 10, "bold"),
            relief=tk.FLAT, cursor="hand2", pady=8, width=15
        ).pack(pady=(20, 0))
    
    def _update_custom_ui_state(self):
        """Enable/disable custom path widgets based on mode."""
        mode = self.config["output_mode_var"].get()
        state = 'normal' if mode == 'custom' else 'disabled'
        self.entry_custom.configure(state=state)
        self.btn_browse_out.configure(state=state)
    
    def winfo_exists(self) -> bool:
        """Check if dialog window still exists."""
        try:
            return self.dialog.winfo_exists()
        except tk.TclError:
            return False
    
    def lift(self):
        """Bring dialog to front."""
        self.dialog.lift()
    
    def focus_force(self):
        """Force focus to dialog."""
        self.dialog.focus_force()
    
    def configure(self, **kwargs):
        """Configure dialog window."""
        self.dialog.configure(**kwargs)
    
    def _open_patterns_file(self):
        """Open the detection patterns config file in default editor."""
        try:
            config_path = ensure_config_exists()
            # Open with default JSON/text editor
            os.startfile(config_path)  # nosec B606
        except Exception as e:
            messagebox.showerror(
                "Error",
                f"Could not open patterns file:\n{e}",
                parent=self.dialog
            )
    
    def _reset_patterns(self):
        """Reset detection patterns to defaults."""
        if messagebox.askyesno(
            "Reset Patterns",
            "Reset all detection patterns to defaults?\n\nThis will overwrite any customizations.",
            parent=self.dialog
        ):
            try:
                reset_to_defaults()
                messagebox.showinfo(
                    "Patterns Reset",
                    "Detection patterns have been reset to defaults.",
                    parent=self.dialog
                )
            except Exception as e:
                messagebox.showerror(
                    "Error",
                    f"Could not reset patterns:\n{e}",
                    parent=self.dialog
                )
