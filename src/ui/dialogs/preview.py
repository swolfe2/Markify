"""
Preview dialog for Markify.
Shows converted markdown content before saving, with Save/Cancel options.
Supports editing the Markdown before saving, with full Undo/Redo support.
"""

from __future__ import annotations

import os
import tkinter as tk
from collections.abc import Callable
from tkinter import messagebox, ttk

from core.linter import lint_markdown


class PreviewDialog:
    """
    Preview dialog showing converted markdown before saving.

    Users may edit the content directly before saving. Full undo/redo
    is supported via Ctrl+Z / Ctrl+Y and toolbar buttons.

    Args:
        parent: Parent Tk window.
        colors: Theme color dictionary.
        source_path: Path to source .docx file.
        output_path: Path where .md will be saved.
        content: Markdown content to preview.
        on_save: Callback when Save is clicked. Receives the (possibly edited)
                 content string as its first argument.
        on_open_options: Callback to open the Options dialog.
        icon_path: Path to application icon (.ico).
        icon_photo: PhotoImage for application icon.

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
        on_save: Callable[[str], None] | None = None,
        on_open_options: Callable[[], None] | None = None,
        icon_path: str = None,
        icon_photo: tk.PhotoImage = None,
        code_theme_var: tk.StringVar | None = None,
        enable_linter_var: tk.BooleanVar | None = None,
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
        self._is_dirty = False  # Track whether the user has edited content

        self.code_theme_var = code_theme_var
        self.code_theme_trace_id = None
        if self.code_theme_var:
            self.code_theme_trace_id = self.code_theme_var.trace_add(
                "write", lambda *_: self._apply_highlighting()
            )

        self.enable_linter_var = enable_linter_var
        self.enable_linter_trace_id = None
        if self.enable_linter_var:
            self.enable_linter_trace_id = self.enable_linter_var.trace_add(
                "write", lambda *_: self._run_linter()
            )

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Preview Conversion")
        self.dialog.configure(bg=colors["bg"])
        self.dialog.resizable(True, True)

        # Set icon if provided
        if icon_photo:
            self.dialog.iconphoto(True, icon_photo)
        elif icon_path:
            try:
                self.dialog.iconbitmap(icon_path)
            except (
                Exception
            ):  # nosec B110 - Safe: icon loading is optional, gracefully degrade
                pass

        # Size and position (centered on parent) - increased height for wrapped paths
        w, h = 700, 640
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

        # Intercept window close button to check dirty state
        self.dialog.protocol("WM_DELETE_WINDOW", self._on_cancel)

        # Clean up traces when window is destroyed
        def on_destroy(event):
            if event.widget == self.dialog:
                if self.code_theme_var and self.code_theme_trace_id:
                    try:
                        self.code_theme_var.trace_remove("write", self.code_theme_trace_id)
                    except Exception:  # nosec B110
                        pass
                if self.enable_linter_var and self.enable_linter_trace_id:
                    try:
                        self.enable_linter_var.trace_remove("write", self.enable_linter_trace_id)
                    except Exception:  # nosec B110
                        pass
        self.dialog.bind("<Destroy>", on_destroy)

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
        tk.Label(
            src_frame,
            text=self.source_path,
            bg=c["bg"],
            fg=c["muted"],
            font=("Segoe UI", 9),
            wraplength=600,
            justify=tk.LEFT,
        ).pack(side=tk.LEFT, fill=tk.X)

        # Output path with wrapping
        out_frame = tk.Frame(header, bg=c["bg"])
        out_frame.pack(fill=tk.X, anchor=tk.W)
        tk.Label(
            out_frame, text="Output: ", bg=c["bg"], fg=c["muted"], font=("Segoe UI", 9)
        ).pack(side=tk.LEFT)
        tk.Label(
            out_frame,
            text=self.output_path,
            bg=c["bg"],
            fg=c["muted"],
            font=("Segoe UI", 9),
            wraplength=600,
            justify=tk.LEFT,
        ).pack(side=tk.LEFT, fill=tk.X)

        # Hint about disabling preview with clickable Options link
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

        hint_text.insert("1.0", "(Preview can be disabled in ", "muted")
        hint_text.insert(tk.END, "Options", "link")
        hint_text.insert(tk.END, ")", "muted")

        hint_text.tag_configure(
            "muted", foreground=c["muted"], font=("Segoe UI", 8, "italic")
        )
        hint_text.tag_configure(
            "link", foreground=c["accent"], font=("Segoe UI", 8, "italic underline")
        )

        def on_hint_click(event):
            index = hint_text.index(f"@{event.x},{event.y}")
            if "link" in hint_text.tag_names(index):
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
        ttk.Separator(main, orient="horizontal").pack(fill="x", pady=(10, 4))

        # Editing toolbar (undo / redo / edit hint)
        toolbar = tk.Frame(main, bg=c["bg"])
        toolbar.pack(fill=tk.X, pady=(0, 6))

        # Undo button
        self._undo_btn = tk.Button(
            toolbar,
            text="↩ Undo",
            font=("Segoe UI", 9),
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            cursor="hand2",
            command=self._undo,
            padx=8,
            pady=3,
            state=tk.DISABLED,
        )
        self._undo_btn.pack(side=tk.LEFT, padx=(0, 4))

        # Redo button
        self._redo_btn = tk.Button(
            toolbar,
            text="↪ Redo",
            font=("Segoe UI", 9),
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            cursor="hand2",
            command=self._redo,
            padx=8,
            pady=3,
            state=tk.DISABLED,
        )
        self._redo_btn.pack(side=tk.LEFT, padx=(0, 12))

        # Dirty indicator label (shows when edits have been made)
        self._dirty_label = tk.Label(
            toolbar,
            text="",
            bg=c["bg"],
            fg=c.get("warning", "#f0a500"),
            font=("Segoe UI", 8, "italic"),
        )
        self._dirty_label.pack(side=tk.LEFT, padx=(0, 8))

        self._reset_btn = tk.Button(
            toolbar,
            text="↺ Reset",
            font=("Segoe UI", 9),
            bg=c["secondary_bg"],
            fg=c.get("warning", "#f0a500"),
            activebackground=c["border"],
            activeforeground=c.get("warning", "#f0a500"),
            relief=tk.FLAT,
            cursor="hand2",
            command=self._reset_content,
            padx=8,
            pady=3,
            state=tk.DISABLED,
        )
        self._reset_btn.pack(side=tk.LEFT)

        # Linter status badge
        self._lint_frame = tk.Frame(toolbar, bg=c["bg"])
        self._lint_frame.pack(side=tk.LEFT, padx=(15, 0))

        self._lint_btn = tk.Button(
            self._lint_frame,
            text="",
            font=("Segoe UI", 9, "bold"),
            relief=tk.FLAT,
            cursor="hand2",
            command=self._show_linter_results,
            padx=8,
            pady=3,
        )
        self._lint_btn.pack(side=tk.LEFT)

        # Edit hint (right-aligned)
        tk.Label(
            toolbar,
            text="✏ Editable — Ctrl+Z to undo, Ctrl+Y to redo",
            bg=c["bg"],
            fg=c["muted"],
            font=("Segoe UI", 8, "italic"),
        ).pack(side=tk.RIGHT)

        # Content area with scrollbar
        content_frame = tk.Frame(main, bg=c["bg"])
        content_frame.pack(fill=tk.BOTH, expand=True)

        # Scrollbar
        scrollbar = tk.Scrollbar(content_frame)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Text widget — editable with built-in undo stack
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
            undo=True,       # Enable built-in undo stack
            maxundo=-1,      # Unlimited undo history
            insertbackground=c.get("accent", "#61afef"),  # Cursor colour
        )
        self.text.pack(fill=tk.BOTH, expand=True)
        scrollbar.config(command=self.text.yview)

        # Insert initial content
        self.text.insert(tk.END, self.content)
        # Reset undo stack so initial insert is not undoable
        self.text.edit_reset()

        # Apply basic syntax highlighting for code blocks
        self._apply_highlighting()

        # Run linter initial scan
        self._run_linter()

        # Track modifications to update dirty state
        self.text.bind("<<Modified>>", self._on_text_modified)

        # Keyboard shortcuts
        self.text.bind("<Control-z>", lambda e: self._undo())
        self.text.bind("<Control-Z>", lambda e: self._undo())
        self.text.bind("<Control-y>", lambda e: self._redo())
        self.text.bind("<Control-Y>", lambda e: self._redo())
        self.text.bind("<Control-a>", lambda e: self._select_all())
        self.text.bind("<Control-A>", lambda e: self._select_all())

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

        stats = self._calculate_stats()
        info_text = f"{stats['words']:,} words • {stats['reading_time']} read • {stats['lines']} lines"
        tk.Label(
            stats_frame, text=info_text, bg=c["bg"], fg=c["muted"], font=("Segoe UI", 8)
        ).pack(side=tk.LEFT)

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

    # -------------------------------------------------------------------------
    # Undo / Redo helpers
    # -------------------------------------------------------------------------

    def _undo(self) -> str:
        """Undo last edit in the text widget."""
        try:
            self.text.edit_undo()
        except tk.TclError:
            pass  # Nothing to undo
        self._refresh_undo_buttons()
        return "break"  # Prevent default tkinter handling

    def _redo(self) -> str:
        """Redo last undone edit in the text widget."""
        try:
            self.text.edit_redo()
        except tk.TclError:
            pass  # Nothing to redo
        self._refresh_undo_buttons()
        return "break"

    def _select_all(self) -> str:
        """Select all text in the widget."""
        self.text.tag_add(tk.SEL, "1.0", tk.END)
        self.text.mark_set(tk.INSERT, "1.0")
        self.text.see(tk.INSERT)
        return "break"

    def _on_text_modified(self, event=None):
        """Called by tkinter whenever the Text widget content changes."""
        # tkinter fires <<Modified>> even on programmatic changes;
        # only mark dirty if the flag was actually set
        if self.text.edit_modified():
            self._is_dirty = True
            self._dirty_label.config(text="● Unsaved edits")
            self._reset_btn.config(state=tk.NORMAL)
            self._refresh_undo_buttons()
            self._apply_highlighting()
            self._run_linter()
            # Reset the modified flag so future changes are detected
            self.text.edit_modified(False)

    def _reset_content(self):
        """Restore the text widget to the original Markify output.

        Prompts for confirmation if edits exist. After reset the undo
        stack is cleared so Ctrl+Z cannot un-do the reset itself.
        """
        if self._is_dirty:
            confirmed = messagebox.askyesno(
                "Reset to Original?",
                "This will discard all your edits and restore the original\n"
                "Markify output. This cannot be undone.\n\nContinue?",
                parent=self.dialog,
                icon="warning",
            )
            if not confirmed:
                return

        # Replace content with original
        self.text.config(state=tk.NORMAL)
        self.text.delete("1.0", tk.END)
        self.text.insert(tk.END, self.content)
        # Clear undo/redo stack so the reset itself is not undoable
        self.text.edit_reset()
        # Re-apply syntax highlighting on the fresh content
        self._apply_highlighting()
        # Re-run linter
        self._run_linter()
        # Clear dirty state
        self._is_dirty = False
        self._dirty_label.config(text="")
        self.text.edit_modified(False)
        self._reset_btn.config(state=tk.DISABLED)
        self._undo_btn.config(state=tk.DISABLED)
        self._redo_btn.config(state=tk.DISABLED)

    def _refresh_undo_buttons(self):
        """Enable/disable Undo and Redo buttons based on stack state."""
        # Try undo/redo and re-undo to probe stack availability
        can_undo = False
        can_redo = False
        try:
            self.text.edit_undo()
            self.text.edit_redo()  # Put it back
            can_undo = True
        except tk.TclError:
            pass

        try:
            self.text.edit_redo()
            self.text.edit_undo()  # Put it back
            can_redo = True
        except tk.TclError:
            pass

        self._undo_btn.config(state=tk.NORMAL if can_undo else tk.DISABLED)
        self._redo_btn.config(state=tk.NORMAL if can_redo else tk.DISABLED)
        # Reset is available whenever there are unsaved edits
        self._reset_btn.config(state=tk.NORMAL if self._is_dirty else tk.DISABLED)

    # -------------------------------------------------------------------------
    # Statistics
    # -------------------------------------------------------------------------

    def _calculate_stats(self) -> dict:
        """Calculate document statistics from the original content."""
        lines = self.content.split("\n")
        words = len(self.content.split())
        minutes = words / 200
        if minutes < 1:
            reading_time = "<1 min"
        else:
            reading_time = f"{int(round(minutes))} min"

        headers = {}
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("#"):
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

    # -------------------------------------------------------------------------
    # Syntax highlighting
    # -------------------------------------------------------------------------

    def _apply_highlighting(self):
        """Apply syntax highlighting using selected code theme."""
        from ui.syntax_highlighter import apply_syntax_highlighting
        theme_name = "One Dark"
        if self.code_theme_var:
            theme_name = self.code_theme_var.get()

        # Get content currently in the widget
        current_content = self.text.get("1.0", tk.END)
        if current_content.endswith("\n"):
            current_content = current_content[:-1]

        apply_syntax_highlighting(self.text, current_content, theme_name)

    # -------------------------------------------------------------------------
    # Linting
    # -------------------------------------------------------------------------

    def _run_linter(self):
        """Run the Markdown linter and update the status badge."""
        c = self.colors
        if not hasattr(self, "_lint_btn"):
            return

        # Check if linter is enabled
        enabled = True
        if self.enable_linter_var:
            enabled = self.enable_linter_var.get()

        if not enabled:
            self._lint_btn.pack_forget()
            return

        # Get content currently in the widget
        current_content = self.text.get("1.0", tk.END)
        if current_content.endswith("\n"):
            current_content = current_content[:-1]

        # Use output directory as base directory to check relative link existences
        base_dir = os.path.dirname(self.output_path) if self.output_path else None
        self._lint_issues = lint_markdown(current_content, base_dir=base_dir)

        if not self._lint_issues:
            self._lint_btn.config(
                text="✔ Markdown Lint: 0 issues",
                bg=c.get("success", "#4caf50"),
                fg=c.get("accent_fg", "#ffffff"),
                activebackground=c.get("success", "#4caf50"),
                activeforeground=c.get("accent_fg", "#ffffff"),
                state=tk.DISABLED,
                cursor="arrow",
            )
        else:
            issue_word = "warning" if len(self._lint_issues) == 1 else "warnings"
            self._lint_btn.config(
                text=f"⚠️ Markdown Lint: {len(self._lint_issues)} {issue_word}",
                bg=c.get("warning", "#ff9800"),
                fg="#ffffff",
                activebackground=c["border"],
                activeforeground="#ffffff",
                state=tk.NORMAL,
                cursor="hand2",
            )

        self._lint_btn.pack(side=tk.LEFT)

    def _show_linter_results(self):
        """Show the details dialog for Markdown linter issues."""
        if not hasattr(self, "_lint_issues") or not self._lint_issues:
            return

        from ui.dialogs.linter_results import LinterResultsDialog
        LinterResultsDialog(
            parent=self.dialog,
            colors=self.colors,
            issues=self._lint_issues,
            on_go_to_line=self._go_to_line,
        )

    def _go_to_line(self, line_number: int):
        """Scroll the editor to the specified line number, focus it, and highlight it briefly."""
        self.text.see(f"{line_number}.0")
        self.text.mark_set(tk.INSERT, f"{line_number}.0")
        self.text.focus_force()

        # Temporary highlight
        tag_name = "temp_highlight"
        self.text.tag_configure(tag_name, background="#ffe58f", foreground="#000000")
        self.text.tag_add(tag_name, f"{line_number}.0", f"{line_number}.end")

        # Raise tag above others so it's visible on code blocks too
        try:
            self.text.tag_raise(tag_name)
        except Exception:  # nosec B110
            pass

        self.dialog.after(
            1500,
            lambda: self.text.tag_remove(tag_name, f"{line_number}.0", f"{line_number}.end")
        )

    # -------------------------------------------------------------------------
    # Button actions
    # -------------------------------------------------------------------------

    def _on_save(self):
        """Handle Save button click — pass current (possibly edited) content."""
        self.result = True
        # Get the current content from the text widget (may differ from original)
        current_content = self.text.get("1.0", tk.END)
        # Strip the trailing newline that tkinter always appends
        if current_content.endswith("\n"):
            current_content = current_content[:-1]
        if self.on_save:
            self.on_save(current_content)
        self.dialog.destroy()

    def _on_cancel(self):
        """Handle Cancel button click. Prompt if unsaved edits exist."""
        if self._is_dirty:
            confirmed = messagebox.askyesno(
                "Discard Edits?",
                "You have unsaved edits to the Markdown.\n\nDiscard changes and cancel?",
                parent=self.dialog,
                icon="warning",
            )
            if not confirmed:
                return  # Stay in dialog
        self.result = False
        self.dialog.destroy()

    def _on_open_options(self, event=None):
        """Handle Options link click."""
        if self.on_open_options:
            # Temporarily release grab so Options dialog can open
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
    on_save: Callable[[str], None] | None = None,
    on_open_options: Callable[[], None] | None = None,
    icon_path: str = None,
    icon_photo: tk.PhotoImage = None,
    code_theme_var: tk.StringVar | None = None,
    enable_linter_var: tk.BooleanVar | None = None,
) -> tuple[bool, str]:
    """
    Show preview dialog and return (saved, content).

    Args:
        parent: Parent Tk window.
        colors: Theme color dictionary.
        source_path: Path to source .docx file.
        output_path: Path where .md will be saved.
        content: Markdown content to preview.
        on_save: Callback receiving the final content string when Save is clicked.
        on_open_options: Callback to open options dialog.
        icon_path: Path to application icon.
        icon_photo: PhotoImage for application icon.
        code_theme_var: StringVar for the selected code theme.
        enable_linter_var: BooleanVar for whether the linter is enabled.

    Returns:
        Tuple of (True if user clicked Save, final content string).
        The content string will reflect any edits the user made before saving.
    """
    dialog = PreviewDialog(
        parent,
        colors,
        source_path,
        output_path,
        content,
        on_save=on_save,
        on_open_options=on_open_options,
        icon_path=icon_path,
        icon_photo=icon_photo,
        code_theme_var=code_theme_var,
        enable_linter_var=enable_linter_var,
    )
    return dialog.result
