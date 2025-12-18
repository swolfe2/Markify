"""
Watch Mode dialog for Markify.
Control panel for folder monitoring and auto-conversion.
"""
from __future__ import annotations

import tkinter as tk
from tkinter import ttk, filedialog
import os
from datetime import datetime
from typing import Dict, Optional, Callable

from logging_config import get_logger

logger = get_logger("watch_dialog")


class WatchModeDialog:
    """
    Watch Mode control panel dialog.
    
    Provides UI for:
    - Folder selection
    - Start/Stop/Pause controls
    - Activity log
    - Statistics
    """
    
    def __init__(
        self, 
        parent: tk.Tk, 
        colors: Dict[str, str],
        prefs: Optional[object] = None,
        on_close: Optional[Callable[[], None]] = None,
        icon_path: str = None
    ):
        """
        Initialize the Watch Mode dialog.
        
        Args:
            parent: Parent Tk window
            colors: Theme color dictionary
            prefs: Preferences object for persistence
            on_close: Callback when dialog is closed
            icon_path: Path to application icon
        """
        self.parent = parent
        self.colors = colors
        self.prefs = prefs
        self.on_close = on_close
        
        # Watcher instance
        self.watcher = None
        
        # Build dialog
        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Watch Mode")
        self.dialog.geometry("500x450")
        self.dialog.configure(bg=colors["bg"])
        self.dialog.transient(parent)
        
        # Set icon if provided
        if icon_path:
            try:
                self.dialog.iconbitmap(icon_path)
            except Exception:
                pass
        
        # Center on parent
        self.dialog.update_idletasks()
        x = parent.winfo_x() + (parent.winfo_width() - 500) // 2
        y = parent.winfo_y() + (parent.winfo_height() - 450) // 2
        self.dialog.geometry(f"+{x}+{y}")
        
        # Handle close
        self.dialog.protocol("WM_DELETE_WINDOW", self._on_close)
        
        self._build_ui()
    
    def _build_ui(self) -> None:
        """Build the dialog UI."""
        c = self.colors
        
        # Main container with padding
        main_frame = tk.Frame(self.dialog, bg=c["bg"], padx=20, pady=15)
        main_frame.pack(fill=tk.BOTH, expand=True)
        
        # === TITLE ===
        tk.Label(
            main_frame,
            text="📂 Watch Mode",
            bg=c["bg"],
            fg=c["fg"],
            font=("Segoe UI", 14, "bold")
        ).pack(anchor=tk.W, pady=(0, 10))
        
        tk.Label(
            main_frame,
            text="Monitor a folder and auto-convert new files to Markdown",
            bg=c["bg"],
            fg=c.get("muted", c["fg"]),
            font=("Segoe UI", 9)
        ).pack(anchor=tk.W, pady=(0, 15))
        
        # === FOLDER SELECTION ===
        folder_frame = tk.Frame(main_frame, bg=c["bg"])
        folder_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(
            folder_frame,
            text="Watch Folder:",
            bg=c["bg"],
            fg=c["fg"],
            font=("Segoe UI", 9)
        ).pack(anchor=tk.W)
        
        path_row = tk.Frame(folder_frame, bg=c["bg"])
        path_row.pack(fill=tk.X, pady=(3, 0))
        
        # Get saved watch path from prefs
        initial_path = ""
        if self.prefs:
            initial_path = self.prefs.get("watch_folder", "")
        
        self.watch_path_var = tk.StringVar(value=initial_path)
        self.path_entry = tk.Entry(
            path_row,
            textvariable=self.watch_path_var,
            bg=c["secondary_bg"],
            fg=c["fg"],
            insertbackground=c["fg"],
            relief=tk.FLAT,
            font=("Segoe UI", 9)
        )
        self.path_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 5))
        
        browse_btn = tk.Button(
            path_row,
            text="📁 Browse",
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            font=("Segoe UI", 9),
            cursor="hand2",
            command=self._browse_folder
        )
        browse_btn.pack(side=tk.RIGHT)
        
        # === OUTPUT OPTIONS ===
        output_frame = tk.Frame(main_frame, bg=c["bg"])
        output_frame.pack(fill=tk.X, pady=(0, 10))
        
        self.output_mode_var = tk.StringVar(value="same")
        if self.prefs:
            self.output_mode_var.set(self.prefs.get("watch_output_mode", "same"))
        
        tk.Radiobutton(
            output_frame,
            text="Save output alongside source files",
            variable=self.output_mode_var,
            value="same",
            bg=c["bg"],
            fg=c["fg"],
            selectcolor=c["secondary_bg"],
            activebackground=c["bg"],
            activeforeground=c["fg"],
            font=("Segoe UI", 9),
            command=self._update_custom_folder_display
        ).pack(anchor=tk.W)
        
        # Custom folder radio with clickable Options link
        custom_row = tk.Frame(output_frame, bg=c["bg"])
        custom_row.pack(anchor=tk.W, fill=tk.X)
        
        tk.Radiobutton(
            custom_row,
            text="Save to custom folder (set in ",
            variable=self.output_mode_var,
            value="custom",
            bg=c["bg"],
            fg=c["fg"],
            selectcolor=c["secondary_bg"],
            activebackground=c["bg"],
            activeforeground=c["fg"],
            font=("Segoe UI", 9),
            command=self._update_custom_folder_display
        ).pack(side=tk.LEFT)
        
        # Clickable "Options" link
        options_link = tk.Label(
            custom_row,
            text="Options",
            bg=c["bg"],
            fg=c.get("accent", "#0066cc"),
            font=("Segoe UI", 9, "underline"),
            cursor="hand2"
        )
        options_link.pack(side=tk.LEFT)
        options_link.bind("<Button-1>", self._open_options)
        
        tk.Label(
            custom_row,
            text=")",
            bg=c["bg"],
            fg=c["fg"],
            font=("Segoe UI", 9)
        ).pack(side=tk.LEFT)
        
        # Display current custom folder path
        self.custom_folder_label = tk.Label(
            output_frame,
            text="",
            bg=c["bg"],
            fg=c.get("muted", c["fg"]),
            font=("Segoe UI", 8),
            wraplength=420,
            justify=tk.LEFT
        )
        self.custom_folder_label.pack(anchor=tk.W, padx=(20, 0), pady=(2, 0))
        self._update_custom_folder_display()
        
        # === CONTROL BUTTONS ===
        btn_frame = tk.Frame(main_frame, bg=c["bg"])
        btn_frame.pack(fill=tk.X, pady=(0, 10))
        
        self.start_btn = tk.Button(
            btn_frame,
            text="▶ Start Watching",
            bg=c["accent"],
            fg=c.get("accent_fg", "#ffffff"),
            activebackground=c["accent_hover"],
            activeforeground=c.get("accent_fg", "#ffffff"),
            relief=tk.FLAT,
            font=("Segoe UI", 10, "bold"),
            cursor="hand2",
            command=self._start_watching,
            width=15
        )
        self.start_btn.pack(side=tk.LEFT, padx=(0, 5))
        
        self.stop_btn = tk.Button(
            btn_frame,
            text="■ Stop",
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            font=("Segoe UI", 10),
            cursor="hand2",
            command=self._stop_watching,
            width=10,
            state=tk.DISABLED
        )
        self.stop_btn.pack(side=tk.LEFT, padx=(0, 5))
        
        self.pause_btn = tk.Button(
            btn_frame,
            text="⏸ Pause",
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            font=("Segoe UI", 10),
            cursor="hand2",
            command=self._toggle_pause,
            width=10,
            state=tk.DISABLED
        )
        self.pause_btn.pack(side=tk.LEFT)
        
        # === STATUS ===
        status_frame = tk.Frame(main_frame, bg=c["secondary_bg"], padx=10, pady=8)
        status_frame.pack(fill=tk.X, pady=(0, 10))
        
        self.status_label = tk.Label(
            status_frame,
            text="⚪ Stopped",
            bg=c["secondary_bg"],
            fg=c["fg"],
            font=("Segoe UI", 10, "bold")
        )
        self.status_label.pack(side=tk.LEFT)
        
        self.stats_label = tk.Label(
            status_frame,
            text="",
            bg=c["secondary_bg"],
            fg=c.get("muted", c["fg"]),
            font=("Segoe UI", 9)
        )
        self.stats_label.pack(side=tk.RIGHT)
        
        # === ACTIVITY LOG ===
        tk.Label(
            main_frame,
            text="Activity Log:",
            bg=c["bg"],
            fg=c["fg"],
            font=("Segoe UI", 9, "bold")
        ).pack(anchor=tk.W, pady=(5, 3))
        
        log_frame = tk.Frame(main_frame, bg=c["secondary_bg"])
        log_frame.pack(fill=tk.BOTH, expand=True)
        
        self.log_text = tk.Text(
            log_frame,
            bg=c["secondary_bg"],
            fg=c["fg"],
            insertbackground=c["fg"],
            relief=tk.FLAT,
            font=("Consolas", 9),
            height=10,
            state=tk.DISABLED,
            wrap=tk.WORD
        )
        self.log_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        scrollbar = ttk.Scrollbar(log_frame, orient=tk.VERTICAL, command=self.log_text.yview)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.log_text.configure(yscrollcommand=scrollbar.set)
        
        # === CLOSE BUTTON ===
        close_btn = tk.Button(
            main_frame,
            text="Close",
            bg=c["secondary_bg"],
            fg=c["fg"],
            activebackground=c["border"],
            activeforeground=c["fg"],
            relief=tk.FLAT,
            font=("Segoe UI", 9),
            cursor="hand2",
            command=self._on_close,
            width=10
        )
        close_btn.pack(side=tk.RIGHT, pady=(10, 0))
    
    def _browse_folder(self) -> None:
        """Open folder selection dialog."""
        initial = self.watch_path_var.get()
        if not os.path.isdir(initial):
            initial = os.path.expanduser("~")
        
        folder = filedialog.askdirectory(
            title="Select Folder to Watch",
            initialdir=initial
        )
        
        if folder:
            self.watch_path_var.set(folder)
            if self.prefs:
                self.prefs.set("watch_folder", folder)
    
    def _update_custom_folder_display(self) -> None:
        """Update the custom folder path display."""
        if not hasattr(self, 'custom_folder_label'):
            return
        
        custom_dir = ""
        if self.prefs:
            custom_dir = self.prefs.get("custom_output_dir", "")
        
        if self.output_mode_var.get() == "custom":
            if custom_dir and os.path.isdir(custom_dir):
                self.custom_folder_label.configure(text=f"📁 {custom_dir}")
            else:
                self.custom_folder_label.configure(text="⚠️ No custom folder set - click Options to configure")
        else:
            self.custom_folder_label.configure(text="")
    
    def _open_options(self, event=None) -> None:
        """Open the Options dialog."""
        from ui.dialogs.options import OptionsDialog
        
        def on_options_close():
            # Refresh the custom folder display after Options closes
            self._update_custom_folder_display()
        
        OptionsDialog(
            self.parent,
            self.colors,
            {
                "format_dax": self.prefs.get("format_dax", False) if self.prefs else False,
                "format_pq": self.prefs.get("format_pq", False) if self.prefs else False,
                "extract_images": self.prefs.get("extract_images", False) if self.prefs else False,
                "output_mode": self.prefs.get("output_mode", "same") if self.prefs else "same",
                "custom_output_dir": self.prefs.get("custom_output_dir", "") if self.prefs else "",
            },
            on_close=on_options_close
        )
    
    def _log(self, message: str) -> None:
        """Add a timestamped message to the activity log."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        full_message = f"[{timestamp}] {message}\n"
        
        self.log_text.configure(state=tk.NORMAL)
        self.log_text.insert(tk.END, full_message)
        self.log_text.see(tk.END)
        self.log_text.configure(state=tk.DISABLED)
    
    def _update_status(self, status: str, color: str = None) -> None:
        """Update the status label."""
        self.status_label.configure(text=status)
        
    def _update_stats(self) -> None:
        """Update the statistics display."""
        if self.watcher:
            converted, failed = self.watcher.get_stats()
            self.stats_label.configure(text=f"{converted} converted, {failed} failed")
    
    def _start_watching(self) -> None:
        """Start the folder watcher."""
        from watch_mode import FolderWatcher
        
        watch_path = self.watch_path_var.get()
        
        if not watch_path or not os.path.isdir(watch_path):
            self._log("❌ Please select a valid folder to watch")
            return
        
        # Determine output path
        output_path = None
        if self.output_mode_var.get() == "custom" and self.prefs:
            custom_dir = self.prefs.get("custom_output_dir", "")
            if custom_dir and os.path.isdir(custom_dir):
                output_path = custom_dir
        
        # Create watcher with callbacks
        self.watcher = FolderWatcher(
            watch_path=watch_path,
            output_path=output_path,
            interval=2.0,
            watch_modified=True,
            on_file_found=lambda f: self.dialog.after(0, lambda: self._log(f"📄 Found: {os.path.basename(f)}")),
            on_convert_start=lambda f: self.dialog.after(0, lambda: self._log(f"⏳ Converting: {os.path.basename(f)}")),
            on_convert_complete=lambda f, o, s: self.dialog.after(0, lambda: self._on_convert_done(f, o, s)),
            on_error=lambda f, e: self.dialog.after(0, lambda: self._log(f"❌ Error: {e}"))
        )
        
        try:
            self.watcher.start()
            
            self._log(f"▶ Started watching: {watch_path}")
            self._update_status("🟢 Watching...")
            
            # Update button states
            self.start_btn.configure(state=tk.DISABLED)
            self.stop_btn.configure(state=tk.NORMAL)
            self.pause_btn.configure(state=tk.NORMAL)
            self.path_entry.configure(state=tk.DISABLED)
            
            # Save preference
            if self.prefs:
                self.prefs.set("watch_folder", watch_path)
                self.prefs.set("watch_output_mode", self.output_mode_var.get())
                
        except Exception as e:
            self._log(f"❌ Failed to start: {e}")
    
    def _stop_watching(self) -> None:
        """Stop the folder watcher."""
        if self.watcher:
            self.watcher.stop()
            self.watcher = None
        
        self._log("■ Stopped watching")
        self._update_status("⚪ Stopped")
        
        # Update button states
        self.start_btn.configure(state=tk.NORMAL)
        self.stop_btn.configure(state=tk.DISABLED)
        self.pause_btn.configure(state=tk.DISABLED, text="⏸ Pause")
        self.path_entry.configure(state=tk.NORMAL)
    
    def _toggle_pause(self) -> None:
        """Toggle pause/resume state."""
        if not self.watcher:
            return
        
        if self.watcher.is_paused:
            self.watcher.resume()
            self._log("▶ Resumed")
            self._update_status("🟢 Watching...")
            self.pause_btn.configure(text="⏸ Pause")
        else:
            self.watcher.pause()
            self._log("⏸ Paused")
            self._update_status("🟡 Paused")
            self.pause_btn.configure(text="▶ Resume")
    
    def _on_convert_done(self, filepath: str, output_path: str, success: bool) -> None:
        """Handle conversion completion."""
        filename = os.path.basename(filepath)
        if success:
            self._log(f"✅ Converted: {filename}")
            # Add to recent files so it shows in main app
            if self.prefs and output_path:
                self.prefs.add_recent_file(filepath, output_path)
        else:
            self._log(f"❌ Failed: {filename}")
        self._update_stats()
    
    def _on_close(self) -> None:
        """Handle dialog close."""
        # Stop watcher if running
        if self.watcher:
            self.watcher.stop()
            self.watcher = None
        
        if self.on_close:
            self.on_close()
        
        self.dialog.destroy()


def show_watch_mode(
    parent: tk.Tk, 
    colors: Dict[str, str],
    prefs: Optional[object] = None
) -> WatchModeDialog:
    """
    Show the Watch Mode dialog.
    
    Args:
        parent: Parent Tk window
        colors: Theme color dictionary
        prefs: Optional preferences object
        
    Returns:
        WatchModeDialog instance
    """
    return WatchModeDialog(parent, colors, prefs)
