"""
Word to Markdown Converter - GUI
Double-click this file or run it to open the application.
"""
from __future__ import annotations

import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import os
import sys
import subprocess  # nosec B404
import shutil
import time
import traceback

from logging_config import setup_logging, get_logger

# Set Windows AppUserModelID so taskbar shows our icon, not Python's
# This must be done before any tkinter windows are created
try:
    import ctypes
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("com.markify.converter")
except Exception:
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
        # In dev mode, we are now in src/, so we might need to look up one level
        # if the resource is in the root (like README.md)
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    path = os.path.join(base_path, relative_path)
    if not os.path.exists(path):
        # Try parent directory (for README in root while script is in src)
        parent_path = os.path.join(os.path.dirname(base_path), relative_path)
        if os.path.exists(parent_path):
            return parent_path
            
    return path

# Import conversion logic from markify_core
script_dir = os.path.dirname(os.path.abspath(__file__))
# Note: we need to ensure we can find markify_core whether frozen or not
sys.path.insert(0, resource_path(".")) 
from markify_core import get_docx_content # noqa: E402
from xlsx_core import get_xlsx_content, get_xlsx_sheet_names # noqa: E402
from markify_prefs import Preferences # noqa: E402

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
try:

    import win_dnd  # noqa: E402
except ImportError:
    win_dnd = None  # Should not happen in dev, but safety for build

