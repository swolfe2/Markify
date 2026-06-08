"""
Word to Markdown Converter - GUI
Double-click this file or run it to open the application.
"""

from __future__ import annotations

import os
import shutil
import subprocess  # nosec B404
import sys
import time
import tkinter as tk
import traceback
from tkinter import filedialog, messagebox, ttk

from logging_config import get_logger, setup_logging

# Set Windows AppUserModelID so taskbar shows our icon, not Python's
# This must be done before any tkinter windows are created
try:
    import ctypes

    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(
        "com.markify.converter"
    )
except (
    Exception
):  # nosec B110 - Safe: Windows-specific feature, gracefully degrade if not available
    pass  # Not on Windows or failed - ignore

# Initialize logging
setup_logging()
logger = get_logger("app")


def resource_path(relative_path: str) -> str:
    """Get absolute path to resource, works for dev and for PyInstaller."""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        # In dev mode, we are in src/, so look up one level to project root
        script_dir = os.path.dirname(os.path.abspath(__file__))
        base_path = os.path.dirname(script_dir)  # Go from src/ to project root

    path = os.path.join(base_path, relative_path)
    if not os.path.exists(path):
        # Try parent directory as fallback
        parent_path = os.path.join(os.path.dirname(base_path), relative_path)
        if os.path.exists(parent_path):
            return parent_path

    return path


# Import conversion logic from markify_core
script_dir = os.path.dirname(os.path.abspath(__file__))
# Note: we need to ensure we can find markify_core whether frozen or not
sys.path.insert(0, resource_path("."))
from markify_core import get_docx_content  # noqa: E402
from markify_prefs import Preferences  # noqa: E402
from xlsx_core import get_xlsx_content  # noqa: E402

# Import Mermaid utilities for adding visualization links
try:
    from core.mermaid import add_mermaid_links_to_markdown
except ImportError:
    add_mermaid_links_to_markdown = None

# Import folder scanning utilities for folder drag-and-drop
try:
    from core.folder_scanner import expand_paths
except ImportError:
    expand_paths = None

# Import front matter utilities for static site generators
try:
    from core.frontmatter import add_front_matter_to_markdown
except ImportError:
    add_front_matter_to_markdown = None

# Import MD to DOCX converter for reverse conversion
try:
    from core.md_to_docx import convert_md_file
except ImportError:
    convert_md_file = None

# Import TOC generator
try:
    from core.toc_generator import insert_toc
except ImportError:
    insert_toc = None

# Error classification for user-friendly messages
from core.error_types import classify_docx_error, classify_xlsx_error  # noqa: E402
from themes import get_default_theme, get_syntax_theme_names, get_theme, get_theme_names  # noqa: E402

try:
    import win_dnd  # noqa: E402
except ImportError:
    win_dnd = None  # Should not happen in dev, but safety for build
from ui.app.components.action_buttons import create_action_buttons  # noqa: E402
from ui.app.components.header import create_header  # noqa: E402
from ui.app.components.mode_buttons import create_mode_buttons  # noqa: E402
from ui.app.components.recent_files import refresh_recent_files  # noqa: E402
from ui.clipboard_mode import show_clipboard_mode  # noqa: E402
from ui.components.markdown_viewer import MarkdownViewer  # noqa: E402
from ui.dialogs.diff_viewer import show_diff_viewer  # noqa: E402
from ui.dialogs.error import show_error_dialog  # noqa: E402
from ui.dialogs.options import OptionsDialog  # noqa: E402
from ui.dialogs.preview import show_preview_dialog  # noqa: E402
from ui.dialogs.shortcuts_dialog import show_shortcuts_dialog  # noqa: E402
from ui.dialogs.success import show_success_dialog  # noqa: E402
from ui.styles import configure_styles, update_widget_tree  # noqa: E402

# Theme colors will be loaded dynamically based on user preference
# These are module-level defaults that get updated when the app loads
_current_theme = get_theme(get_default_theme())
BG_COLOR = _current_theme["bg"]
FG_COLOR = _current_theme["fg"]
ACCENT_COLOR = _current_theme["accent"]
ACCENT_FG = _current_theme.get("accent_fg", "#ffffff")
ACCENT_HOVER = _current_theme["accent_hover"]
SEC_BG_COLOR = _current_theme["secondary_bg"]
ERROR_COLOR = _current_theme["error"]


class ConverterApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Markify")
        self.root.geometry("600x660")

        # Initialize Preferences
        self.prefs = Preferences()

        # Load theme from preferences
        theme_name = self.prefs.get("theme", get_default_theme())
        self.colors = get_theme(theme_name)
        self.root.configure(bg=self.colors["bg"])

        # Set App Icon (load .ico from resources folder for Windows taskbar)
        # Note: The ICO file should contain multiple sizes (16, 32, 48, 256)
        # for consistent display across different Windows DPI settings
        self.icon_path = None
        self.icon_photo = None
        try:
            # Use resource_path to handle both dev and PyInstaller modes
            icon_path = resource_path("resources/markify_icon.ico")
            icon_png_path = resource_path("resources/markify_icon.png")

            if os.path.exists(icon_path):
                self.icon_path = icon_path

                # Ensure window is fully initialized before setting icons
                # This prevents race conditions with Windows icon caching
                self.root.update_idletasks()

                # Set icon for window and taskbar
                self.root.iconbitmap(icon_path)
                self.root.wm_iconbitmap(icon_path)
                logger.debug(f"App icon loaded from: {icon_path}")

                # Also set PhotoImage for better consistency
                if os.path.exists(icon_png_path):
                    self.icon_photo = tk.PhotoImage(file=icon_png_path)
                    self.root.iconphoto(True, self.icon_photo)

            else:
                logger.warning(f"Icon file not found at: {icon_path}")
        except Exception as e:  # nosec B110
            logger.warning(f"Failed to load icon: {e}")
            # Fallback to default if something fails

        # Keyboard Bindings
        self.root.bind("<F1>", lambda e: self.open_shortcuts())
        self.root.bind("<Control-Shift-slash>", lambda e: self.open_shortcuts())
        self.root.bind("<Control-o>", lambda e: self.select_file())

        # Style Configuration
        self._configure_styles()

        c = self.colors  # Shorthand

        # Main Layout
        self.main_frame = ttk.Frame(root, padding="40")
        self.main_frame.pack(fill=tk.BOTH, expand=True)

        # Header component (icon, title, version, links)
        create_header(self.main_frame, self.colors, self.open_changelog)

        # Notification area (for update messages, etc.)
        self.notification_container = tk.Frame(self.main_frame, bg=self.colors["bg"])
        self.notification_container.pack(fill=tk.X, pady=0)

        # Action buttons component (Convert, Options, Help)
        self.convert_btn, self.options_btn, self.help_btn = create_action_buttons(
            self.main_frame,
            self.colors,
            self.select_file,
            self.toggle_options,
            self.open_help,
        )

        # Drag-drop hint
        hint_label = ttk.Label(
            self.main_frame,
            text="or drag a .docx / .xlsx file onto this window",
            style="Sub.TLabel",
        )
        hint_label.pack(pady=(0, 10))

        # === OR SEPARATOR ===
        or_frame = tk.Frame(self.main_frame, bg=c["bg"])
        or_frame.pack(fill=tk.X, pady=(0, 10))

        ttk.Separator(or_frame, orient="horizontal").pack(
            side=tk.LEFT, fill=tk.X, expand=True
        )
        tk.Label(
            or_frame,
            text=" OR ",
            bg=c["bg"],
            fg=c.get("fg_secondary", c["fg"]),
            font=("Segoe UI", 9),
        ).pack(side=tk.LEFT, padx=10)
        ttk.Separator(or_frame, orient="horizontal").pack(
            side=tk.LEFT, fill=tk.X, expand=True
        )

        # Mode buttons component (Clipboard, Watch, MD→DOCX, Diff)
        self.clipboard_btn, self.watch_btn, self.reverse_btn, self.diff_btn = (
            create_mode_buttons(
                self.main_frame,
                self.colors,
                self.open_clipboard_mode,
                self.open_watch_mode,
                self.convert_md_to_docx,
                self.open_diff_viewer,
            )
        )

        # Recent files section
        self.recent_frame = tk.Frame(self.main_frame, bg=c["bg"])
        self.recent_frame.pack(fill=tk.X, pady=(0, 10))
        self.refresh_recents()

        # === SLIDING OPTIONS PANEL (Hidden by default) ===
        self.options_visible = False

        # Initialize preference variables
        self.format_dax_var = tk.BooleanVar(value=self.prefs.get("format_dax", False))
        self.format_dax_var.trace_add("write", self.on_pref_change)

        self.format_pq_var = tk.BooleanVar(value=self.prefs.get("format_pq", False))
        self.format_pq_var.trace_add("write", self.on_pref_change)

        self.extract_images_var = tk.BooleanVar(
            value=self.prefs.get("extract_images", False)
        )
        self.extract_images_var.trace_add("write", self.on_pref_change)

        self.output_mode_var = tk.StringVar(value=self.prefs.get("output_mode", "same"))
        self.output_mode_var.trace_add("write", self.on_output_mode_change)

        self.custom_path_var = tk.StringVar(
            value=self.prefs.get("custom_output_dir", "")
        )

        self.theme_var = tk.StringVar(
            value=self.prefs.get("theme", get_default_theme())
        )
        self.theme_var.trace_add("write", self.on_theme_change)

        self.code_theme_var = tk.StringVar(
            value=self.prefs.get("code_theme", "One Dark")
        )
        self.code_theme_var.trace_add("write", self.on_code_theme_change)

        self.show_preview_var = tk.BooleanVar(
            value=self.prefs.get("show_preview", True)
        )
        self.show_preview_var.trace_add("write", self.on_pref_change)

        self.add_front_matter_var = tk.BooleanVar(
            value=self.prefs.get("add_front_matter", False)
        )
        self.add_front_matter_var.trace_add("write", self.on_pref_change)

        self.add_toc_var = tk.BooleanVar(value=self.prefs.get("add_toc", False))
        self.add_toc_var.trace_add("write", self.on_pref_change)

        self.enable_linter_var = tk.BooleanVar(
            value=self.prefs.get("enable_linter", True)
        )
        self.enable_linter_var.trace_add("write", self.on_pref_change)

        self.check_for_updates_var = tk.BooleanVar(
            value=self.prefs.get("check_for_updates", True)
        )
        self.check_for_updates_var.trace_add("write", self.on_pref_change)

        # Map internal export format key to UI drop-down labels
        pref_format = self.prefs.get("export_format", "markdown")
        ui_format = "Standard Markdown"
        if pref_format == "confluence":
            ui_format = "Confluence Wiki Syntax"
        elif pref_format == "ado_wiki":
            ui_format = "Azure DevOps Wiki"

        self.export_format_var = tk.StringVar(value=ui_format)
        self.export_format_var.trace_add("write", self.on_pref_change)

        # Options dialog will be created on-demand
        self.options_dialog = None

        # Initial state update for entry/button (they'll be created in the dialog)
        # We'll update state when dialog opens

        # Progress Bar (Hidden by default)
        self.progress = ttk.Progressbar(
            self.main_frame, orient=tk.HORIZONTAL, length=100, mode="determinate"
        )

        # Status Bar

        self.status_var = tk.StringVar()
        self.status_var.set("Ready")
        status_bar = tk.Label(
            root,
            textvariable=self.status_var,
            bg=SEC_BG_COLOR,
            fg="#cccccc",
            font=("Segoe UI", 9),
            anchor=tk.W,
            padx=10,
            pady=5,
        )
        status_bar.pack(side=tk.BOTTOM, fill=tk.X)

        # Enable Drag & Drop
        if win_dnd:
            try:
                # We need to wait for the window to have a handle
                # update_idletasks is called inside hook_window
                win_dnd.hook_window(self.root, self.on_drop_files)
            except Exception as e:
                logger.warning(f"Failed to initialize Drag & Drop: {e}")

        # Check for updates on startup if preference is enabled
        if self.prefs.get("check_for_updates", True):
            self.root.after(2000, self.check_for_updates_auto)

    def refresh_recents(self):
        """Refresh the Recent Files list UI using component."""
        recents = self.prefs.get("recent_files", [])
        refresh_recent_files(self.recent_frame, self.colors, recents)

    def on_pref_change(self, *args):
        """Save preferences when variables change."""
        self.prefs.set("format_dax", self.format_dax_var.get())
        self.prefs.set("format_pq", self.format_pq_var.get())
        self.prefs.set("extract_images", self.extract_images_var.get())
        self.prefs.set("show_preview", self.show_preview_var.get())
        self.prefs.set("add_front_matter", self.add_front_matter_var.get())
        self.prefs.set("add_toc", self.add_toc_var.get())
        self.prefs.set("enable_linter", self.enable_linter_var.get())
        self.prefs.set("check_for_updates", self.check_for_updates_var.get())

        # Save export format preference
        ui_format = self.export_format_var.get()
        internal_format = "markdown"
        if ui_format == "Confluence Wiki Syntax":
            internal_format = "confluence"
        elif ui_format == "Azure DevOps Wiki":
            internal_format = "ado_wiki"
        self.prefs.set("export_format", internal_format)

    def toggle_options(self, event=None):
        """Open the Options dialog."""
        # If dialog already open, bring it to front
        if self.options_dialog and self.options_dialog.winfo_exists():
            self.options_dialog.lift()
            self.options_dialog.focus_force()
            return

        # Create dialog with config
        config = {
            "format_dax_var": self.format_dax_var,
            "format_pq_var": self.format_pq_var,
            "extract_images_var": self.extract_images_var,
            "show_preview_var": self.show_preview_var,
            "add_front_matter_var": self.add_front_matter_var,
            "add_toc_var": self.add_toc_var,
            "output_mode_var": self.output_mode_var,
            "custom_path_var": self.custom_path_var,
            "theme_var": self.theme_var,
            "theme_names": get_theme_names(),
            "code_theme_var": self.code_theme_var,
            "code_theme_names": get_syntax_theme_names(),
            "enable_linter_var": self.enable_linter_var,
            "check_for_updates_var": self.check_for_updates_var,
            "export_format_var": self.export_format_var,
            "on_browse": self.browse_output_folder,
        }
        self.options_dialog = OptionsDialog(
            self.root,
            self.colors,
            config,
            icon_path=self.icon_path,
            icon_photo=self.icon_photo,
        )

    def on_output_mode_change(self, *args):
        mode = self.output_mode_var.get()
        self.prefs.set("output_mode", mode)
        self.update_custom_ui_state()

    def on_code_theme_change(self, *args):
        """Save code theme preference."""
        self.prefs.set("code_theme", self.code_theme_var.get())

    def on_theme_change(self, *args):
        """Save theme preference and apply changes immediately."""
        theme_name = self.theme_var.get()
        self.prefs.set("theme", theme_name)

        # Get old and new colors
        old_colors = self.colors
        new_colors = get_theme(theme_name)
        self.colors = new_colors

        # 1. Update TTK styles (handles Title.TLabel, Sucess.TLabel, etc.)
        self._configure_styles()

        # 2. Update Root window background
        self.root.configure(bg=new_colors["bg"])

        # 3. Recursively update all TK widgets in the hierarchy
        self._update_widget_tree(self.root, old_colors, new_colors)

        # 4. If options dialog is open, update it too
        if self.options_dialog and self.options_dialog.winfo_exists():
            self.options_dialog.configure(bg=new_colors["bg"])
            self._update_widget_tree(self.options_dialog.dialog, old_colors, new_colors)

    def _update_widget_tree(self, parent, old, new):
        """Wrapper for update_widget_tree utility."""
        update_widget_tree(parent, old, new)

    def update_custom_ui_state(self):
        # Check if widgets exist (they're created in dialog)
        if not hasattr(self, "entry_custom") or self.entry_custom is None:
            return
        if not self.entry_custom.winfo_exists():
            return

        mode = self.output_mode_var.get()
        if mode == "custom":
            self.entry_custom.configure(state="normal")
            self.btn_browse_out.configure(state="normal")
        else:
            self.entry_custom.configure(state="disabled")
            self.btn_browse_out.configure(state="disabled")

    def browse_output_folder(self):
        folder_selected = filedialog.askdirectory(initialdir=self.custom_path_var.get())
        if folder_selected:
            self.custom_path_var.set(folder_selected)
            self.prefs.set("custom_output_dir", folder_selected)

    def on_drop_files(self, file_paths):
        """Handle files and folders dropped onto the window"""
        valid_extensions = (".docx", ".xlsx")

        # Use folder scanner if available (handles both files and folders)
        if expand_paths:
            valid_files = expand_paths(file_paths)
        else:
            # Fallback: only accept individual files (no folder support)
            valid_files = [
                f
                for f in file_paths
                if os.path.isfile(f) and f.lower().endswith(valid_extensions)
            ]

        if not valid_files:
            # Check if user dropped folders but no files were found
            dropped_folders = [p for p in file_paths if os.path.isdir(p)]
            if dropped_folders:
                messagebox.showinfo(
                    "No Files Found",
                    "No .docx or .xlsx files found in the dropped folder(s).",
                )
            else:
                messagebox.showwarning(
                    "Invalid File", "Please drop .docx or .xlsx files only."
                )
            return

        # Bring window to front
        self.root.deiconify()
        self.root.lift()
        self.root.focus_force()

        # Show count if multiple files from folder
        if len(valid_files) > 1:
            logger.info(f"Processing {len(valid_files)} files from dropped paths")

        # Process them
        self.process_files(valid_files)

    def _configure_styles(self):
        """Wrapper for configure_styles utility."""
        configure_styles(self.colors)

    def open_readme(self):
        """Open the README documentation viewer."""
        readme_path = resource_path("README.md")
        if os.path.exists(readme_path):
            MarkdownViewer(
                self.root,
                readme_path,
                self.colors,
                icon_path=self.icon_path,
                icon_photo=self.icon_photo,
            )
        else:
            messagebox.showwarning("Help", f"README.md not found at {readme_path}")

    def open_help(self):
        """Post a popup/dropdown menu below the Help button."""
        menu = tk.Menu(self.root, tearoff=0)
        c = self.colors

        menu.configure(
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["accent"],
            activeforeground=c.get("accent_fg", "#ffffff"),
            font=("Segoe UI", 10)
        )

        menu.add_command(label="📖  Documentation (README)", command=self.open_readme)
        menu.add_command(label="⌨️  Keyboard Shortcuts (F1)", command=self.open_shortcuts)
        menu.add_command(label="📋  What's New (Changelog)", command=self.open_changelog)
        menu.add_separator()
        menu.add_command(label="🔄  Check for Updates...", command=self.check_for_updates_manual)

        try:
            x = self.help_btn.winfo_rootx()
            y = self.help_btn.winfo_rooty() + self.help_btn.winfo_height()
            menu.post(x, y)
        except Exception as e:
            logger.warning(f"Failed to post Help menu: {e}")

    def show_update_notification(self, remote_version: str):
        """Display a non-blocking banner at the top of the main window."""
        self.dismiss_update_notification()

        c = self.colors
        self.notification_container.pack_configure(pady=(5, 15))

        card = tk.Frame(
            self.notification_container,
            bg=c["secondary_bg"],
            highlightbackground=c["accent"],
            highlightthickness=1,
            padx=10,
            pady=8,
        )
        card.pack(fill=tk.X)

        label = ttk.Label(
            card,
            text=f"🚀 A new version (v{remote_version}) is available!",
            style="Body.TLabel",
            background=c["secondary_bg"],
        )
        label.pack(side=tk.LEFT, padx=(5, 10))

        download_btn = tk.Button(
            card,
            text="Download",
            font=("Segoe UI", 9, "bold"),
            bg=c["accent"],
            fg=c.get("accent_fg", "#ffffff"),
            activebackground=c["accent_hover"],
            activeforeground=c.get("accent_fg", "#ffffff"),
            relief=tk.FLAT,
            cursor="hand2",
            padx=10,
            pady=2,
            command=lambda: subprocess.Popen(  # nosec B602 B607 - Safe: fixed GitHub releases URL
                ["start", f"https://github.com/swolfe2/Markify/releases/tag/{remote_version}"],
                shell=True,
            ),
        )
        download_btn.pack(side=tk.RIGHT, padx=(5, 0))

        dismiss_btn = tk.Button(
            card,
            text="✕",
            font=("Segoe UI", 10),
            bg=c["secondary_bg"],
            fg=c["muted"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            cursor="hand2",
            padx=5,
            pady=2,
            command=self.dismiss_update_notification,
        )
        dismiss_btn.pack(side=tk.RIGHT)

    def dismiss_update_notification(self):
        """Dismiss the update banner and reset container spacing."""
        for widget in self.notification_container.winfo_children():
            widget.destroy()
        self.notification_container.pack_configure(pady=0)

    def check_for_updates_auto(self):
        """Silently check for updates in the background on startup."""
        from config import __version__
        from core.update_checker import check_for_updates_async

        def on_check_complete(remote_version: str | None):
            if remote_version:
                from core.update_checker import is_newer_version
                if is_newer_version(remote_version, __version__):
                    self.show_update_notification(remote_version)

        check_for_updates_async(
            lambda res: self.root.after(0, lambda: on_check_complete(res))
        )

    def check_for_updates_manual(self):
        """Perform a user-triggered manual update check with feedback."""
        self.status_var.set("Checking for updates...")
        from config import __version__
        from core.update_checker import check_for_updates_async

        def on_complete(remote_version: str | None):
            self.status_var.set("Ready")
            if remote_version:
                from core.update_checker import is_newer_version
                if is_newer_version(remote_version, __version__):
                    self.show_update_notification(remote_version)
                    messagebox.showinfo(
                        "Check for Updates",
                        f"A new version (v{remote_version}) is available!\n\nClick the Download button in the notification banner to get it.",
                        parent=self.root,
                    )
                else:
                    messagebox.showinfo(
                        "Check for Updates",
                        f"Markify is up to date (v{__version__}).",
                        parent=self.root,
                    )
            else:
                messagebox.showerror(
                    "Check for Updates",
                    "Could not check for updates. Please check your internet connection.",
                    parent=self.root,
                )

        check_for_updates_async(
            lambda res: self.root.after(0, lambda: on_complete(res))
        )

    def open_changelog(self):
        """Open the Changelog viewer."""
        changelog_path = resource_path("CHANGELOG.md")
        if os.path.exists(changelog_path):
            MarkdownViewer(
                self.root,
                changelog_path,
                self.colors,
                icon_path=self.icon_path,
                icon_photo=self.icon_photo,
            )
        else:
            messagebox.showwarning(
                "Changelog", f"CHANGELOG.md not found at {changelog_path}"
            )

    def open_shortcuts(self):
        """Open the Keyboard Shortcuts dialog."""
        show_shortcuts_dialog(
            self.root, self.colors, icon_path=self.icon_path, icon_photo=self.icon_photo
        )

    def open_clipboard_mode(self):
        """Open the Clipboard Mode dialog."""
        show_clipboard_mode(
            self.root,
            self.colors,
            self.prefs,
            on_close=self.refresh_recents,
            icon_path=self.icon_path,
            icon_photo=self.icon_photo,
        )

    def open_watch_mode(self):
        """Open the Watch Mode dialog."""
        from ui.dialogs.watch import WatchModeDialog

        WatchModeDialog(
            self.root,
            self.colors,
            self.prefs,
            on_close=self.refresh_recents,
            icon_path=self.icon_path,
        )

    def convert_md_to_docx(self):
        """Open file dialog to select MD file and convert to DOCX."""
        if not convert_md_file:
            messagebox.showwarning(
                "Not Available", "MD to DOCX conversion is not available."
            )
            return

        # File dialog
        initial_dir = self.prefs.get("last_directory", "")
        file_path = filedialog.askopenfilename(
            title="Select Markdown File",
            initialdir=initial_dir if initial_dir else None,
            filetypes=[("Markdown Files", "*.md"), ("All Files", "*.*")],
        )

        if not file_path:
            return

        # Save directory preference
        self.prefs.set("last_directory", os.path.dirname(file_path))

        # Convert
        self.status_var.set(f"Converting {os.path.basename(file_path)} to DOCX...")
        self.root.update()

        success, result = convert_md_file(file_path)

        if success:
            self.status_var.set("Conversion complete!")
            show_success_dialog(
                self.root,
                self.colors,
                output_path=result,
                message=f"Created: {os.path.basename(result)}",
                on_close=self.refresh_recents,
                icon_path=self.icon_path,
            )
        else:
            self.status_var.set("Conversion failed")
            messagebox.showerror("Conversion Error", result)

    def open_diff_viewer(self):
        """Open the Diff View dialog to compare two files."""
        show_diff_viewer(
            self.root,
            self.colors,
            icon_path=self.icon_path,
            icon_photo=self.icon_photo,
            code_theme_var=self.code_theme_var,
        )

    def select_file(self):
        initial_dir = self.prefs.get("last_directory", "")
        if not os.path.exists(initial_dir):
            initial_dir = "/"

        file_paths = filedialog.askopenfilenames(
            title="Select Documents",
            initialdir=initial_dir,
            filetypes=[
                ("Supported Files", "*.docx *.xlsx *.dax *.msdax *.pbix *.bim *.tmdl *.pptx"),
                ("Word Documents", "*.docx"),
                ("Excel Spreadsheets", "*.xlsx"),
                ("PowerPoint Presentations", "*.pptx"),
                ("DAX Studio Files", "*.dax *.msdax"),
                ("Power BI Reports", "*.pbix"),
                ("Tabular Editor Files", "*.bim *.tmdl"),
                ("All Files", "*.*"),
            ],
        )
        if file_paths:
            # Save the directory of the first selected file
            first_dir = os.path.dirname(file_paths[0])
            self.prefs.set("last_directory", first_dir)
            self.process_files(file_paths)

    def process_files(self, source_paths):
        """Process files, routing to appropriate converter based on extension."""
        total = len(source_paths)
        if total == 1:
            source_path = source_paths[0]
            if source_path.lower().endswith(".xlsx"):
                self._process_xlsx_async(source_path)
            elif source_path.lower().endswith((".dax", ".msdax")):
                self._process_dax_async(source_path)
            elif source_path.lower().endswith(".pbix"):
                self._process_pbix_async(source_path)
            elif source_path.lower().endswith((".bim", ".tmdl")):
                self._process_tmdl_async(source_path)
            elif source_path.lower().endswith(".pptx"):
                self._process_pptx_async(source_path)
            else:
                self._process_single_async(source_path)
            return

        success_count = 0

        # Setup Progress Bar
        self.progress.pack(fill=tk.X, pady=(20, 0))
        self.progress["maximum"] = total
        self.progress["value"] = 0
        self.root.update()

        for i, source_path in enumerate(source_paths, 1):
            self.status_var.set(
                f"Converting ({i}/{total}): {os.path.basename(source_path)}..."
            )
            self.root.update()

            # Route to appropriate converter based on file type
            if source_path.lower().endswith(".xlsx"):
                success, output_file, _ = self._perform_xlsx_conversion(source_path)
            elif source_path.lower().endswith((".dax", ".msdax")):
                success, output_file, _ = self._perform_dax_conversion(source_path)
            elif source_path.lower().endswith(".pbix"):
                success, output_file, _ = self._perform_pbix_conversion(source_path)
            elif source_path.lower().endswith((".bim", ".tmdl")):
                success, output_file, _ = self._perform_tmdl_conversion(source_path)
            elif source_path.lower().endswith(".pptx"):
                success, output_file, _ = self._perform_pptx_conversion(source_path)
            else:
                success, output_file, _ = self._perform_conversion(source_path)

            if success:
                success_count += 1
                # Handle tuple from preview mode (content, path)
                if isinstance(output_file, tuple):
                    _, actual_path = output_file
                    # In batch mode, write directly
                    content, path = output_file
                    try:
                        with open(path, "w", encoding="utf-8") as f:
                            f.write(content)
                        self.prefs.add_recent_file(source_path, path)
                    except (
                        Exception
                    ):  # nosec B110 - Safe: recent files tracking is optional
                        pass
                else:
                    self.prefs.add_recent_file(source_path, output_file)

            self.progress["value"] = i
            self.root.update()

        # Refresh recents UI
        self.refresh_recents()

        # Hide progress bar
        self.progress.pack_forget()

        file_word = "file" if total == 1 else "files"
        self.status_var.set(
            f"Completed: {success_count}/{total} {file_word} converted."
        )

        if success_count > 0:
            # Batch behavior: Show summary
            show_success_dialog(
                self.root,
                self.colors,
                os.path.dirname(source_paths[0]),
                single_mode=False,
                count=success_count,
                on_run_cmd=self._run_cmd,
                icon_path=self.icon_path,
            )

    def _process_single_async(self, source_path):
        """Handle single file conversion in a separate thread."""
        self.status_var.set(f"Converting: {os.path.basename(source_path)}...")

        # Store source path for use in callback
        self._pending_source_path = source_path

        # Indeterminate progress
        self.progress.pack(fill=tk.X, pady=(20, 0))
        self.progress.configure(mode="indeterminate")
        self.progress.start(10)
        self.root.update()  # Force UI refresh to show progress bar

        # Disable inputs
        self.convert_btn.configure(state="disabled")
        if hasattr(self, "options_btn"):
            self.options_btn.configure(state="disabled")

        def run_thread():
            result = self._perform_conversion(source_path)
            # Schedule completion on main thread
            self.root.after(0, lambda: self._on_single_complete(result, source_path))

        import threading

        t = threading.Thread(target=run_thread, daemon=True)
        t.start()

    def _process_xlsx_async(self, source_path):
        """Handle single Excel file conversion in a separate thread."""
        self.status_var.set(f"Converting Excel: {os.path.basename(source_path)}...")

        # Indeterminate progress
        self.progress.pack(fill=tk.X, pady=(20, 0))
        self.progress.configure(mode="indeterminate")
        self.progress.start(10)
        self.root.update()

        # Disable inputs
        self.convert_btn.configure(state="disabled")
        if hasattr(self, "options_btn"):
            self.options_btn.configure(state="disabled")

        def run_thread():
            result = self._perform_xlsx_conversion(source_path)
            self.root.after(0, lambda: self._on_xlsx_complete(result, source_path))

        import threading

        t = threading.Thread(target=run_thread, daemon=True)
        t.start()

    def _process_dax_async(self, source_path):
        """Handle single DAX file conversion in a separate thread."""
        self.status_var.set(f"Converting DAX: {os.path.basename(source_path)}...")

        # Indeterminate progress
        self.progress.pack(fill=tk.X, pady=(20, 0))
        self.progress.configure(mode="indeterminate")
        self.progress.start(10)
        self.root.update()

        # Disable inputs
        self.convert_btn.configure(state="disabled")
        if hasattr(self, "options_btn"):
            self.options_btn.configure(state="disabled")

        def run_thread():
            result = self._perform_dax_conversion(source_path)
            self.root.after(0, lambda: self._on_dax_complete(result, source_path))

        import threading

        t = threading.Thread(target=run_thread, daemon=True)
        t.start()

    def _perform_dax_conversion(self, source_path):
        """Convert DAX file to Markdown. Returns (success, output_path_or_content, error_dict)."""
        try:
            # Determine output path
            base_name_only = os.path.splitext(os.path.basename(source_path))[0]
            output_mode = self.prefs.get("output_mode", "same")
            custom_dir = self.prefs.get("custom_output_dir", "")

            if output_mode == "custom" and custom_dir and os.path.exists(custom_dir):
                output_file = os.path.join(custom_dir, f"{base_name_only}.md")
            else:
                output_file = os.path.join(
                    os.path.dirname(source_path), f"{base_name_only}.md"
                )

            # Convert using dax_import
            from core.dax_import import convert_dax_file
            content = convert_dax_file(
                source_path,
                format_code=self.prefs.get("format_dax", True)
            )

            if content:
                # Add YAML front matter for static site generators
                if add_front_matter_to_markdown and self.prefs.get(
                    "add_front_matter", False
                ):
                    content = add_front_matter_to_markdown(
                        content, filename=os.path.basename(source_path)
                    )

                # Apply export format conversion
                export_format = self.prefs.get("export_format", "markdown")
                if export_format == "confluence":
                    from core.confluence import full_convert
                    content = full_convert(content)
                elif export_format == "ado_wiki":
                    from core.ado_wiki import full_convert as ado_full_convert
                    content = ado_full_convert(content)

                # Check if preview mode
                if self.prefs.get("show_preview", True):
                    return True, (content, output_file), None
                else:
                    with open(output_file, "w", encoding="utf-8") as f:
                        f.write(content)
                    return True, output_file, None
            else:
                return (
                    False,
                    None,
                    {
                        "title": "Conversion Error",
                        "message": f"Failed to convert {os.path.basename(source_path)}",
                        "details": "No content extracted from DAX file.",
                    },
                )
        except Exception as e:
            logger.error(f"DAX conversion failed: {e}")
            return (
                False,
                None,
                {
                    "title": "Conversion Error",
                    "message": f"Failed to convert {os.path.basename(source_path)}",
                    "details": str(e),
                },
            )

    def _on_dax_complete(self, result, source_path):
        """Callback when DAX file conversion finishes."""
        success, output_data, error_info = result

        if success and isinstance(output_data, tuple):
            content, output_file_path = output_data
        else:
            content = None
            output_file_path = output_data

        # Stop progress
        self.progress.stop()
        self.progress.configure(mode="determinate")
        self.progress.pack_forget()

        # Re-enable inputs
        self.convert_btn.configure(state="normal")
        if hasattr(self, "options_btn"):
            self.options_btn.configure(state="normal")

        if success:
            if self.show_preview_var.get():
                _saved_content = [content]

                def _on_dax_preview_save(final_content: str):
                    try:
                        with open(output_file_path, "w", encoding="utf-8") as f:
                            f.write(final_content)
                        _saved_content[0] = final_content
                        self.status_var.set("DAX Conversion Successful!")
                        self.prefs.add_recent_file(source_path, output_file_path)
                        self.refresh_recents()
                        show_success_dialog(
                            self.root,
                            self.colors,
                            output_file_path,
                            single_mode=True,
                            on_run_cmd=self._run_cmd,
                            icon_path=self.icon_path,
                        )
                    except Exception as e:
                        self.status_var.set("Save Failed.")
                        show_error_dialog(
                            self.root,
                            self.colors,
                            title="Save Error",
                            message="Failed to save file",
                            details=str(e),
                            icon_photo=self.icon_photo,
                        )

                user_approved = show_preview_dialog(
                    self.root,
                    self.colors,
                    source_path,
                    output_file_path,
                    content,
                    on_save=_on_dax_preview_save,
                    on_open_options=self.toggle_options,
                    icon_path=self.icon_path,
                    icon_photo=self.icon_photo,
                    code_theme_var=self.code_theme_var,
                    enable_linter_var=self.enable_linter_var,
                )

                if not user_approved:
                    self.status_var.set("Conversion cancelled.")
            else:
                self.status_var.set("DAX Conversion Successful!")
                self.prefs.add_recent_file(source_path, output_file_path)
                self.refresh_recents()
                show_success_dialog(
                    self.root,
                    self.colors,
                    output_file_path,
                    single_mode=True,
                    on_run_cmd=self._run_cmd,
                    icon_path=self.icon_path,
                )
        else:
            if error_info:
                show_error_dialog(
                    self.root, self.colors, icon_photo=self.icon_photo, **error_info
                )

    def _process_pbix_async(self, source_path):
        """Handle single Power BI file conversion in a separate thread."""
        self.status_var.set(f"Extracting PBIX Metadata: {os.path.basename(source_path)}...")

        # Indeterminate progress
        self.progress.pack(fill=tk.X, pady=(20, 0))
        self.progress.configure(mode="indeterminate")
        self.progress.start(10)
        self.root.update()

        # Disable inputs
        self.convert_btn.configure(state="disabled")
        if hasattr(self, "options_btn"):
            self.options_btn.configure(state="disabled")

        def run_thread():
            result = self._perform_pbix_conversion(source_path)
            self.root.after(0, lambda: self._on_pbix_complete(result, source_path))

        import threading

        t = threading.Thread(target=run_thread, daemon=True)
        t.start()

    def _perform_pbix_conversion(self, source_path):
        """Extract PBIX metadata to Markdown. Returns (success, output_path_or_content, error_dict)."""
        try:
            # Determine output path
            base_name_only = os.path.splitext(os.path.basename(source_path))[0]
            output_mode = self.prefs.get("output_mode", "same")
            custom_dir = self.prefs.get("custom_output_dir", "")

            if output_mode == "custom" and custom_dir and os.path.exists(custom_dir):
                output_file = os.path.join(custom_dir, f"{base_name_only}.md")
            else:
                output_file = os.path.join(
                    os.path.dirname(source_path), f"{base_name_only}.md"
                )

            # Convert using pbix_core
            from pbix_core import get_pbix_metadata
            content = get_pbix_metadata(source_path)

            if content:
                # Add YAML front matter if enabled
                if add_front_matter_to_markdown and self.prefs.get(
                    "add_front_matter", False
                ):
                    content = add_front_matter_to_markdown(
                        content, filename=os.path.basename(source_path)
                    )

                # Apply export format conversion
                export_format = self.prefs.get("export_format", "markdown")
                if export_format == "confluence":
                    from core.confluence import full_convert
                    content = full_convert(content)
                elif export_format == "ado_wiki":
                    from core.ado_wiki import full_convert as ado_full_convert
                    content = ado_full_convert(content)

                # Check if preview mode
                if self.prefs.get("show_preview", True):
                    return True, (content, output_file), None
                else:
                    with open(output_file, "w", encoding="utf-8") as f:
                        f.write(content)
                    return True, output_file, None
            else:
                return (
                    False,
                    None,
                    {
                        "title": "Extraction Error",
                        "message": f"Failed to extract metadata from {os.path.basename(source_path)}",
                        "details": "No metadata content extracted.",
                    },
                )
        except Exception as e:
            logger.error(f"PBIX extraction failed: {e}")
            return (
                False,
                None,
                {
                    "title": "Extraction Error",
                    "message": f"Failed to extract metadata from {os.path.basename(source_path)}",
                    "details": str(e),
                },
            )

    def _on_pbix_complete(self, result, source_path):
        """Callback when PBIX metadata extraction finishes."""
        success, output_data, error_info = result

        if success and isinstance(output_data, tuple):
            content, output_file_path = output_data
        else:
            content = None
            output_file_path = output_data

        # Stop progress
        self.progress.stop()
        self.progress.configure(mode="determinate")
        self.progress.pack_forget()

        # Re-enable inputs
        self.convert_btn.configure(state="normal")
        if hasattr(self, "options_btn"):
            self.options_btn.configure(state="normal")

        if success:
            if self.show_preview_var.get():
                _saved_content = [content]

                def _on_pbix_preview_save(final_content: str):
                    try:
                        with open(output_file_path, "w", encoding="utf-8") as f:
                            f.write(final_content)
                        _saved_content[0] = final_content
                        self.status_var.set("Metadata Extraction Successful!")
                        self.prefs.add_recent_file(source_path, output_file_path)
                        self.refresh_recents()
                        show_success_dialog(
                            self.root,
                            self.colors,
                            output_file_path,
                            single_mode=True,
                            on_run_cmd=self._run_cmd,
                            icon_path=self.icon_path,
                        )
                    except Exception as e:
                        self.status_var.set("Save Failed.")
                        show_error_dialog(
                            self.root,
                            self.colors,
                            title="Save Error",
                            message="Failed to save file",
                            details=str(e),
                            icon_photo=self.icon_photo,
                        )

                user_approved = show_preview_dialog(
                    self.root,
                    self.colors,
                    source_path,
                    output_file_path,
                    content,
                    on_save=_on_pbix_preview_save,
                    on_open_options=self.toggle_options,
                    icon_path=self.icon_path,
                    icon_photo=self.icon_photo,
                    code_theme_var=self.code_theme_var,
                    enable_linter_var=self.enable_linter_var,
                )

                if not user_approved:
                    self.status_var.set("Conversion cancelled.")
            else:
                self.status_var.set("Metadata Extraction Successful!")
                self.prefs.add_recent_file(source_path, output_file_path)
                self.refresh_recents()
                show_success_dialog(
                    self.root,
                    self.colors,
                    output_file_path,
                    single_mode=True,
                    on_run_cmd=self._run_cmd,
                    icon_path=self.icon_path,
                )
            if error_info:
                show_error_dialog(
                    self.root, self.colors, icon_photo=self.icon_photo, **error_info
                )

    def _process_tmdl_async(self, source_path):
        """Handle single TMDL/BIM file conversion in a separate thread."""
        self.status_var.set(f"Extracting TMDL/BIM Metadata: {os.path.basename(source_path)}...")

        # Indeterminate progress
        self.progress.pack(fill=tk.X, pady=(20, 0))
        self.progress.configure(mode="indeterminate")
        self.progress.start(10)
        self.root.update()

        # Disable inputs
        self.convert_btn.configure(state="disabled")
        if hasattr(self, "options_btn"):
            self.options_btn.configure(state="disabled")

        def run_thread():
            result = self._perform_tmdl_conversion(source_path)
            self.root.after(0, lambda: self._on_tmdl_complete(result, source_path))

        import threading

        t = threading.Thread(target=run_thread, daemon=True)
        t.start()

    def _perform_tmdl_conversion(self, source_path):
        """Extract TMDL/BIM metadata to Markdown. Returns (success, output_path_or_content, error_dict)."""
        try:
            # Determine output path
            base_name_only = os.path.splitext(os.path.basename(source_path))[0]
            output_mode = self.prefs.get("output_mode", "same")
            custom_dir = self.prefs.get("custom_output_dir", "")

            if output_mode == "custom" and custom_dir and os.path.exists(custom_dir):
                output_file = os.path.join(custom_dir, f"{base_name_only}.md")
            else:
                output_file = os.path.join(
                    os.path.dirname(source_path), f"{base_name_only}.md"
                )

            # Convert using tmdl_import
            from core.tmdl_import import convert_tmdl_or_bim
            content = convert_tmdl_or_bim(source_path)

            if content:
                # Add YAML front matter if enabled
                if add_front_matter_to_markdown and self.prefs.get(
                    "add_front_matter", False
                ):
                    content = add_front_matter_to_markdown(
                        content, filename=os.path.basename(source_path)
                    )

                # Apply export format conversion
                export_format = self.prefs.get("export_format", "markdown")
                if export_format == "confluence":
                    from core.confluence import full_convert
                    content = full_convert(content)
                elif export_format == "ado_wiki":
                    from core.ado_wiki import full_convert as ado_full_convert
                    content = ado_full_convert(content)

                # Check if preview mode
                if self.prefs.get("show_preview", True):
                    return True, (content, output_file), None
                else:
                    with open(output_file, "w", encoding="utf-8") as f:
                        f.write(content)
                    return True, output_file, None
            else:
                return (
                    False,
                    None,
                    {
                        "title": "Extraction Error",
                        "message": f"Failed to extract metadata from {os.path.basename(source_path)}",
                        "details": "No metadata content extracted.",
                    },
                )
        except Exception as e:
            logger.error(f"TMDL/BIM extraction failed: {e}")
            return (
                False,
                None,
                {
                    "title": "Extraction Error",
                    "message": f"Failed to extract metadata from {os.path.basename(source_path)}",
                    "details": str(e),
                },
            )

    def _on_tmdl_complete(self, result, source_path):
        """Callback when TMDL/BIM metadata extraction finishes."""
        success, output_data, error_info = result

        if success and isinstance(output_data, tuple):
            content, output_file_path = output_data
        else:
            content = None
            output_file_path = output_data

        # Stop progress
        self.progress.stop()
        self.progress.configure(mode="determinate")
        self.progress.pack_forget()

        # Re-enable inputs
        self.convert_btn.configure(state="normal")
        if hasattr(self, "options_btn"):
            self.options_btn.configure(state="normal")

        if success:
            if self.show_preview_var.get():
                _saved_content = [content]

                def _on_tmdl_preview_save(final_content: str):
                    try:
                        with open(output_file_path, "w", encoding="utf-8") as f:
                            f.write(final_content)
                        _saved_content[0] = final_content
                        self.status_var.set("Metadata Extraction Successful!")
                        self.prefs.add_recent_file(source_path, output_file_path)
                        self.refresh_recents()
                        show_success_dialog(
                            self.root,
                            self.colors,
                            output_file_path,
                            single_mode=True,
                            on_run_cmd=self._run_cmd,
                            icon_path=self.icon_path,
                        )
                    except Exception as e:
                        self.status_var.set("Save Failed.")
                        show_error_dialog(
                            self.root,
                            self.colors,
                            title="Save Error",
                            message="Failed to save file",
                            details=str(e),
                            icon_photo=self.icon_photo,
                        )

                user_approved = show_preview_dialog(
                    self.root,
                    self.colors,
                    source_path,
                    output_file_path,
                    content,
                    on_save=_on_tmdl_preview_save,
                    on_open_options=self.toggle_options,
                    icon_path=self.icon_path,
                    icon_photo=self.icon_photo,
                    code_theme_var=self.code_theme_var,
                    enable_linter_var=self.enable_linter_var,
                )

                if not user_approved:
                    self.status_var.set("Conversion cancelled.")
            else:
                self.status_var.set("Metadata Extraction Successful!")
                self.prefs.add_recent_file(source_path, output_file_path)
                self.refresh_recents()
                show_success_dialog(
                    self.root,
                    self.colors,
                    output_file_path,
                    single_mode=True,
                    on_run_cmd=self._run_cmd,
                    icon_path=self.icon_path,
                )
            if error_info:
                show_error_dialog(
                    self.root, self.colors, icon_photo=self.icon_photo, **error_info
                )

    def _process_pptx_async(self, source_path):
        """Handle single PowerPoint file conversion in a separate thread."""
        self.status_var.set(f"Converting PowerPoint: {os.path.basename(source_path)}...")

        # Indeterminate progress
        self.progress.pack(fill=tk.X, pady=(20, 0))
        self.progress.configure(mode="indeterminate")
        self.progress.start(10)
        self.root.update()

        # Disable inputs
        self.convert_btn.configure(state="disabled")
        if hasattr(self, "options_btn"):
            self.options_btn.configure(state="disabled")

        def run_thread():
            result = self._perform_pptx_conversion(source_path)
            self.root.after(0, lambda: self._on_pptx_complete(result, source_path))

        import threading

        t = threading.Thread(target=run_thread, daemon=True)
        t.start()

    def _perform_pptx_conversion(self, source_path):
        """Convert PowerPoint file to Markdown. Returns (success, output_path_or_content, error_dict)."""
        try:
            # Determine output path
            base_name_only = os.path.splitext(os.path.basename(source_path))[0]
            output_mode = self.prefs.get("output_mode", "same")
            custom_dir = self.prefs.get("custom_output_dir", "")

            if output_mode == "custom" and custom_dir and os.path.exists(custom_dir):
                output_file = os.path.join(custom_dir, f"{base_name_only}.md")
            else:
                output_file = os.path.join(
                    os.path.dirname(source_path), f"{base_name_only}.md"
                )

            # Convert using pptx_core
            from pptx_core import convert_pptx_to_markdown
            content = convert_pptx_to_markdown(source_path)

            if content:
                # Add YAML front matter if enabled
                if add_front_matter_to_markdown and self.prefs.get(
                    "add_front_matter", False
                ):
                    content = add_front_matter_to_markdown(
                        content, filename=os.path.basename(source_path)
                    )

                # Apply export format conversion
                export_format = self.prefs.get("export_format", "markdown")
                if export_format == "confluence":
                    from core.confluence import full_convert
                    content = full_convert(content)
                elif export_format == "ado_wiki":
                    from core.ado_wiki import full_convert as ado_full_convert
                    content = ado_full_convert(content)

                # Check if preview mode
                if self.prefs.get("show_preview", True):
                    return True, (content, output_file), None
                else:
                    with open(output_file, "w", encoding="utf-8") as f:
                        f.write(content)
                    return True, output_file, None
            else:
                return (
                    False,
                    None,
                    {
                        "title": "Conversion Error",
                        "message": f"Failed to convert {os.path.basename(source_path)}",
                        "details": "No content was generated.",
                    },
                )
        except Exception as e:
            logger.error(f"PowerPoint conversion failed: {e}")
            return (
                False,
                None,
                {
                    "title": "Conversion Error",
                    "message": f"Failed to convert {os.path.basename(source_path)}",
                    "details": str(e),
                },
            )

    def _on_pptx_complete(self, result, source_path):
        """Callback when PowerPoint conversion finishes."""
        success, output_data, error_info = result

        if success and isinstance(output_data, tuple):
            content, output_file_path = output_data
        else:
            content = None
            output_file_path = output_data

        # Stop progress
        self.progress.stop()
        self.progress.configure(mode="determinate")
        self.progress.pack_forget()

        # Re-enable inputs
        self.convert_btn.configure(state="normal")
        if hasattr(self, "options_btn"):
            self.options_btn.configure(state="normal")

        if success:
            if self.show_preview_var.get():
                _saved_content = [content]

                def _on_pptx_preview_save(final_content: str):
                    try:
                        with open(output_file_path, "w", encoding="utf-8") as f:
                            f.write(final_content)
                        _saved_content[0] = final_content
                        self.status_var.set("Conversion Successful!")
                        self.prefs.add_recent_file(source_path, output_file_path)
                        self.refresh_recents()
                        show_success_dialog(
                            self.root,
                            self.colors,
                            output_file_path,
                            single_mode=True,
                            on_run_cmd=self._run_cmd,
                            icon_path=self.icon_path,
                        )
                    except Exception as e:
                        self.status_var.set("Save Failed.")
                        show_error_dialog(
                            self.root,
                            self.colors,
                            title="Save Error",
                            message="Failed to save file",
                            details=str(e),
                            icon_photo=self.icon_photo,
                        )

                user_approved = show_preview_dialog(
                    self.root,
                    self.colors,
                    source_path,
                    output_file_path,
                    content,
                    on_save=_on_pptx_preview_save,
                    on_open_options=self.toggle_options,
                    icon_path=self.icon_path,
                    icon_photo=self.icon_photo,
                    code_theme_var=self.code_theme_var,
                    enable_linter_var=self.enable_linter_var,
                )

                if not user_approved:
                    self.status_var.set("Conversion cancelled.")
            else:
                self.status_var.set("Conversion Successful!")
                self.prefs.add_recent_file(source_path, output_file_path)
                self.refresh_recents()
                show_success_dialog(
                    self.root,
                    self.colors,
                    output_file_path,
                    single_mode=True,
                    on_run_cmd=self._run_cmd,
                    icon_path=self.icon_path,
                )
        else:
            if error_info:
                show_error_dialog(
                    self.root, self.colors, icon_photo=self.icon_photo, **error_info
                )

    def _perform_xlsx_conversion(self, source_path):
        """Convert Excel file to Markdown. Returns (success, output_path_or_content, error_dict)."""
        try:
            # Determine output path
            base_name_only = os.path.splitext(os.path.basename(source_path))[0]
            output_mode = self.prefs.get("output_mode", "same")
            custom_dir = self.prefs.get("custom_output_dir", "")

            if output_mode == "custom" and custom_dir and os.path.exists(custom_dir):
                output_file = os.path.join(custom_dir, f"{base_name_only}.md")
            else:
                output_file = os.path.join(
                    os.path.dirname(source_path), f"{base_name_only}.md"
                )

            # Convert using xlsx_core
            content = get_xlsx_content(source_path)

            if content:
                # Add mermaid.live links to any mermaid code blocks
                if add_mermaid_links_to_markdown:
                    content = add_mermaid_links_to_markdown(content)

                # Add YAML front matter for static site generators
                if add_front_matter_to_markdown and self.prefs.get(
                    "add_front_matter", False
                ):
                    content = add_front_matter_to_markdown(
                        content, filename=os.path.basename(source_path)
                    )

                # Check if preview mode
                if self.prefs.get("show_preview", True):
                    return True, (content, output_file), None
                else:
                    with open(output_file, "w", encoding="utf-8") as f:
                        f.write(content)
                    return True, output_file, None
            else:
                return (
                    False,
                    None,
                    {
                        "title": "Conversion Error",
                        "message": f"Failed to convert {os.path.basename(source_path)}",
                        "details": "No content extracted (spreadsheet might be empty).",
                    },
                )
        except Exception as e:
            # Use structured error classification
            error_info = classify_xlsx_error(e, source_path)
            return (False, None, error_info)

    def _on_xlsx_complete(self, result, source_path):
        """Callback when Excel file conversion finishes."""
        success, output_data, error_info = result

        # Handle preview mode tuple: (content, output_file_path)
        # vs non-preview mode: just output_file_path
        if success and isinstance(output_data, tuple):
            content, output_file_path = output_data
        else:
            content = None
            output_file_path = output_data

        # Stop progress
        self.progress.stop()
        self.progress.configure(mode="determinate")
        self.progress.pack_forget()

        # Re-enable inputs
        self.convert_btn.configure(state="normal")
        if hasattr(self, "options_btn"):
            self.options_btn.configure(state="normal")

        if success:
            if self.show_preview_var.get():
                # on_save receives the (possibly edited) content from the preview dialog
                _saved_content = [content]  # mutable container for closure

                def _on_xlsx_preview_save(final_content: str):
                    try:
                        with open(output_file_path, "w", encoding="utf-8") as f:
                            f.write(final_content)
                        _saved_content[0] = final_content
                        self.status_var.set("Excel Conversion Successful!")
                        self.prefs.add_recent_file(source_path, output_file_path)
                        self.refresh_recents()
                        show_success_dialog(
                            self.root,
                            self.colors,
                            output_file_path,
                            single_mode=True,
                            on_run_cmd=self._run_cmd,
                            icon_path=self.icon_path,
                        )
                    except Exception as e:
                        self.status_var.set("Save Failed.")
                        show_error_dialog(
                            self.root,
                            self.colors,
                            title="Save Error",
                            message="Failed to save file",
                            details=str(e),
                            icon_photo=self.icon_photo,
                        )

                user_approved = show_preview_dialog(
                    self.root,
                    self.colors,
                    source_path,
                    output_file_path,
                    content,
                    on_save=_on_xlsx_preview_save,
                    on_open_options=self.toggle_options,
                    icon_path=self.icon_path,
                    icon_photo=self.icon_photo,
                    code_theme_var=self.code_theme_var,
                    enable_linter_var=self.enable_linter_var,
                )

                if not user_approved:
                    self.status_var.set("Conversion cancelled.")
            else:
                self.status_var.set("Excel Conversion Successful!")
                self.prefs.add_recent_file(source_path, output_file_path)
                self.refresh_recents()
                show_success_dialog(
                    self.root,
                    self.colors,
                    output_file_path,
                    single_mode=True,
                    on_run_cmd=self._run_cmd,
                    icon_path=self.icon_path,
                )
        else:
            if error_info:
                show_error_dialog(
                    self.root, self.colors, icon_photo=self.icon_photo, **error_info
                )

    def _on_single_complete(self, result, source_path):
        """Callback when single file async conversion finishes."""
        success, output_file, error_info = result

        # Stop progress
        self.progress.stop()
        self.progress.configure(mode="determinate")  # Reset mode
        self.progress.pack_forget()

        # Re-enable inputs
        self.convert_btn.configure(state="normal")
        if hasattr(self, "options_btn"):
            self.options_btn.configure(state="normal")

        if success:
            # Check if preview is enabled
            if self.show_preview_var.get():
                # output_file is (content, path) tuple in preview mode
                content, output_file_path = output_file

                # on_save receives the (possibly edited) content from the preview dialog
                def _on_docx_preview_save(final_content: str):
                    try:
                        with open(output_file_path, "w", encoding="utf-8") as f:
                            f.write(final_content)
                        self.status_var.set("Conversion Successful!")
                        self.prefs.add_recent_file(source_path, output_file_path)
                        self.refresh_recents()
                        show_success_dialog(
                            self.root,
                            self.colors,
                            output_file_path,
                            single_mode=True,
                            on_run_cmd=self._run_cmd,
                            icon_path=self.icon_path,
                        )
                    except Exception as e:
                        self.status_var.set("Save Failed.")
                        show_error_dialog(
                            self.root,
                            self.colors,
                            title="Save Error",
                            message="Failed to save file",
                            details=str(e),
                            icon_photo=self.icon_photo,
                        )

                user_approved = show_preview_dialog(
                    self.root,
                    self.colors,
                    source_path,
                    output_file_path,
                    content,
                    on_save=_on_docx_preview_save,
                    on_open_options=self.toggle_options,
                    icon_path=self.icon_path,
                    icon_photo=self.icon_photo,
                    code_theme_var=self.code_theme_var,
                    enable_linter_var=self.enable_linter_var,
                )

                if not user_approved:
                    self.status_var.set("Conversion cancelled.")
            else:
                # No preview - file already written
                self.status_var.set("Conversion Successful!")
                self.prefs.add_recent_file(source_path, output_file)
                self.refresh_recents()
                show_success_dialog(
                    self.root,
                    self.colors,
                    output_file,
                    single_mode=True,
                    on_run_cmd=self._run_cmd,
                    icon_path=self.icon_path,
                )
        else:
            self.status_var.set("Conversion Failed.")
            if error_info:
                show_error_dialog(
                    self.root, self.colors, icon_photo=self.icon_photo, **error_info
                )

    def _perform_conversion(self, source_path):
        """Core conversion logic, returns (success, output_path, error_dict). Safe for threads."""
        try:
            # Determine output paths
            base_name_only = os.path.splitext(os.path.basename(source_path))[0]
            output_mode = self.prefs.get("output_mode", "same")
            custom_dir = self.prefs.get("custom_output_dir", "")

            if output_mode == "custom" and custom_dir and os.path.exists(custom_dir):
                output_file = os.path.join(custom_dir, f"{base_name_only}.md")
            else:
                output_file = os.path.join(
                    os.path.dirname(source_path), f"{base_name_only}.md"
                )

            temp_file = os.path.join(
                os.path.dirname(source_path),
                f"temp_{int(time.time())}_{base_name_only}.docx",
            )

            # Copy and convert
            shutil.copy(source_path, temp_file)
            try:
                # Progress callback
                def progress_cb(msg):
                    if hasattr(self, "status_var"):
                        self.status_var.set(
                            f"Converting {os.path.basename(source_path)}: {msg}"
                        )
                        # In async mode, update call isn't needed for var, but harmless

                markdown_lines = get_docx_content(
                    temp_file,
                    format_dax_code=self.prefs.get("format_dax", False),
                    format_pq_code=self.prefs.get("format_pq", False),
                    extract_images=self.prefs.get("extract_images", False),
                    progress_callback=progress_cb,
                )
            finally:
                if os.path.exists(temp_file):
                    try:
                        os.remove(temp_file)
                    except Exception:
                        pass  # nosec

            if markdown_lines:
                content = "\n\n".join(markdown_lines)

                # Add mermaid.live links to any mermaid code blocks
                if add_mermaid_links_to_markdown:
                    content = add_mermaid_links_to_markdown(content)

                # Add YAML front matter for static site generators
                if add_front_matter_to_markdown and self.prefs.get(
                    "add_front_matter", False
                ):
                    content = add_front_matter_to_markdown(
                        content, filename=os.path.basename(source_path)
                    )

                # Add Table of Contents if enabled
                if insert_toc and self.prefs.get("add_toc", False):
                    content = insert_toc(content, position="after_title", max_depth=3)

                # Apply export format conversion
                export_format = self.prefs.get("export_format", "markdown")
                if export_format == "confluence":
                    from core.confluence import full_convert
                    content = full_convert(content)
                elif export_format == "ado_wiki":
                    from core.ado_wiki import full_convert as ado_full_convert
                    content = ado_full_convert(content)

                # Check if preview mode - return content without writing
                if self.prefs.get("show_preview", True):
                    return True, (content, output_file), None
                else:
                    # Write directly
                    with open(output_file, "w", encoding="utf-8") as f:
                        f.write(content)
                    return True, output_file, None
            else:
                logger.error(f"No content extracted from {source_path}")
                return (
                    False,
                    None,
                    {
                        "title": "Conversion Error",
                        "message": f"Failed to convert {os.path.basename(source_path)}",
                        "details": "No content extracted (file might be empty or protected).",
                    },
                )

        except Exception as e:
            # Use structured error classification for better user feedback
            error_info = classify_docx_error(e, source_path)
            return (False, None, error_info)

    def convert_single_file(self, source_path):
        # Wrapper for synchronous batch mode
        success, _, error_info = self._perform_conversion(source_path)
        if not success and error_info:
            show_error_dialog(
                self.root, self.colors, icon_photo=self.icon_photo, **error_info
            )
        return success

    def _run_cmd(self, cmd):
        # Use Popen with DETACHED_PROCESS to fully separate subprocess lifecycle
        try:
            subprocess.Popen(  # nosec B602 B603 - Safe: user-initiated command execution, detached process
                cmd,
                shell=True,
                creationflags=subprocess.DETACHED_PROCESS
                | subprocess.CREATE_NEW_PROCESS_GROUP,
            )
        except Exception as e:
            messagebox.showerror("Error", f"Failed to open application:\n{str(e)}")


def main() -> None:
    try:
        root = tk.Tk()

        # CRITICAL: Withdraw window BEFORE it becomes visible to Windows
        # This allows us to set the icon before the taskbar entry is created
        root.withdraw()

        # Set icon immediately after Tk() but before window is shown
        # This is crucial for Windows taskbar icon to work correctly
        try:
            icon_path = resource_path("resources/markify_icon.ico")
            if os.path.exists(icon_path):
                root.iconbitmap(default=icon_path)
                root.wm_iconbitmap(icon_path)
        except Exception:  # nosec B110
            pass  # Icon loading failure is non-critical

        # Now create the app (which will configure the window)
        _app = ConverterApp(root)  # noqa: F841

        # Show the window now that icon is properly set
        root.deiconify()
        root.lift()
        root.focus_force()

        root.mainloop()
    except Exception:  # nosec B110
        # Catch-all for init errors
        error_msg = traceback.format_exc()
        # Create a simple root to show error if main root failed
        try:
            err_root = tk.Tk()
            err_root.withdraw()
            messagebox.showerror("Critical Error", f"Failed to start:\n{error_msg}")
            err_root.destroy()
        except Exception:  # nosec B110
            logger.error(error_msg)


if __name__ == "__main__":
    main()
