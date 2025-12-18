"""
Clipboard Mode dialog for Markify.
Two-pane interface: paste formatted text → see Markdown output.
"""
from __future__ import annotations

import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from typing import Dict, Any, Optional
import re

from logging_config import get_logger
from core.html_to_md import html_to_markdown, clean_text_for_markdown
from core.detectors import detect_code_language

# Import Windows clipboard for HTML access
try:
    from win_clipboard import get_clipboard_html
except ImportError:
    get_clipboard_html = None

logger = get_logger("clipboard_mode")


class ClipboardModeDialog:
    """
    Clipboard conversion dialog.
    
    Left pane: Paste formatted text
    Right pane: Markdown output (auto-updates)
    """
    
    def __init__(self, parent: tk.Tk, colors: Dict[str, str], prefs: Optional[Any] = None, on_close: Optional[Any] = None, icon_path: str = None):
        self.parent = parent
        self.colors = colors
        self.prefs = prefs
        self.on_close_callback = on_close
        
        self.dialog = tk.Toplevel(parent)
        self.dialog.withdraw()  # Hide until positioned
        self.dialog.title("Clipboard Mode - Paste to Markdown")
        self.dialog.configure(bg=colors["bg"])
        
        # Set icon if provided
        if icon_path:
            try:
                self.dialog.iconbitmap(icon_path)
            except Exception:
                pass
        
        # Size and position
        w, h = 900, 600
        parent.update_idletasks()
        screen_w = parent.winfo_screenwidth()
        screen_h = parent.winfo_screenheight()
        x = (screen_w - w) // 2
        y = (screen_h - h) // 2 - 50
        self.dialog.geometry(f"{w}x{h}+{x}+{y}")
        self.dialog.minsize(700, 400)
        
        self._build_ui()
        
        # Show dialog after building UI
        self.dialog.deiconify()
        
        # Focus on input
        self.input_text.focus_set()
    
    def _build_ui(self):
        """Build the dialog UI."""
        c = self.colors
        
        # Main container
        main = tk.Frame(self.dialog, bg=c["bg"], padx=15, pady=15)
        main.pack(fill=tk.BOTH, expand=True)
        
        # Header
        header_frame = tk.Frame(main, bg=c["bg"])
        header_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(
            header_frame, text="📋 Clipboard Mode",
            bg=c["bg"], fg=c["fg"],
            font=("Segoe UI", 14, "bold")
        ).pack(side=tk.LEFT)
        
        tk.Label(
            header_frame, text="Paste formatted text on the left, see Markdown on the right",
            bg=c["bg"], fg=c.get("fg_secondary", c["fg"]),
            font=("Segoe UI", 10)
        ).pack(side=tk.LEFT, padx=(15, 0))
        
        # Two-pane container
        panes = tk.Frame(main, bg=c["bg"])
        panes.pack(fill=tk.BOTH, expand=True)
        panes.columnconfigure(0, weight=1)
        panes.columnconfigure(1, weight=0)  # Separator
        panes.columnconfigure(2, weight=1)
        panes.rowconfigure(0, weight=1)
        
        # === LEFT PANE: Input ===
        left_frame = tk.Frame(panes, bg=c["bg"])
        left_frame.grid(row=0, column=0, sticky="nsew", padx=(0, 5))
        left_frame.rowconfigure(1, weight=1)
        left_frame.columnconfigure(0, weight=1)
        
        tk.Label(
            left_frame, text="📥 Paste Here (Ctrl+V)",
            bg=c["bg"], fg=c["fg"],
            font=("Segoe UI", 10, "bold")
        ).grid(row=0, column=0, sticky="w", pady=(0, 5))
        
        self.input_text = tk.Text(
            left_frame,
            bg=c["secondary_bg"],
            fg=c["fg"],
            insertbackground=c["fg"],
            font=("Consolas", 10),
            wrap=tk.WORD,
            padx=10,
            pady=10,
            relief=tk.FLAT,
            highlightthickness=1,
            highlightbackground=c["border"],
            highlightcolor=c["accent"]
        )
        self.input_text.grid(row=1, column=0, sticky="nsew")
        
        # Add scrollbar
        input_scroll = ttk.Scrollbar(left_frame, command=self.input_text.yview)
        input_scroll.grid(row=1, column=1, sticky="ns")
        self.input_text.configure(yscrollcommand=input_scroll.set)
        
        # Bind paste and key events
        self.input_text.bind("<Control-v>", self._on_paste)
        self.input_text.bind("<KeyRelease>", self._on_input_change)
        
        # === SEPARATOR ===
        sep_frame = tk.Frame(panes, bg=c["border"], width=2)
        sep_frame.grid(row=0, column=1, sticky="ns", padx=10)
        
        # === RIGHT PANE: Output ===
        right_frame = tk.Frame(panes, bg=c["bg"])
        right_frame.grid(row=0, column=2, sticky="nsew", padx=(5, 0))
        right_frame.rowconfigure(1, weight=1)
        right_frame.columnconfigure(0, weight=1)
        
        tk.Label(
            right_frame, text="📤 Markdown Output",
            bg=c["bg"], fg=c["fg"],
            font=("Segoe UI", 10, "bold")
        ).grid(row=0, column=0, sticky="w", pady=(0, 5))
        
        self.output_text = tk.Text(
            right_frame,
            bg=c["secondary_bg"],
            fg=c["fg"],
            font=("Consolas", 10),
            wrap=tk.WORD,
            padx=10,
            pady=10,
            relief=tk.FLAT,
            highlightthickness=1,
            highlightbackground=c["border"],
            highlightcolor=c["accent"],
            state=tk.DISABLED
        )
        self.output_text.grid(row=1, column=0, sticky="nsew")
        
        # Add scrollbar
        output_scroll = ttk.Scrollbar(right_frame, command=self.output_text.yview)
        output_scroll.grid(row=1, column=1, sticky="ns")
        self.output_text.configure(yscrollcommand=output_scroll.set)
        
        # === BUTTON BAR ===
        btn_frame = tk.Frame(main, bg=c["bg"])
        btn_frame.pack(fill=tk.X, pady=(15, 0))
        
        # Copy button (primary action)
        tk.Button(
            btn_frame, text="📋 Copy Markdown",
            bg=c["accent"], fg=c.get("accent_fg", "#ffffff"),
            font=("Segoe UI", 10, "bold"),
            activebackground=c["accent_hover"],
            activeforeground=c.get("accent_fg", "#ffffff"),
            relief=tk.FLAT, cursor="hand2",
            command=self._copy_markdown,
            padx=15, pady=8
        ).pack(side=tk.LEFT)
        
        # Clear button
        tk.Button(
            btn_frame, text="🔄 Clear",
            bg=c["secondary_bg"], fg=c["fg"],
            font=("Segoe UI", 10),
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT, cursor="hand2",
            command=self._clear_all,
            padx=15, pady=8
        ).pack(side=tk.LEFT, padx=(10, 0))
        
        # Save As button
        tk.Button(
            btn_frame, text="💾 Save As...",
            bg=c["secondary_bg"], fg=c["fg"],
            font=("Segoe UI", 10),
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT, cursor="hand2",
            command=self._save_as,
            padx=15, pady=8
        ).pack(side=tk.LEFT, padx=(10, 0))
        
        # Close button (right side)
        tk.Button(
            btn_frame, text="Close",
            bg=c["secondary_bg"], fg=c["fg"],
            font=("Segoe UI", 10),
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT, cursor="hand2",
            command=self._close,
            padx=15, pady=8
        ).pack(side=tk.RIGHT)
        
        # Status label
        self.status_var = tk.StringVar(value="Paste formatted text to convert")
        tk.Label(
            btn_frame, textvariable=self.status_var,
            bg=c["bg"], fg=c.get("fg_secondary", c["fg"]),
            font=("Segoe UI", 9)
        ).pack(side=tk.RIGHT, padx=(0, 15))
    
    def _on_paste(self, event=None):
        """Handle paste event - try to get HTML from clipboard."""
        try:
            # Try Windows clipboard API for HTML (CF_HTML format)
            html_content = None
            if get_clipboard_html is not None:
                try:
                    html_content = get_clipboard_html()
                except Exception as e:
                    logger.warning(f"Windows clipboard error: {e}")
            
            if html_content:
                logger.info("Got HTML from Windows clipboard")
                # Set flag to prevent _on_input_change from overwriting
                self._html_converted = True
                # Convert HTML and show in output
                self._convert_html(html_content)
                # Reset flag after a delay (allow for typing to work normally after)
                self.dialog.after(1000, self._reset_html_flag)
                return  # Let normal paste proceed for input display
            
            # Fall back to plain text
            # Let default paste happen, then convert
            self.dialog.after(50, self._convert_plain_text)
            
        except Exception as e:
            logger.warning(f"Paste handling error: {e}")
    
    def _reset_html_flag(self):
        """Reset the HTML converted flag."""
        self._html_converted = False
    
    def _on_input_change(self, event=None):
        """Handle changes in input text."""
        # Don't overwrite HTML conversion
        if getattr(self, '_html_converted', False):
            return
        self._convert_plain_text()
    
    def _convert_html(self, html: str):
        """Convert HTML content to Markdown."""
        try:
            markdown = html_to_markdown(html)
            # Apply code block detection
            markdown = self._detect_and_wrap_code_blocks(markdown)
            self._set_output(markdown)
            lines = markdown.count('\n') + 1
            self.status_var.set(f"✓ Converted from HTML ({lines} lines)")
        except Exception as e:
            logger.error(f"HTML conversion error: {e}")
            self.status_var.set("Error converting HTML")
    
    def _detect_and_wrap_code_blocks(self, text: str) -> str:
        """
        Detect code patterns in text and wrap them in code fences.
        
        Looks for common code patterns:
        - let ... in (Power Query)
        - := with DAX functions
        - Python imports/defs
        """
        lines = text.split('\n')
        result = []
        code_buffer = []
        in_code = False
        current_lang = None
        
        def clean_code_buffer(buffer):
            """Remove all empty lines from code buffer."""
            # Strip all empty lines - Word HTML inserts a blank line after each code line
            return [line for line in buffer if line.strip()]
        
        for line in lines:
            stripped = line.strip()
            
            # Skip if already in a code block
            if stripped.startswith('```'):
                if in_code:
                    # End our detected block first
                    result.append(f'```{current_lang or ""}')
                    result.extend(clean_code_buffer(code_buffer))
                    result.append('```')
                    code_buffer = []
                    in_code = False
                    current_lang = None
                result.append(line)
                continue
            
            # Detect code language
            lang = detect_code_language(stripped) if stripped else None
            
            if lang:
                if not in_code:
                    # Start new code block
                    in_code = True
                    current_lang = lang
                code_buffer.append(line)
            else:
                if in_code:
                    # Check if this is a continuation (empty line or indented)
                    if not stripped or line.startswith(' ') or line.startswith('\t'):
                        code_buffer.append(line)
                    else:
                        # End code block
                        result.append(f'```{current_lang or ""}')
                        result.extend(clean_code_buffer(code_buffer))
                        result.append('```')
                        code_buffer = []
                        in_code = False
                        current_lang = None
                        result.append(line)
                else:
                    result.append(line)
        
        # Close any remaining code block
        if in_code and code_buffer:
            result.append(f'```{current_lang or ""}')
            result.extend(clean_code_buffer(code_buffer))
            result.append('```')
        
        return '\n'.join(result)
    
    def _convert_plain_text(self):
        """Convert plain text input to Markdown."""
        text = self.input_text.get("1.0", tk.END).strip()
        if not text:
            self._set_output("")
            self.status_var.set("Paste formatted text to convert")
            return
        
        # For plain text, just clean it up
        markdown = clean_text_for_markdown(text)
        self._set_output(markdown)
        lines = markdown.count('\n') + 1
        chars = len(markdown)
        self.status_var.set(f"{lines} lines, {chars} chars")
    
    def _set_output(self, text: str):
        """Set the output text area content."""
        self.output_text.configure(state=tk.NORMAL)
        self.output_text.delete("1.0", tk.END)
        self.output_text.insert("1.0", text)
        self.output_text.configure(state=tk.DISABLED)
    
    def _copy_markdown(self):
        """Copy Markdown output to clipboard."""
        self.output_text.configure(state=tk.NORMAL)
        content = self.output_text.get("1.0", tk.END).strip()
        self.output_text.configure(state=tk.DISABLED)
        
        if not content:
            messagebox.showwarning("Nothing to Copy", "No Markdown content to copy.", parent=self.dialog)
            return
        
        self.dialog.clipboard_clear()
        self.dialog.clipboard_append(content)
        self.status_var.set("✓ Copied to clipboard!")
        
        # Reset status after 2 seconds
        self.dialog.after(2000, lambda: self.status_var.set(f"{content.count(chr(10)) + 1} lines, {len(content)} chars"))
    
    def _clear_all(self):
        """Clear both input and output."""
        self._html_converted = False  # Reset flag
        self.input_text.delete("1.0", tk.END)
        self._set_output("")
        self.status_var.set("Paste formatted text to convert")
    
    def _save_as(self):
        """Save Markdown output to file."""
        self.output_text.configure(state=tk.NORMAL)
        content = self.output_text.get("1.0", tk.END).strip()
        self.output_text.configure(state=tk.DISABLED)
        
        if not content:
            messagebox.showwarning("Nothing to Save", "No Markdown content to save.", parent=self.dialog)
            return
        
        filepath = filedialog.asksaveasfilename(
            parent=self.dialog,
            title="Save Markdown As",
            defaultextension=".md",
            filetypes=[("Markdown files", "*.md"), ("All files", "*.*")]
        )
        
        if filepath:
            try:
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(content)
                self.status_var.set(f"✓ Saved to {filepath}")
                # Add to recent files (source is "clipboard" since there's no source file)
                if self.prefs:
                    self.prefs.add_recent_file("Clipboard", filepath)
            except Exception as e:
                messagebox.showerror("Save Error", f"Could not save file:\n{e}", parent=self.dialog)
    
    def _close(self):
        """Close the dialog and call the on_close callback."""
        if self.on_close_callback:
            self.on_close_callback()
        self.dialog.destroy()


def show_clipboard_mode(parent: tk.Tk, colors: Dict[str, str], prefs: Optional[Any] = None, on_close: Optional[Any] = None, icon_path: str = None) -> ClipboardModeDialog:
    """Show the Clipboard Mode dialog."""
    return ClipboardModeDialog(parent, colors, prefs, on_close, icon_path=icon_path)