from themes import get_theme, get_theme_names, get_default_theme
from ui.components.markdown_viewer import MarkdownViewer
from ui.dialogs.success import show_success_dialog
from ui.dialogs.error import show_error_dialog
from ui.dialogs.options import OptionsDialog
from ui.dialogs.preview import show_preview_dialog
from ui.dialogs.shortcuts_dialog import show_shortcuts_dialog
from ui.clipboard_mode import show_clipboard_mode
from ui.dialogs.watch import show_watch_mode
from ui.dialogs.diff_viewer import show_diff_viewer
from ui.styles import configure_styles, update_widget_tree

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
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            icon_path = os.path.join(os.path.dirname(script_dir), "resources", "markify_icon.ico")
            
            if os.path.exists(icon_path):
                self.root.iconbitmap(icon_path)
        except Exception:  # nosec B110
            pass  # Fallback to default if something fails

        # Keyboard Bindings
        self.root.bind("<F1>", lambda e: self.open_shortcuts())
        self.root.bind("<Control-Shift-slash>", lambda e: self.open_shortcuts())
        self.root.bind("<Control-o>", lambda e: self.select_file())
        
        # Style Configuration
        self._configure_styles()
        
        c = self.colors # Shorthand
        
        # Main Layout
        self.main_frame = ttk.Frame(root, padding="40")
        self.main_frame.pack(fill=tk.BOTH, expand=True)

        # Title
        title_label = ttk.Label(self.main_frame, text="Markify", style="Title.TLabel")
        title_label.pack(pady=(0, 10))
        
        # Subtitle/Version
        ver_label = ttk.Label(self.main_frame, text="v1.0 • steve.wolfe@kcc.com", style="Sub.TLabel")
        ver_label.pack(pady=(0, 5))
        
        # GitHub Link
        github_link = tk.Label(
            self.main_frame,
            text="github.com/swolfe2/code-examples",
            bg=self.colors["bg"],
            fg=self.colors["accent"],
            font=("Segoe UI", 9, "underline"),
            cursor="hand2"
        )
        github_link.pack(pady=(0, 20))
        github_link.bind("<Button-1>", lambda e: subprocess.Popen(['start', 'https://github.com/swolfe2/code-examples'], shell=True)) # nosec B602 B607

        # === ACTION ROW: Main Button (left) + Options/Help (right) ===
        action_row = tk.Frame(self.main_frame, bg=c["bg"])
        action_row.pack(fill=tk.X, pady=(0, 10))
        action_row.columnconfigure(0, weight=1)  # Main button expands
        action_row.columnconfigure(1, weight=0)  # Buttons fixed width
        action_row.rowconfigure(0, weight=1)
        
        # Main Convert Button (left, takes most space)
        self.convert_btn = tk.Button(
            action_row,
            text="📂  SELECT FILE TO CONVERT",
            font=("Segoe UI", 12, "bold"),
            bg=self.colors["accent"],
            fg=self.colors.get("accent_fg", "#ffffff"),
            activebackground=self.colors["accent_hover"],
            activeforeground=self.colors.get("accent_fg", "#ffffff"),
            relief=tk.FLAT,
            cursor="hand2",
            command=self.select_file,
            pady=10
        )
        self.convert_btn.grid(row=0, column=0, sticky="nsew", padx=(0, 10))
        
        # Buttons Frame (right side, stacked vertically using grid for equal sizing)
        btn_frame = tk.Frame(action_row, bg=c["bg"])
        btn_frame.grid(row=0, column=1, sticky="nsew")
        btn_frame.rowconfigure(0, weight=1)
        btn_frame.rowconfigure(1, weight=1)
        btn_frame.columnconfigure(0, weight=1)
        
        self.options_btn = tk.Button(
            btn_frame,
            text="⚙️ Options",
            font=("Segoe UI", 9),
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            cursor="hand2",
            command=self.toggle_options,
            width=10
        )
        self.options_btn.grid(row=0, column=0, sticky="nsew", pady=(0, 5))
        
        self.help_btn = tk.Button(
            btn_frame,
            text="❓ Help",
            font=("Segoe UI", 9),
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            cursor="hand2",
            command=self.open_help,
            width=10
        )
        self.help_btn.grid(row=1, column=0, sticky="nsew", pady=(5, 0))
        
        # Drag-drop hint
        hint_label = ttk.Label(
            self.main_frame, 
            text="or drag a .docx / .xlsx file onto this window",
            style="Sub.TLabel"
        )
        hint_label.pack(pady=(0, 10))
        
        # === OR SEPARATOR ===
        or_frame = tk.Frame(self.main_frame, bg=c["bg"])
        or_frame.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Separator(or_frame, orient='horizontal').pack(side=tk.LEFT, fill=tk.X, expand=True)
        tk.Label(or_frame, text=" OR ", bg=c["bg"], fg=c.get("fg_secondary", c["fg"]),
                 font=("Segoe UI", 9)).pack(side=tk.LEFT, padx=10)
        ttk.Separator(or_frame, orient='horizontal').pack(side=tk.LEFT, fill=tk.X, expand=True)
        
        # === MODE BUTTONS (GRID LAYOUT - SCALABLE) ===
        mode_frame = tk.Frame(self.main_frame, bg=c["bg"])
        mode_frame.pack(fill=tk.X, padx=40, pady=(0, 15))
        mode_frame.columnconfigure(0, weight=1)
        mode_frame.columnconfigure(1, weight=1)
        mode_frame.rowconfigure(0, weight=1)
        mode_frame.rowconfigure(1, weight=1)
        
        # Row 0, Col 0: Clipboard Mode
        clipboard_container = tk.Frame(mode_frame, bg=c["bg"])
        clipboard_container.grid(row=0, column=0, sticky="nsew", padx=(0, 5), pady=(0, 10))
        
        self.clipboard_btn = tk.Button(
            clipboard_container,
            text="📋 CLIPBOARD",
            font=("Segoe UI", 10, "bold"),
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            cursor="hand2",
            command=self.open_clipboard_mode,
            pady=8
        )
        self.clipboard_btn.pack(fill=tk.X)
        
        tk.Label(
            clipboard_container, text="Paste text → Markdown",
            bg=c["bg"], fg=c.get("fg_secondary", c["fg"]),
            font=("Segoe UI", 8)
        ).pack(pady=(3, 0))
        
        # Row 0, Col 1: Watch Mode
        watch_container = tk.Frame(mode_frame, bg=c["bg"])
        watch_container.grid(row=0, column=1, sticky="nsew", padx=(5, 0), pady=(0, 10))
        
        self.watch_btn = tk.Button(
            watch_container,
            text="👁 WATCH MODE",
            font=("Segoe UI", 10, "bold"),
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            cursor="hand2",
            command=self.open_watch_mode,
            pady=8
        )
        self.watch_btn.pack(fill=tk.X)
        
        tk.Label(
            watch_container, text="Auto-convert folder",
            bg=c["bg"], fg=c.get("fg_secondary", c["fg"]),
            font=("Segoe UI", 8)
        ).pack(pady=(3, 0))
        
        # Row 1, Col 0: MD → DOCX
        reverse_container = tk.Frame(mode_frame, bg=c["bg"])
        reverse_container.grid(row=1, column=0, sticky="nsew", padx=(0, 5))
        
        self.reverse_btn = tk.Button(
            reverse_container,
            text="📝 MD → DOCX",
            font=("Segoe UI", 10, "bold"),
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            cursor="hand2",
            command=self.convert_md_to_docx,
            pady=8
        )
        self.reverse_btn.pack(fill=tk.X)
        
        tk.Label(
            reverse_container, text="Markdown → Word",
            bg=c["bg"], fg=c.get("fg_secondary", c["fg"]),
            font=("Segoe UI", 8)
        ).pack(pady=(3, 0))
        
        # Row 1, Col 1: Diff View
        diff_container = tk.Frame(mode_frame, bg=c["bg"])
        diff_container.grid(row=1, column=1, sticky="nsew", padx=(5, 0))
        
        self.diff_btn = tk.Button(
            diff_container,
            text="🔍 DIFF VIEW",
            font=("Segoe UI", 10, "bold"),
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            cursor="hand2",
            command=self.open_diff_viewer,
            pady=8
        )
        self.diff_btn.pack(fill=tk.X)
        
        tk.Label(
            diff_container, text="Compare files",
            bg=c["bg"], fg=c.get("fg_secondary", c["fg"]),
            font=("Segoe UI", 8)
        ).pack(pady=(3, 0))
        
        # === RECENT FILES SECTION ===
        self.recent_frame = tk.Frame(self.main_frame, bg=c["bg"])
        self.recent_frame.pack(fill=tk.X, pady=(0, 10))
        self.refresh_recents()

        # === SLIDING OPTIONS PANEL (Hidden by default) ===
        self.options_visible = False
        
        # Initialize preference variables
        self.format_dax_var = tk.BooleanVar(value=self.prefs.get("format_dax", False))
        self.format_dax_var.trace_add('write', self.on_pref_change)
        
        self.format_pq_var = tk.BooleanVar(value=self.prefs.get("format_pq", False))
        self.format_pq_var.trace_add('write', self.on_pref_change)
        
        self.extract_images_var = tk.BooleanVar(value=self.prefs.get("extract_images", False))
        self.extract_images_var.trace_add('write', self.on_pref_change)
        
        self.output_mode_var = tk.StringVar(value=self.prefs.get("output_mode", "same"))
        self.output_mode_var.trace_add('write', self.on_output_mode_change)
        
        self.custom_path_var = tk.StringVar(value=self.prefs.get("custom_output_dir", ""))
        
        self.theme_var = tk.StringVar(value=self.prefs.get("theme", get_default_theme()))
        self.theme_var.trace_add('write', self.on_theme_change)
        
        self.show_preview_var = tk.BooleanVar(value=self.prefs.get("show_preview", True))
        self.show_preview_var.trace_add('write', self.on_pref_change)
        
        self.add_front_matter_var = tk.BooleanVar(value=self.prefs.get("add_front_matter", False))
        self.add_front_matter_var.trace_add('write', self.on_pref_change)
        
        self.add_toc_var = tk.BooleanVar(value=self.prefs.get("add_toc", False))
        self.add_toc_var.trace_add('write', self.on_pref_change)
        
        # Options dialog will be created on-demand
        self.options_dialog = None
        
        # Initial state update for entry/button (they'll be created in the dialog)
        # We'll update state when dialog opens
        

        
        # Progress Bar (Hidden by default)
        self.progress = ttk.Progressbar(self.main_frame, orient=tk.HORIZONTAL, length=100, mode='determinate')
        
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
            pady=5
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

    def refresh_recents(self):
        """Refresh the Recent Files list UI as a table."""
        from datetime import datetime
        
        # Clear existing
        try:
            for widget in self.recent_frame.winfo_children():
                widget.destroy()
        except AttributeError:
            return 

        recents = self.prefs.get("recent_files", [])
        if not recents:
            return
        
        # Handle old format (list of strings) - skip
        if recents and isinstance(recents[0], str):
            return
            
        c = self.colors
        
        # Filter to valid entries with existing files
        valid_recents = []
        for r in recents:
            if isinstance(r, dict) and r.get("source") and os.path.exists(r.get("source", "")):
                valid_recents.append(r)
        
        if not valid_recents:
            return

        # Header
        tk.Label(self.recent_frame, text="Recent Conversions:", bg=c["bg"], fg=c["muted"], 
                 font=("Segoe UI", 9, "bold")).pack(anchor=tk.W, pady=(0, 5))
        
        # Table frame
        table = tk.Frame(self.recent_frame, bg=c["bg"])
        table.pack(fill=tk.X)
        
        # Column headers
        tk.Label(table, text="Date", bg=c["bg"], fg=c["muted"], font=("Segoe UI", 8), width=10, anchor=tk.W).grid(row=0, column=0, sticky="w")
        tk.Label(table, text="Source", bg=c["bg"], fg=c["muted"], font=("Segoe UI", 8), anchor=tk.W).grid(row=0, column=1, sticky="w", padx=(5, 0))
        tk.Label(table, text="Output", bg=c["bg"], fg=c["muted"], font=("Segoe UI", 8), anchor=tk.W).grid(row=0, column=2, sticky="w", padx=(5, 0))
        
        for i, entry in enumerate(valid_recents[:5], start=1):
            # Parse date
            try:
                dt = datetime.fromisoformat(entry.get("timestamp", ""))
                date_str = dt.strftime("%m/%d/%Y")
            except:
                date_str = "Unknown"
            
            source_path = entry.get("source", "")
            output_path = entry.get("output", "")
            
            # Date label
            tk.Label(table, text=date_str, bg=c["bg"], fg=c["fg"], font=("Segoe UI", 8), anchor=tk.W).grid(row=i, column=0, sticky="w")
            
            # Source link (opens folder in explorer)
            source_name = os.path.basename(source_path)[:40] + "..." if len(os.path.basename(source_path)) > 40 else os.path.basename(source_path)
            src_lbl = tk.Label(table, text=source_name, bg=c["bg"], fg=c["accent"], 
                              cursor="hand2", font=("Segoe UI", 8, "underline"), anchor=tk.W)
            src_lbl.grid(row=i, column=1, sticky="w", padx=(5, 0))
            src_folder = os.path.dirname(source_path)
            src_lbl.bind("<Button-1>", lambda e, f=src_folder: subprocess.Popen(['explorer', f]))  # nosec B602 B607
            
            # Output link (opens folder in explorer)
            if output_path and os.path.exists(output_path):
                out_name = os.path.basename(output_path)[:40] + "..." if len(os.path.basename(output_path)) > 40 else os.path.basename(output_path)
                out_lbl = tk.Label(table, text=out_name, bg=c["bg"], fg=c["accent"], 
                                  cursor="hand2", font=("Segoe UI", 8, "underline"), anchor=tk.W)
                out_lbl.grid(row=i, column=2, sticky="w", padx=(5, 0))
                out_folder = os.path.dirname(output_path)
                out_lbl.bind("<Button-1>", lambda e, f=out_folder: subprocess.Popen(['explorer', f]))  # nosec B602 B607
            else:
                tk.Label(table, text="-", bg=c["bg"], fg=c["muted"], font=("Segoe UI", 8), anchor=tk.W).grid(row=i, column=2, sticky="w", padx=(5, 0))

    def on_pref_change(self, *args):
        """Save preferences when variables change."""
        self.prefs.set("format_dax", self.format_dax_var.get())
        self.prefs.set("format_pq", self.format_pq_var.get())
        self.prefs.set("extract_images", self.extract_images_var.get())
        self.prefs.set("show_preview", self.show_preview_var.get())
        self.prefs.set("add_front_matter", self.add_front_matter_var.get())
        self.prefs.set("add_toc", self.add_toc_var.get())

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
            "on_browse": self.browse_output_folder,
        }
        self.options_dialog = OptionsDialog(self.root, self.colors, config)

    def on_output_mode_change(self, *args):
        mode = self.output_mode_var.get()
        self.prefs.set("output_mode", mode)
        self.update_custom_ui_state()

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
        if not hasattr(self, 'entry_custom') or self.entry_custom is None:
            return
        if not self.entry_custom.winfo_exists():
            return
            
        mode = self.output_mode_var.get()
        if mode == 'custom':
            self.entry_custom.configure(state='normal')
            self.btn_browse_out.configure(state='normal')
        else:
            self.entry_custom.configure(state='disabled')
            self.btn_browse_out.configure(state='disabled')

    def browse_output_folder(self):
        folder_selected = filedialog.askdirectory(initialdir=self.custom_path_var.get())
        if folder_selected:
            self.custom_path_var.set(folder_selected)
            self.prefs.set("custom_output_dir", folder_selected)

    def on_drop_files(self, file_paths):
        """Handle files and folders dropped onto the window"""
        valid_extensions = ('.docx', '.xlsx')
        
        # Use folder scanner if available (handles both files and folders)
        if expand_paths:
            valid_files = expand_paths(file_paths)
        else:
            # Fallback: only accept individual files (no folder support)
            valid_files = [f for f in file_paths if os.path.isfile(f) and f.lower().endswith(valid_extensions)]
        
        if not valid_files:
            # Check if user dropped folders but no files were found
            dropped_folders = [p for p in file_paths if os.path.isdir(p)]
            if dropped_folders:
                messagebox.showinfo("No Files Found", 
                    f"No .docx or .xlsx files found in the dropped folder(s).")
            else:
                messagebox.showwarning("Invalid File", "Please drop .docx or .xlsx files only.")
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

    def open_help(self):
        readme_path = resource_path("README.md")
        if os.path.exists(readme_path):
            MarkdownViewer(self.root, readme_path, self.colors)
        else:
            messagebox.showwarning("Help", f"README.md not found at {readme_path}")
    
    def open_shortcuts(self):
        """Open the Keyboard Shortcuts dialog."""
        show_shortcuts_dialog(self.root, self.colors)
    
    def open_clipboard_mode(self):
        """Open the Clipboard Mode dialog."""
        show_clipboard_mode(self.root, self.colors, self.prefs, on_close=self.refresh_recents)
    
    def open_watch_mode(self):
        """Open the Watch Mode dialog."""
        from ui.dialogs.watch import WatchModeDialog
        WatchModeDialog(
            self.root, self.colors, self.prefs,
            on_close=self.refresh_recents
        )
    
    def convert_md_to_docx(self):
        """Open file dialog to select MD file and convert to DOCX."""
        if not convert_md_file:
            messagebox.showwarning("Not Available", 
                "MD to DOCX conversion is not available.")
            return
        
        # File dialog
        initial_dir = self.prefs.get("last_directory", "")
        file_path = filedialog.askopenfilename(
            title="Select Markdown File",
            initialdir=initial_dir if initial_dir else None,
            filetypes=[("Markdown Files", "*.md"), ("All Files", "*.*")]
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
                on_close=self.refresh_recents
            )
        else:
            self.status_var.set("Conversion failed")
            messagebox.showerror("Conversion Error", result)
    
    def open_diff_viewer(self):
        """Open the Diff View dialog to compare two files."""
        show_diff_viewer(self.root, self.colors)

    def select_file(self):
        initial_dir = self.prefs.get("last_directory", "")
        if not os.path.exists(initial_dir):
            initial_dir = "/"
            
        file_paths = filedialog.askopenfilenames(
            title="Select Documents",
            initialdir=initial_dir,
            filetypes=[
                ("Supported Files", "*.docx *.xlsx"),
                ("Word Documents", "*.docx"),
                ("Excel Spreadsheets", "*.xlsx"),
                ("All Files", "*.*")
            ]
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
            if source_path.lower().endswith('.xlsx'):
                self._process_xlsx_async(source_path)
            else:
                self._process_single_async(source_path)
            return

        success_count = 0
        last_output_file = None
        
        # Setup Progress Bar
        self.progress.pack(fill=tk.X, pady=(20, 0))
        self.progress['maximum'] = total
        self.progress['value'] = 0
        self.root.update()
        
        for i, source_path in enumerate(source_paths, 1):
            self.status_var.set(f"Converting ({i}/{total}): {os.path.basename(source_path)}...")
            self.root.update()
            
            # Route to appropriate converter based on file type
            if source_path.lower().endswith('.xlsx'):
                success, output_file, _ = self._perform_xlsx_conversion(source_path)
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
                        with open(path, 'w', encoding='utf-8') as f:
                            f.write(content)
                        last_output_file = path
                        self.prefs.add_recent_file(source_path, path)
                    except Exception:
                        pass
                else:
                    last_output_file = output_file
                    self.prefs.add_recent_file(source_path, output_file)
            
            self.progress['value'] = i
            self.root.update()

        # Refresh recents UI
        self.refresh_recents()
        
        # Hide progress bar
        self.progress.pack_forget()

        file_word = "file" if total == 1 else "files"
        self.status_var.set(f"Completed: {success_count}/{total} {file_word} converted.")
        
        if success_count > 0:
            # Batch behavior: Show summary
            show_success_dialog(self.root, self.colors, os.path.dirname(source_paths[0]), single_mode=False, count=success_count, on_run_cmd=self._run_cmd)

    def _process_single_async(self, source_path):
        """Handle single file conversion in a separate thread."""
        self.status_var.set(f"Converting: {os.path.basename(source_path)}...")
        
        # Store source path for use in callback
        self._pending_source_path = source_path
        
        # Indeterminate progress
        self.progress.pack(fill=tk.X, pady=(20, 0))
        self.progress.configure(mode='indeterminate')
        self.progress.start(10)
        self.root.update()  # Force UI refresh to show progress bar
        
        # Disable inputs
        self.convert_btn.configure(state='disabled')
        if hasattr(self, 'options_btn'):
            self.options_btn.configure(state='disabled')
            
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
        self.progress.configure(mode='indeterminate')
        self.progress.start(10)
        self.root.update()
        
        # Disable inputs
        self.convert_btn.configure(state='disabled')
        if hasattr(self, 'options_btn'):
            self.options_btn.configure(state='disabled')
            
        def run_thread():
            result = self._perform_xlsx_conversion(source_path)
            self.root.after(0, lambda: self._on_xlsx_complete(result, source_path))
            
        import threading
        t = threading.Thread(target=run_thread, daemon=True)
        t.start()

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
                output_file = os.path.join(os.path.dirname(source_path), f"{base_name_only}.md")
            
            # Convert using xlsx_core
            content = get_xlsx_content(source_path)
            
            if content:
                # Add mermaid.live links to any mermaid code blocks
                if add_mermaid_links_to_markdown:
                    content = add_mermaid_links_to_markdown(content)
                
                # Add YAML front matter for static site generators
                if add_front_matter_to_markdown and self.prefs.get("add_front_matter", False):
                    content = add_front_matter_to_markdown(
                        content,
                        filename=os.path.basename(source_path)
                    )
                
                # Check if preview mode
                if self.prefs.get("show_preview", True):
                    return True, (content, output_file), None
                else:
                    with open(output_file, 'w', encoding='utf-8') as f:
                        f.write(content)
                    return True, output_file, None
            else:
                return False, None, {
                    "title": "Conversion Error",
                    "message": f"Failed to convert {os.path.basename(source_path)}",
                    "details": "No content extracted (spreadsheet might be empty)."
                }
        except Exception as e:
            error_msg = str(e)
            return False, None, {
                "title": "Excel Conversion Error",
                "message": f"Failed to convert {os.path.basename(source_path)}",
                "details": error_msg
            }

    def _on_xlsx_complete(self, result, source_path):
        """Callback when Excel file conversion finishes."""
        success, output_file, error_info = result
        
        # Stop progress
        self.progress.stop()
        self.progress.configure(mode='determinate')
        self.progress.pack_forget()
        
        # Re-enable inputs
        self.convert_btn.configure(state='normal')
        if hasattr(self, 'options_btn'):
            self.options_btn.configure(state='normal')
        
        if success:
            if self.show_preview_var.get():
                content, output_file_path = output_file
                
                user_approved = show_preview_dialog(
                    self.root, self.colors, source_path, output_file_path, content,
                    on_open_options=self.toggle_options
                )
                
                if user_approved:
                    try:
                        with open(output_file_path, 'w', encoding='utf-8') as f:
                            f.write(content)
                        self.status_var.set("Excel Conversion Successful!")
                        self.prefs.add_recent_file(source_path, output_file_path)
                        self.refresh_recents()
                        show_success_dialog(self.root, self.colors, output_file_path, single_mode=True, on_run_cmd=self._run_cmd)
                    except Exception as e:
                        self.status_var.set("Save Failed.")
                        show_error_dialog(self.root, self.colors, title="Save Error", message="Failed to save file", details=str(e))
                else:
                    self.status_var.set("Conversion cancelled.")
            else:
                self.status_var.set("Excel Conversion Successful!")
                self.prefs.add_recent_file(source_path, output_file)
                self.refresh_recents()
                show_success_dialog(self.root, self.colors, output_file, single_mode=True, on_run_cmd=self._run_cmd)
        else:
            self.status_var.set("Excel Conversion Failed.")
            if error_info:
                show_error_dialog(self.root, self.colors, **error_info)

    def _on_single_complete(self, result, source_path):
        """Callback when single file async conversion finishes."""
        success, output_file, error_info = result
        
        # Stop progress
        self.progress.stop()
        self.progress.configure(mode='determinate') # Reset mode
        self.progress.pack_forget()
        
        # Re-enable inputs
        self.convert_btn.configure(state='normal')
        if hasattr(self, 'options_btn'):
            self.options_btn.configure(state='normal')

        if success:
            # Check if preview is enabled
            if self.show_preview_var.get():
                # Show preview dialog with content
                content, output_file_path = output_file  # output_file is (content, path) tuple in preview mode
                
                user_approved = show_preview_dialog(
                    self.root, self.colors, source_path, output_file_path, content,
                    on_open_options=self.toggle_options
                )
                
                if user_approved:
                    # Write the file now
                    try:
                        with open(output_file_path, 'w', encoding='utf-8') as f:
                            f.write(content)
                        self.status_var.set("Conversion Successful!")
                        self.prefs.add_recent_file(source_path, output_file_path)
                        self.refresh_recents()
                        show_success_dialog(self.root, self.colors, output_file_path, single_mode=True, on_run_cmd=self._run_cmd)
                    except Exception as e:
                        self.status_var.set("Save Failed.")
                        show_error_dialog(self.root, self.colors, title="Save Error", message=f"Failed to save file", details=str(e))
                else:
                    self.status_var.set("Conversion cancelled.")
            else:
                # No preview - file already written
                self.status_var.set("Conversion Successful!")
                self.prefs.add_recent_file(source_path, output_file)
                self.refresh_recents()
                show_success_dialog(self.root, self.colors, output_file, single_mode=True, on_run_cmd=self._run_cmd)
        else:
            self.status_var.set("Conversion Failed.")
            if error_info:
                show_error_dialog(self.root, self.colors, **error_info)

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
                output_file = os.path.join(os.path.dirname(source_path), f"{base_name_only}.md")
                
            temp_file = os.path.join(os.path.dirname(source_path), f"temp_{int(time.time())}_{base_name_only}.docx")
            
            # Copy and convert
            shutil.copy(source_path, temp_file)
            try:
                # Progress callback
                def progress_cb(msg):
                    if hasattr(self, 'status_var'):
                        self.status_var.set(f"Converting {os.path.basename(source_path)}: {msg}")
                        # In async mode, update call isn't needed for var, but harmless
                
                markdown_lines = get_docx_content(
                    temp_file, 
                    format_dax_code=self.prefs.get("format_dax", False),
                    format_pq_code=self.prefs.get("format_pq", False),
                    extract_images=self.prefs.get("extract_images", False),
                    progress_callback=progress_cb
                )
            finally:
                if os.path.exists(temp_file):
                    try: os.remove(temp_file)
                    except: pass # nosec

            if markdown_lines:
                content = '\n\n'.join(markdown_lines)
                
                # Add mermaid.live links to any mermaid code blocks
                if add_mermaid_links_to_markdown:
                    content = add_mermaid_links_to_markdown(content)
                
                # Add YAML front matter for static site generators
                if add_front_matter_to_markdown and self.prefs.get("add_front_matter", False):
                    content = add_front_matter_to_markdown(
                        content,
                        filename=os.path.basename(source_path)
                    )
                
                # Add Table of Contents if enabled
                if insert_toc and self.prefs.get("add_toc", False):
                    content = insert_toc(content, position="after_title", max_depth=3)
                
                # Check if preview mode - return content without writing
                if self.prefs.get("show_preview", True):
                    return True, (content, output_file), None
                else:
                    # Write directly
                    with open(output_file, 'w', encoding='utf-8') as f:
                        f.write(content)
                    return True, output_file, None
            else:
                logger.error(f"No content extracted from {source_path}")
                return False, None, {
                    "title": "Conversion Error",
                    "message": f"Failed to convert {os.path.basename(source_path)}",
                    "details": "No content extracted (file might be empty or protected)."
                }

        except Exception as e:
            error_msg = str(e)
            if "Permission denied" in error_msg or "being used" in error_msg.lower():
                return False, None, {
                    "title": "File Access Error",
                    "message": "Cannot access the Word document.",
                    "details": f"📄 {os.path.basename(source_path)}",
                    "hint": "Please close the file in Word and try again."
                }
            else:
                return False, None, {
                    "title": "Conversion Error",
                    "message": f"Failed to convert {os.path.basename(source_path)}",
                    "details": error_msg
                }

    def convert_single_file(self, source_path):
        # Wrapper for synchronous batch mode
        success, _, error_info = self._perform_conversion(source_path)
        if not success and error_info:
            show_error_dialog(self.root, self.colors, **error_info)
        return success





    def _run_cmd(self, cmd):
        # Use Popen with DETACHED_PROCESS to fully separate subprocess lifecycle
        try:
            subprocess.Popen(cmd, shell=True, creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP) # nosec B602
        except Exception as e:
            messagebox.showerror("Error", f"Failed to open application:\n{str(e)}")



def main() -> None:
    try:
        root = tk.Tk()
        ConverterApp(root)
        root.mainloop()
    except Exception: # nosec B110
        # Catch-all for init errors
        error_msg = traceback.format_exc()
        # Create a simple root to show error if main root failed
        try:
            err_root = tk.Tk()
            err_root.withdraw()
            messagebox.showerror("Critical Error", f"Failed to start:\n{error_msg}")
            err_root.destroy()
        except Exception: # nosec B110
            logger.error(error_msg)

if __name__ == "__main__":
    main()
