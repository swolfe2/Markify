"""
Clipboard Mode dialog for Markify.
Two-pane interface: paste formatted text → see Markdown output.
"""
from __future__ import annotations

import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from typing import Any

from core.detectors import detect_code_language
from core.html_to_md import clean_text_for_markdown, html_to_markdown
from logging_config import get_logger

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

    def __init__(self, parent: tk.Tk, colors: dict[str, str], prefs: Any | None = None, on_close: Any | None = None, icon_path: str = None):
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
            except Exception:  # nosec B110 - Safe: icon loading is optional, gracefully degrade
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

        # === STATUS/DIAGNOSTIC BAR ===
        meta_frame = tk.Frame(main, bg=c["bg"])
        meta_frame.pack(fill=tk.X, pady=(10, 0))

        # Reset counters label (hidden/internal)
        self.status_var = tk.StringVar(value="Paste formatted text to convert")
        tk.Label(
            meta_frame, textvariable=self.status_var,
            bg=c["bg"], fg=c.get("fg_secondary", c["fg"]),
            font=("Segoe UI", 9)
        ).pack(side=tk.LEFT)

        # Debug Mode Checkbox
        self.debug_var = tk.BooleanVar(value=self.prefs.get("clipboard_debug_mode", False) if self.prefs else False)
        tk.Checkbutton(
            meta_frame, text="Diagnostic Mode",
            variable=self.debug_var,
            bg=c["bg"], fg=c.get("fg_secondary", c["fg"]),
            selectcolor=c["secondary_bg"],
            activebackground=c["bg"],
            font=("Segoe UI", 9),
            command=self._toggle_debug
        ).pack(side=tk.RIGHT)

        # Open Folder Link (clickable label)
        self.folder_link = tk.Label(
            meta_frame, text="📁 Open Diagnostics",
            bg=c["bg"], fg=c.get("accent", "#0078d4"),
            font=("Segoe UI", 9, "underline"),
            cursor="hand2"
        )
        self.folder_link.pack(side=tk.RIGHT, padx=(0, 15))
        self.folder_link.bind("<Button-1>", lambda e: self._open_debug_folder())

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
                
                # Diagnostic mode: save raw HTML
                if self.debug_var.get():
                    self._save_debug_html(html_content)
                
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

    def _toggle_debug(self):
        """Save debug mode preference."""
        if self.prefs:
            self.prefs.set("clipboard_debug_mode", self.debug_var.get())

    def _save_debug_html(self, html: str):
        """Save raw HTML to the preferences directory for debugging."""
        try:
            import os
            
            # Get preferences directory
            if self.prefs and hasattr(self.prefs, "prefs_dir"):
                debug_dir = self.prefs.prefs_dir
            else:
                # Fallback
                debug_dir = os.path.join(os.environ.get("APPDATA", ""), "Markify")
                if not os.path.exists(debug_dir):
                    os.makedirs(debug_dir)
            
            filepath = os.path.join(debug_dir, "clipboard_debug.html")
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(html)
            
            logger.info(f"Saved diagnostic HTML to {filepath}")
            self.status_var.set(f"✓ Diagnostic HTML saved to prefs folder")
        except Exception as e:
            logger.error(f"Failed to save diagnostic HTML: {e}")

    def _open_debug_folder(self):
        """Open the folder containing diagnostic files in File Explorer."""
        try:
            import os
            import subprocess
            
            if self.prefs and hasattr(self.prefs, "prefs_dir"):
                path = self.prefs.prefs_dir
            else:
                path = os.path.join(os.environ.get("APPDATA", ""), "Markify")
            
            if os.path.exists(path):
                if os.name == 'nt':
                    os.startfile(path)
                else:
                    # Fallback for non-windows (though Markify is mainly windows)
                    subprocess.run(['open' if sys.platform == 'darwin' else 'xdg-open', path], check=False)
        except Exception as e:
            logger.error(f"Failed to open diagnostic folder: {e}")

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
            
            # Only apply aggressive code block detection for non-Word-Online sources
            # Word Online HTML already has code formatting info and aggressive detection
            # causes false positives on prose text
            if not self._is_word_online_html(html):
                markdown = self._detect_and_wrap_code_blocks(markdown)
            else:
                # For Word Online: just clean up excessive blank lines
                markdown = self._clean_word_online_markdown(markdown)
            
            self._set_output(markdown)
            lines = markdown.count('\n') + 1
            self.status_var.set(f"✓ Converted from HTML ({lines} lines)")
        except Exception as e:
            logger.error(f"HTML conversion error: {e}")
            self.status_var.set("Error converting HTML")

    def _is_word_online_html(self, html: str) -> bool:
        """Detect if HTML content is from Word Online.
        
        Word Online HTML has distinctive patterns:
        - SCX/SCXW class names
        - paraid/paraeid attributes
        - data-ccp-* attributes
        """
        indicators = [
            'class="SCXW',
            'class="SCX',
            'paraid="',
            'paraeid="',
            'data-ccp-',
            'Aptos_EmbeddedFont',
            'Aptos_MSFontService',
        ]
        return any(indicator in html for indicator in indicators)

    def _clean_word_online_markdown(self, text: str) -> str:
        """Clean up Word Online markdown output.
        
        Word Online conversion creates excessive blank lines and doesn't
        wrap code blocks properly. This function:
        1. Reduces excessive blank lines
        2. Detects shell/code content and wraps it in code fences, handling heredocs
        """
        import re
        
        # Reduce 3+ consecutive newlines to 2
        text = re.sub(r'\n{3,}', '\n\n', text)
        
        # Remove trailing whitespace from lines
        lines = text.split('\n')
        lines = [line.rstrip() for line in lines]
        
        # Patterns that indicate shell/bash code
        shell_patterns = [
            r'^#!/bin/(bash|sh)',           # Shebang
            r'^set\s+-[euxo]',              # set -e, set -x, etc.
            r'^mkdir\s+',                    # mkdir command
            r'^cd\s+',                       # cd command  
            r'^git\s+(init|add|commit|push)',  # git commands
            r'^echo\s+["\']',               # echo with string
            r'^cat\s+<<',                   # Here document start
            r'^EOT$',                        # End of here doc
            r'^chmod\s+',                    # chmod command
            r'^\./[\w-]+',                   # Run script ./script.sh
            r'^//\s+\w',                     # Comment like // Define
        ]
        
        def is_shell_code(line: str) -> bool:
            """Check if a line looks like shell code."""
            stripped = line.strip()
            if not stripped:
                return False
            # Check shell patterns
            for pattern in shell_patterns:
                if re.match(pattern, stripped):
                    return True
            return False
        
        def get_heredoc_delimiter(line: str) -> str | None:
            """Extract heredoc delimiter from a line like 'cat <<EOT > file'."""
            match = re.search(r'<<\s*([A-Za-z0-9_]+)', line)
            if match:
                return match.group(1)
            return None
            
        def is_code_context(line: str, in_here_doc: str | None) -> bool:
            """Check if line is in a code-like context (after shell code started)."""
            # If we are inside a heredoc, EVERYTHING is code
            if in_here_doc:
                return True
                
            stripped = line.strip()
            if not stripped:
                return True  # Blank lines can be part of code
            # Lines that look like they're continuing code
            if stripped.startswith(('#', '//', 'echo', 'cat', 'EOT', '>', '>>')):
                return True
            return False
        
        # Process lines, detecting and wrapping code blocks
        result = []
        code_buffer = []
        in_shell_code = False
        current_heredoc = None  # Track if we are inside a heredoc (e.g. "EOT")
        
        for i, line in enumerate(lines):
            stripped = line.strip()
            
            # Skip if already in a markdown code block (unless we're inside our own detection)
            if stripped.startswith('```') and not in_shell_code:
                result.append(line)
                continue
            
            # Check for heredoc start/end
            if in_shell_code:
                if current_heredoc:
                    if stripped == current_heredoc:
                        current_heredoc = None
                else:
                    delim = get_heredoc_delimiter(line)
                    if delim:
                        current_heredoc = delim
            
            if is_shell_code(line):
                if not in_shell_code:
                    # Start new code block
                    in_shell_code = True
                    # Check if this start line initiates a heredoc
                    delim = get_heredoc_delimiter(line)
                    if delim:
                        current_heredoc = delim
                code_buffer.append(line)
            elif in_shell_code and is_code_context(line, current_heredoc):
                # Continue code block
                code_buffer.append(line)
            else:
                if in_shell_code and code_buffer:
                    # End code block - wrap in fence
                    result.append('```bash')
                    # Filter out excessive blank lines in code
                    result.extend([l for l in code_buffer if l.strip()]) # Filter out blank lines to fix double-spacing
                    result.append('```')
                    code_buffer = []
                    in_shell_code = False
                    current_heredoc = None
                result.append(line)
        
        # Close any remaining code block
        if in_shell_code and code_buffer:
            result.append('```bash')
            result.extend([l for l in code_buffer if l.strip()])
            result.append('```')
        
        # Now clean up list spacing
        final_result = []
        prev_was_list = False
        prev_was_blank = False
        
        for line in result:
            # Check for standard list markers AND ASCII tree markers (|--) AND Path markers (/)
            is_list = line.strip().startswith(('-', '*', '1.', '2.', '3.', '4.', '5.', '6.', '7.', '8.', '9.', '|', '+', '`', '/'))
            is_blank = not line.strip()
            is_indented_list = (line.startswith('  ') or line.startswith('\t')) and (line.strip().startswith('-') or line.strip().startswith('|'))
            
            if is_blank and prev_was_list:
                prev_was_blank = True
                continue
            
            if prev_was_blank and (is_list or is_indented_list):
                prev_was_blank = False
            elif prev_was_blank:
                final_result.append('')
                prev_was_blank = False
            
            final_result.append(line)
            prev_was_list = is_list or is_indented_list
    
        text = '\n'.join(final_result)
        return self._wrap_ascii_trees(text)

    def _wrap_ascii_trees(self, text: str) -> str:
        """Detect and wrap ASCII directory trees in code blocks."""
        lines = text.split('\n')
        result = []
        tree_buffer = []

        def is_tree_line(line: str) -> bool:
            s = line.strip()
            if not s: return False
            # Strong indicators
            if s.startswith(('|--', '├──', '└──', '│', '+--', '\`--')): return True
            # Weak indicators (path context)
            if s.startswith(('/', '|', '+', '\\')): return True
            return False

        def has_strong_tree_indicator(buffer: list[str]) -> bool:
            for line in buffer:
                s = line.strip()
                if s.startswith(('|--', '├──', '└──', '│', '+--', '\`--')):
                    return True
            return False

        for line in lines:
            if line.strip().startswith('```'):
                # Flush buffer if we hit a code block
                if tree_buffer:
                    if has_strong_tree_indicator(tree_buffer):
                        result.append('```text')
                        result.extend([l for l in tree_buffer if l.strip()])
                        result.append('```')
                    else:
                        result.extend(tree_buffer)
                    tree_buffer = []
                result.append(line)
                continue

            if is_tree_line(line):
                tree_buffer.append(line)
            elif not line.strip() and tree_buffer:
                 # Allow blank lines within a potential tree block
                 tree_buffer.append(line)
            else:
                if tree_buffer:
                    # Flush buffer
                    # Only wrap if we saw Strong indicators OR if it looks like a definitive tree
                    if has_strong_tree_indicator(tree_buffer):
                        # Clean up blank lines before wrapping
                        clean_buffer = [l for l in tree_buffer if l.strip()]
                        if len(clean_buffer) > 1: # Single lines usually not a tree
                            result.append('```text')
                            result.extend(clean_buffer)
                            result.append('```')
                        else:
                            result.extend(tree_buffer)
                    else:
                        result.extend(tree_buffer)
                    tree_buffer = []
                
                result.append(line)

        # Flush remaining
        if tree_buffer:
            if has_strong_tree_indicator(tree_buffer):
                clean_buffer = [l for l in tree_buffer if l.strip()]
                if len(clean_buffer) > 1:
                     result.append('```text')
                     result.extend(clean_buffer)
                     result.append('```')
                else:
                    result.extend(tree_buffer)
            else:
                result.extend(tree_buffer)

        return '\n'.join(result)


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


def show_clipboard_mode(parent: tk.Tk, colors: dict[str, str], prefs: Any | None = None, on_close: Any | None = None, icon_path: str = None) -> ClipboardModeDialog:
    """Show the Clipboard Mode dialog."""
    return ClipboardModeDialog(parent, colors, prefs, on_close, icon_path=icon_path)
