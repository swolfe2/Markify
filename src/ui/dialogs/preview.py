"""
Preview dialog for Markify.
Shows converted markdown content before saving, with Save/Cancel options.
"""

from __future__ import annotations

import os
import tkinter as tk
from collections.abc import Callable
from tkinter import ttk


class PreviewDialog:
    """
    Preview dialog showing converted markdown before saving.

    Args:
        parent: Parent Tk window.
        colors: Theme color dictionary.
        source_path: Path to source .docx file.
        output_path: Path where .md will be saved.
        content: Markdown content to preview.
        on_save: Callback when Save is clicked.

    Returns:
        True if user clicked Save, False if cancelled.
    """

    def __init__(
        self,
        parent: tk.Tk,
        colors: dict[str, str],
        source_path: str,
        output_path: str,
        content: str,
        on_save: Callable[[], None] | None = None,
        on_open_options: Callable[[], None] | None = None,
        icon_path: str = None,
    ):
        self.parent = parent
        self.colors = colors
        # Normalize path separators to backslashes on Windows
        self.source_path = os.path.normpath(source_path)
        self.output_path = os.path.normpath(output_path)
        self.content = content
        self.on_save = on_save
        self.on_open_options = on_open_options
        self.result = False

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Preview Conversion")
        self.dialog.configure(bg=colors["bg"])
        self.dialog.resizable(True, True)

        # Set icon if provided
        if icon_path:
            try:
                self.dialog.iconbitmap(icon_path)
            except (
                Exception
            ):  # nosec B110 - Safe: icon loading is optional, gracefully degrade
                pass

        # Size and position (centered on parent) - increased height for wrapped paths
        w, h = 700, 620
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

        # Make modal
        self.dialog.transient(parent)
        self.dialog.grab_set()

        self._build_ui()

        # Wait for dialog to close
        parent.wait_window(self.dialog)

    def _build_ui(self):
        """Build the dialog UI."""
        c = self.colors

        # Main frame with padding
        main = tk.Frame(self.dialog, bg=c["bg"], padx=20, pady=15)
        main.pack(fill=tk.BOTH, expand=True)

        # Header with file info
        header = tk.Frame(main, bg=c["bg"])
        header.pack(fill=tk.X, pady=(0, 10))

        tk.Label(
            header,
            text="Preview Conversion",
            bg=c["bg"],
            fg=c["fg"],
            font=("Segoe UI", 14, "bold"),
        ).pack(anchor=tk.W)

        # Source path with wrapping
        src_frame = tk.Frame(header, bg=c["bg"])
        src_frame.pack(fill=tk.X, anchor=tk.W)
        tk.Label(
            src_frame, text="Source: ", bg=c["bg"], fg=c["muted"], font=("Segoe UI", 9)
        ).pack(side=tk.LEFT)
        src_path_lbl = tk.Label(
            src_frame,
            text=self.source_path,
            bg=c["bg"],
            fg=c["muted"],
            font=("Segoe UI", 9),
            wraplength=600,
            justify=tk.LEFT,
        )
        src_path_lbl.pack(side=tk.LEFT, fill=tk.X)

        # Output path with wrapping
        out_frame = tk.Frame(header, bg=c["bg"])
        out_frame.pack(fill=tk.X, anchor=tk.W)
        tk.Label(
            out_frame, text="Output: ", bg=c["bg"], fg=c["muted"], font=("Segoe UI", 9)
        ).pack(side=tk.LEFT)
        out_path_lbl = tk.Label(
            out_frame,
            text=self.output_path,
            bg=c["bg"],
            fg=c["muted"],
            font=("Segoe UI", 9),
            wraplength=600,
            justify=tk.LEFT,
        )
        out_path_lbl.pack(side=tk.LEFT, fill=tk.X)

        # Hint about disabling preview with clickable Options link
        # Use a single Text widget to avoid spacing issues between multiple labels
        hint_frame = tk.Frame(header, bg=c["bg"])
        hint_frame.pack(anchor=tk.W, pady=(5, 0))

        hint_text = tk.Text(
            hint_frame,
            bg=c["bg"],
            height=1,
            wrap=tk.NONE,
            relief=tk.FLAT,
            borderwidth=0,
            highlightthickness=0,
            padx=0,
            pady=0,
            cursor="arrow",
            insertwidth=0,
        )
        hint_text.pack(side=tk.LEFT)

        # Insert text with different styling for "Options"
        hint_text.insert("1.0", "(Preview can be disabled in ", "muted")
        hint_text.insert(tk.END, "Options", "link")
        hint_text.insert(tk.END, ")", "muted")

        # Configure tags
        hint_text.tag_configure(
            "muted", foreground=c["muted"], font=("Segoe UI", 8, "italic")
        )
        hint_text.tag_configure(
            "link", foreground=c["accent"], font=("Segoe UI", 8, "italic underline")
        )

        # Make Options clickable
        def on_hint_click(event):
            index = hint_text.index(f"@{event.x},{event.y}")
            if "link" in hint_text.tag_names(index):
                if self._on_open_options:
                    self._on_open_options(None)
            return "break"

        def on_hint_motion(event):
            index = hint_text.index(f"@{event.x},{event.y}")
            if "link" in hint_text.tag_names(index):
                hint_text.config(cursor="hand2")
            else:
                hint_text.config(cursor="arrow")

        hint_text.bind("<Button-1>", on_hint_click)
        hint_text.bind("<Motion>", on_hint_motion)
        hint_text.config(state=tk.DISABLED)

        # Separator
        ttk.Separator(main, orient="horizontal").pack(fill="x", pady=10)

        # Content area with scrollbar
        content_frame = tk.Frame(main, bg=c["bg"])
        content_frame.pack(fill=tk.BOTH, expand=True)

        # Scrollbar
        scrollbar = tk.Scrollbar(content_frame)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Text widget for markdown preview
        self.text = tk.Text(
            content_frame,
            bg=c["secondary_bg"],
            fg=c["fg"],
            font=("Consolas", 10),
            wrap=tk.WORD,
            yscrollcommand=scrollbar.set,
            padx=10,
            pady=10,
            relief=tk.FLAT,
            state=tk.NORMAL,
        )
        self.text.pack(fill=tk.BOTH, expand=True)
        scrollbar.config(command=self.text.yview)

        # Insert content and make read-only
        self.text.insert(tk.END, self.content)
        self.text.configure(state=tk.DISABLED)

        # Apply basic syntax highlighting for code blocks
        self._apply_highlighting()

        # Button row
        btn_row = tk.Frame(main, bg=c["bg"])
        btn_row.pack(fill=tk.X, pady=(15, 0))

        # Cancel button (left)
        cancel_btn = tk.Button(
            btn_row,
            text="Cancel",
            font=("Segoe UI", 10),
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            cursor="hand2",
            command=self._on_cancel,
            width=12,
            pady=8,
        )
        cancel_btn.pack(side=tk.LEFT)

        # Save button (right, prominent)
        save_btn = tk.Button(
            btn_row,
            text="Save",
            font=("Segoe UI", 10, "bold"),
            bg=c["accent"],
            fg=c.get("accent_fg", "#ffffff"),
            activebackground=c["accent_hover"],
            activeforeground=c.get("accent_fg", "#ffffff"),
            relief=tk.FLAT,
            cursor="hand2",
            command=self._on_save,
            width=12,
            pady=8,
        )
        save_btn.pack(side=tk.RIGHT)

        # Statistics panel
        stats_frame = tk.Frame(btn_row, bg=c["bg"])
        stats_frame.pack(side=tk.LEFT, padx=20)

        # Calculate statistics
        stats = self._calculate_stats()

        # Word count and reading time
        info_text = f"{stats['words']:,} words • {stats['reading_time']} read • {stats['lines']} lines"
        tk.Label(
            stats_frame, text=info_text, bg=c["bg"], fg=c["muted"], font=("Segoe UI", 8)
        ).pack(side=tk.LEFT)

        # Header breakdown (if any headers exist)
        if stats["headers"]:
            header_info = " • Headers: " + ", ".join(
                f"H{k}:{v}" for k, v in sorted(stats["headers"].items())
            )
            tk.Label(
                stats_frame,
                text=header_info,
                bg=c["bg"],
                fg=c["muted"],
                font=("Segoe UI", 8),
            ).pack(side=tk.LEFT)

    def _calculate_stats(self) -> dict:
        """Calculate document statistics."""

        lines = self.content.split("\n")

        # Word count (simple split on whitespace, excluding code blocks)
        words = len(self.content.split())

        # Reading time at 200 words per minute
        minutes = words / 200
        if minutes < 1:
            reading_time = "<1 min"
        else:
            reading_time = f"{int(round(minutes))} min"

        # Header count by level
        headers = {}
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("#"):
                # Count leading #
                level = len(stripped) - len(stripped.lstrip("#"))
                if 1 <= level <= 6:
                    headers[level] = headers.get(level, 0) + 1

        return {
            "lines": len(lines),
            "chars": len(self.content),
            "words": words,
            "reading_time": reading_time,
            "headers": headers,
        }

    def _apply_highlighting(self):
        """Apply basic syntax highlighting for code blocks."""
        c = self.colors

        # Configure tags
        self.text.tag_configure("code_block", background=c.get("border", "#3c3c3c"))
        self.text.tag_configure(
            "header", foreground=c["accent"], font=("Consolas", 10, "bold")
        )

        # Find and highlight code blocks (```...```)
        content = self.content
        self.text.configure(state=tk.NORMAL)

        # Highlight headers (lines starting with #)
        lines = content.split("\n")
        for i, line in enumerate(lines, 1):
            if line.strip().startswith("#"):
                start = f"{i}.0"
                end = f"{i}.end"
                self.text.tag_add("header", start, end)

        self.text.configure(state=tk.DISABLED)

    def _on_save(self):
        """Handle Save button click."""
        self.result = True
        if self.on_save:
            self.on_save()
        self.dialog.destroy()

    def _on_cancel(self):
        """Handle Cancel button click."""
        self.result = False
        self.dialog.destroy()

    def _on_open_options(self, event=None):
        """Handle Options link click."""
        if self.on_open_options:
            # Temporarily release grab so Options dialog can open without closing Preview
            self.dialog.grab_release()
            self.on_open_options()
            # Re-grab after Options dialog closes
            self.dialog.grab_set()


def show_preview_dialog(
    parent: tk.Tk,
    colors: dict[str, str],
    source_path: str,
    output_path: str,
    content: str,
    on_open_options: Callable[[], None] | None = None,
    icon_path: str = None,
) -> bool:
    """
    Show preview dialog and return True if user clicked Save.

    Args:
        parent: Parent Tk window.
        colors: Theme color dictionary.
        source_path: Path to source .docx file.
        output_path: Path where .md will be saved.
        content: Markdown content to preview.
        on_open_options: Callback to open options dialog.
        icon_path: Path to application icon.

    Returns:
        True if user clicked Save, False if cancelled.
    """
    dialog = PreviewDialog(
        parent,
        colors,
        source_path,
        output_path,
        content,
        on_open_options=on_open_options,
        icon_path=icon_path,
    )
    return dialog.result
