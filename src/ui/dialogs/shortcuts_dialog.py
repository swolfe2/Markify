"""
Keyboard Shortcuts dialog for Markify.
Shows all available keyboard shortcuts in a categorized table.
"""
from __future__ import annotations

import tkinter as tk
from tkinter import ttk

# Define all keyboard shortcuts
SHORTCUTS = {
    "File": [
        ("Ctrl+O", "Open file(s) for conversion"),
        ("Ctrl+S", "Save current conversion"),
        ("Ctrl+Shift+S", "Save As..."),
        ("Ctrl+W", "Close current file"),
        ("Ctrl+Q", "Quit application"),
    ],
    "Edit": [
        ("Ctrl+C", "Copy selected text"),
        ("Ctrl+V", "Paste from clipboard"),
        ("Ctrl+A", "Select all text"),
        ("Ctrl+Z", "Undo (in editable fields)"),
    ],
    "View": [
        ("Ctrl+Shift+V", "Toggle Raw/Formatted view"),
        ("Ctrl+B", "Preview in browser"),
        ("F11", "Toggle fullscreen"),
    ],
    "Convert": [
        ("Ctrl+M", "Convert to Markdown"),
        ("Ctrl+Shift+M", "Convert to DOCX (reverse)"),
        ("Ctrl+Shift+C", "Open Clipboard Mode"),
        ("Ctrl+Shift+W", "Open Watch Mode"),
        ("Ctrl+Shift+D", "Open Diff View"),
    ],
    "Navigation": [
        ("Ctrl+Tab", "Switch between panels"),
        ("Escape", "Close dialog/Cancel"),
        ("F1", "Open Help"),
    ],
}


class ShortcutsDialog:
    """
    Dialog showing all available keyboard shortcuts.
    """

    def __init__(self, parent: tk.Tk, colors: dict[str, str], icon_path: str = None):
        self.parent = parent
        self.colors = colors

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Keyboard Shortcuts")
        self.dialog.configure(bg=colors["bg"])
        self.dialog.resizable(True, True)

        # Set icon if provided
        if icon_path:
            try:
                self.dialog.iconbitmap(icon_path)
            except Exception:  # nosec B110 - Safe: icon loading is optional, gracefully degrade
                pass

        # Size and position
        w, h = 500, 450
        parent.update_idletasks()
        px = parent.winfo_x()
        py = parent.winfo_y()
        pw = parent.winfo_width()
        ph = parent.winfo_height()
        x = px + (pw // 2) - (w // 2)
        y = py + (ph // 2) - (h // 2)
        self.dialog.geometry(f"{w}x{h}+{x}+{y}")

        # Make modal
        self.dialog.transient(parent)
        self.dialog.grab_set()

        self._build_ui()

        # Bind Escape to close
        self.dialog.bind("<Escape>", lambda e: self.dialog.destroy())

    def _build_ui(self):
        """Build the dialog UI."""
        c = self.colors

        # Main frame with padding
        main = tk.Frame(self.dialog, bg=c["bg"], padx=20, pady=15)
        main.pack(fill=tk.BOTH, expand=True)

        # Header
        tk.Label(main, text="⌨️ Keyboard Shortcuts", bg=c["bg"], fg=c["fg"],
                 font=("Segoe UI", 14, "bold")).pack(anchor=tk.W, pady=(0, 10))

        # Scrollable frame
        canvas = tk.Canvas(main, bg=c["bg"], highlightthickness=0)
        scrollbar = ttk.Scrollbar(main, orient="vertical", command=canvas.yview)
        scrollable_frame = tk.Frame(canvas, bg=c["bg"])

        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )

        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)

        # Build shortcuts by category
        for category, shortcuts in SHORTCUTS.items():
            # Category header
            cat_frame = tk.Frame(scrollable_frame, bg=c["bg"])
            cat_frame.pack(fill=tk.X, pady=(10, 5))

            tk.Label(cat_frame, text=category, bg=c["bg"], fg=c["accent"],
                     font=("Segoe UI", 11, "bold")).pack(anchor=tk.W)

            # Shortcuts table
            for shortcut, description in shortcuts:
                row = tk.Frame(scrollable_frame, bg=c["bg"])
                row.pack(fill=tk.X, pady=2)

                # Shortcut key (fixed width)
                key_label = tk.Label(row, text=shortcut, bg=c["secondary_bg"],
                                     fg=c["fg"], font=("Consolas", 10),
                                     width=16, anchor=tk.W, padx=8, pady=2)
                key_label.pack(side=tk.LEFT)

                # Description
                desc_label = tk.Label(row, text=description, bg=c["bg"],
                                      fg=c["muted"], font=("Segoe UI", 10),
                                      anchor=tk.W, padx=10)
                desc_label.pack(side=tk.LEFT, fill=tk.X)

        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Enable mouse wheel scrolling
        def _on_mousewheel(event):
            canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")
        canvas.bind_all("<MouseWheel>", _on_mousewheel)

        # Close button
        close_btn = tk.Button(
            main, text="Close", font=("Segoe UI", 10),
            bg=c["secondary_bg"], fg=c["fg"],
            activebackground=c["border"], activeforeground=c["fg"],
            relief=tk.FLAT, cursor="hand2",
            command=self.dialog.destroy,
            width=12, pady=6
        )
        close_btn.pack(pady=(15, 0))

        # Unbind mousewheel when dialog closes
        def on_close():
            canvas.unbind_all("<MouseWheel>")
            self.dialog.destroy()

        self.dialog.protocol("WM_DELETE_WINDOW", on_close)


def show_shortcuts_dialog(parent: tk.Tk, colors: dict[str, str], icon_path: str = None):
    """Show the keyboard shortcuts dialog."""
    ShortcutsDialog(parent, colors, icon_path=icon_path)
