"""
Markdown Linter Results dialog for Markify.
Displays a list of linting issues and allows navigation to the issue lines.
"""
from __future__ import annotations

import tkinter as tk
from collections.abc import Callable
from tkinter import ttk

from core.linter import LintIssue


class LinterResultsDialog:
    """
    Dialog displaying Markdown lint issues.
    """

    def __init__(
        self,
        parent: tk.Tk,
        colors: dict[str, str],
        issues: list[LintIssue],
        on_go_to_line: Callable[[int], None] | None = None,
        icon_path: str = None,
        icon_photo: tk.PhotoImage = None,
    ):
        self.parent = parent
        self.colors = colors
        self.issues = issues
        self.on_go_to_line = on_go_to_line

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Markdown Lint Issues")
        self.dialog.configure(bg=colors["bg"])
        self.dialog.resizable(True, True)

        # Set icon if provided
        if icon_photo:
            self.dialog.iconphoto(True, icon_photo)
        elif icon_path:
            try:
                self.dialog.iconbitmap(icon_path)
            except Exception:  # nosec B110 - Safe: icon loading is optional, gracefully degrade
                pass

        # Size and position
        w, h = 500, 400
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
        tk.Label(
            main,
            text=f"⚠️ Markdown Lint Issues ({len(self.issues)})",
            bg=c["bg"],
            fg=c.get("warning", "#ff9800"),
            font=("Segoe UI", 12, "bold"),
        ).pack(anchor=tk.W, pady=(0, 5))

        tk.Label(
            main,
            text="Click an issue to jump directly to its line in the editor.",
            bg=c["bg"],
            fg=c["muted"],
            font=("Segoe UI", 9, "italic"),
        ).pack(anchor=tk.W, pady=(0, 10))

        # Scrollable frame container
        container = tk.Frame(main, bg=c["bg"])
        container.pack(fill=tk.BOTH, expand=True)

        canvas = tk.Canvas(container, bg=c["bg"], highlightthickness=0)
        scrollbar = ttk.Scrollbar(container, orient="vertical", command=canvas.yview)
        scrollable_frame = tk.Frame(canvas, bg=c["bg"])

        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )

        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw", width=440)
        canvas.configure(yscrollcommand=scrollbar.set)

        # Event binds helper for hover effect
        def make_hover_handlers(r_widget, msg_w, rule_w):
            def on_enter(event):
                r_widget.configure(bg=c["border"])
                msg_w.configure(bg=c["border"])
                rule_w.configure(bg=c["border"])

            def on_leave(event):
                r_widget.configure(bg=c["secondary_bg"])
                msg_w.configure(bg=c["secondary_bg"])
                rule_w.configure(bg=c["secondary_bg"])

            return on_enter, on_leave

        # Build issue items
        for issue in self.issues:
            # Row frame
            row = tk.Frame(scrollable_frame, bg=c["secondary_bg"], padx=8, pady=6, cursor="hand2")
            row.pack(fill=tk.X, pady=3)

            # Severity prefix / symbol
            symbol = "⚠️" if issue.severity == "warning" else "❌"

            # Line badge
            line_lbl = tk.Label(
                row,
                text=f"Line {issue.line_number}",
                bg=c["border"],
                fg=c["fg"],
                font=("Consolas", 9, "bold"),
                width=8,
                anchor=tk.CENTER,
            )
            line_lbl.pack(side=tk.LEFT, padx=(0, 8))

            # Message
            msg_lbl = tk.Label(
                row,
                text=f"{symbol} {issue.message}",
                bg=c["secondary_bg"],
                fg=c["fg"],
                font=("Segoe UI", 9),
                anchor=tk.W,
                wraplength=260,
                justify=tk.LEFT,
            )
            msg_lbl.pack(side=tk.LEFT, fill=tk.X, expand=True)

            # Rule ID
            rule_lbl = tk.Label(
                row,
                text=issue.rule_id,
                bg=c["secondary_bg"],
                fg=c["muted"],
                font=("Consolas", 8),
                anchor=tk.E,
            )
            rule_lbl.pack(side=tk.RIGHT, padx=(5, 0))

            on_enter, on_leave = make_hover_handlers(row, msg_lbl, rule_lbl)

            # Bind to all labels and frame for consistent hover
            for widget in (row, line_lbl, msg_lbl, rule_lbl):
                widget.bind("<Enter>", on_enter)
                widget.bind("<Leave>", on_leave)
                widget.bind(
                    "<Button-1>",
                    lambda e, ln=issue.line_number: self._select_issue(ln),
                )

        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Enable mouse wheel scrolling
        def _on_mousewheel(event):
            canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")
        canvas.bind_all("<MouseWheel>", _on_mousewheel)

        # Close button
        close_btn = tk.Button(
            main,
            text="Close",
            font=("Segoe UI", 10),
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            cursor="hand2",
            command=self.dialog.destroy,
            width=12,
            pady=6,
        )
        close_btn.pack(pady=(15, 0))

        # Unbind mousewheel when dialog closes
        def on_close():
            canvas.unbind_all("<MouseWheel>")
            self.dialog.destroy()

        self.dialog.protocol("WM_DELETE_WINDOW", on_close)

    def _select_issue(self, line_number: int):
        """Handle issue selection — jump to line and close modal."""
        if self.on_go_to_line:
            self.on_go_to_line(line_number)
        self.dialog.destroy()
