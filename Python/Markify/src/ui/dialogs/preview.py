"""
Preview dialog for Markify.
Shows converted markdown content before saving, with Save/Cancel options.
"""
from __future__ import annotations

import os
import tkinter as tk
from tkinter import ttk
from typing import Callable, Dict, Optional


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
        colors: Dict[str, str],
        source_path: str,
        output_path: str,
        content: str,
        on_save: Optional[Callable[[], None]] = None,
        on_open_options: Optional[Callable[[], None]] = None
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
        
        tk.Label(header, text="Preview Conversion", bg=c["bg"], fg=c["fg"],
                 font=("Segoe UI", 14, "bold")).pack(anchor=tk.W)
        
        # Source path with wrapping
        src_frame = tk.Frame(header, bg=c["bg"])
        src_frame.pack(fill=tk.X, anchor=tk.W)
        tk.Label(src_frame, text="Source: ", bg=c["bg"], fg=c["muted"], 
                 font=("Segoe UI", 9)).pack(side=tk.LEFT)
        src_path_lbl = tk.Label(src_frame, text=self.source_path, bg=c["bg"], fg=c["muted"], 
                 font=("Segoe UI", 9), wraplength=600, justify=tk.LEFT)
        src_path_lbl.pack(side=tk.LEFT, fill=tk.X)
        
        # Output path with wrapping
        out_frame = tk.Frame(header, bg=c["bg"])
        out_frame.pack(fill=tk.X, anchor=tk.W)
        tk.Label(out_frame, text="Output: ", bg=c["bg"], fg=c["muted"], 
                 font=("Segoe UI", 9)).pack(side=tk.LEFT)
        out_path_lbl = tk.Label(out_frame, text=self.output_path, bg=c["bg"], fg=c["muted"], 
                 font=("Segoe UI", 9), wraplength=600, justify=tk.LEFT)
        out_path_lbl.pack(side=tk.LEFT, fill=tk.X)
        
        # Hint about disabling preview with clickable Options link
        hint_frame = tk.Frame(header, bg=c["bg"])
        hint_frame.pack(anchor=tk.W, pady=(5, 0))
        tk.Label(hint_frame, text="(Preview can be disabled in", bg=c["bg"], fg=c["muted"], 
                 font=("Segoe UI", 8, "italic")).pack(side=tk.LEFT)
        options_link = tk.Label(hint_frame, text="Options", bg=c["bg"], fg=c["accent"], 
                 font=("Segoe UI", 8, "italic underline"), cursor="hand2")
        options_link.pack(side=tk.LEFT, padx=(4, 0))
        options_link.bind("<Button-1>", self._on_open_options)
        tk.Label(hint_frame, text=")", bg=c["bg"], fg=c["muted"], 
                 font=("Segoe UI", 8, "italic")).pack(side=tk.LEFT)
        
        # Separator
        ttk.Separator(main, orient='horizontal').pack(fill='x', pady=10)
        
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
            state=tk.NORMAL
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
            pady=8
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
            pady=8
        )
        save_btn.pack(side=tk.RIGHT)
        
        # Line count info
        line_count = len(self.content.split('\n'))
        char_count = len(self.content)
        info_text = f"{line_count} lines, {char_count:,} characters"
        tk.Label(btn_row, text=info_text, bg=c["bg"], fg=c["muted"],
                 font=("Segoe UI", 8)).pack(side=tk.LEFT, padx=20)
    
    def _apply_highlighting(self):
        """Apply basic syntax highlighting for code blocks."""
        c = self.colors
        
        # Configure tags
        self.text.tag_configure("code_block", background=c.get("border", "#3c3c3c"))
        self.text.tag_configure("header", foreground=c["accent"], font=("Consolas", 10, "bold"))
        
        # Find and highlight code blocks (```...```)
        content = self.content
        self.text.configure(state=tk.NORMAL)
        
        # Highlight headers (lines starting with #)
        lines = content.split('\n')
        current_pos = "1.0"
        for i, line in enumerate(lines, 1):
            if line.strip().startswith('#'):
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
            self.dialog.destroy()
            self.result = False
            self.on_open_options()


def show_preview_dialog(
    parent: tk.Tk,
    colors: Dict[str, str],
    source_path: str,
    output_path: str,
    content: str,
    on_open_options: Optional[Callable[[], None]] = None
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
    
    Returns:
        True if user clicked Save, False if cancelled.
    """
    dialog = PreviewDialog(parent, colors, source_path, output_path, content, on_open_options=on_open_options)
    return dialog.result

