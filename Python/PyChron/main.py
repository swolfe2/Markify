"""PyChron Application - Main Entry Point."""

import os
import sys
from datetime import datetime

# Add the script's directory to the path so imports work
_script_dir = os.path.dirname(os.path.abspath(__file__))
if _script_dir not in sys.path:
    sys.path.insert(0, _script_dir)

import customtkinter as ctk  # noqa: E402
from handlers import TaskHandlers  # noqa: E402
from storage import load_tasks, save_tasks  # noqa: E402
from ui import create_theme_toggle, export_dialog  # noqa: E402
from utils import format_timedelta  # noqa: E402

# Constants
ACTIONS_FRAME_INDEX = 4  # Index of actions frame in table row tuple


# --- Main Application ---
class PyChronApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("PyChron")
        self.geometry("800x700")
        # Ensure window is fully opaque (not transparent)
        try:
            self.attributes("-alpha", 1.0)
        except Exception:
            pass

        self.current_theme = "Dark"
        ctk.set_appearance_mode(self.current_theme)

        # Set window icon (try to use Tkinterviz icon or default)
        # Must be called after window is fully initialized
        self.after(100, self._set_window_icon)

        self.tasks = {}
        self.task_frames = {}

        self.tasks = load_tasks()

        # Initialize handlers
        self.handlers = TaskHandlers(self)

        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)

        input_frame = ctk.CTkFrame(self)
        input_frame.grid(row=0, column=0, padx=10, pady=10, sticky="ew")

        # Task entry - auto-scales to fill remaining space
        self.task_entry = ctk.CTkEntry(
            input_frame, placeholder_text="Enter new task name"
        )
        self.task_entry.pack(side="left", padx=(5, 0), pady=5, fill="x", expand=True)
        self.task_entry.bind("<Return>", self.handlers.add_task)

        # Add Task button - fixed size with padding
        self.add_button = ctk.CTkButton(
            input_frame, text="Add Task", command=self.handlers.add_task, width=100
        )
        self.add_button.pack(side="left", padx=(10, 10), pady=5)

        # Theme toggle - simple switch
        theme_switch_frame, theme_switch_var, theme_status_label = (
            create_theme_toggle(input_frame, self.current_theme, self._toggle_theme)
        )
        theme_switch_frame.pack(side="right", padx=(10, 5), pady=5)
        self.theme_switch_var = theme_switch_var
        self.theme_status_label = theme_status_label

        self.scrollable_frame = ctk.CTkScrollableFrame(self, label_text="Tasks")
        self.scrollable_frame.grid(row=1, column=0, padx=10, pady=10, sticky="nsew")
        self.scrollable_frame.grid_columnconfigure(0, weight=1)

        # Hook into scrollbar's set method to auto-hide when not needed
        # Delay setup to ensure scrollbar is created
        self.after(10, self._setup_auto_hide_scrollbar)

        actions_frame = ctk.CTkFrame(self)
        actions_frame.grid(row=2, column=0, padx=10, pady=10, sticky="ew")

        self.delete_all_button = ctk.CTkButton(
            actions_frame,
            text="Delete All",
            fg_color="#D32F2F",
            hover_color="#B71C1C",
            command=self.handlers.delete_all_tasks,
        )
        self.delete_all_button.pack(side="left", padx=5, pady=5)

        self.export_button = ctk.CTkButton(
            actions_frame,
            text="Export Completed...",
            command=lambda: export_dialog(self, self.handlers.perform_export),
        )
        self.export_button.pack(side="right", padx=5, pady=5)

        self._redraw_task_list()
        # apply theme colors to avoid pure-black backgrounds
        try:
            self._apply_theme_colors()
        except Exception:
            pass
        # enable/disable export depending on completed tasks
        try:
            self._update_export_button_state()
        except Exception:
            pass
        # Update scrollbar visibility after initial setup
        # Use multiple delays to ensure layout is fully complete
        self.after(50, self._update_scrollbar_visibility)
        self.after(200, self._update_scrollbar_visibility)
        self.after(500, self._update_scrollbar_visibility)
        self._update_timers()

        self.protocol("WM_DELETE_WINDOW", self._on_closing)

    def _toggle_theme(self):
        """Toggle between light and dark theme with smooth transition."""
        # Swap the appearance mode
        self.current_theme = "Light" if self.current_theme == "Dark" else "Dark"

        # Update switch state and status label immediately
        if hasattr(self, "theme_switch_var") and hasattr(
            self, "theme_status_label"
        ):
            switch_val = "on" if self.current_theme == "Light" else "off"
            self.theme_switch_var.set(switch_val)
            status_text = "Light" if self.current_theme == "Light" else "Dark"
            self.theme_status_label.configure(text=status_text)

        # Prepare all color updates
        container_bg = self._get_container_bg()
        text_color = "#000000" if self.current_theme == "Light" else "#FFFFFF"
        hdr_bg = "#E0E0E0" if self.current_theme == "Light" else "#3a3a3a"
        hdr_text_color = "#000000" if self.current_theme == "Light" else "#FFFFFF"

        # Disable window updates temporarily to prevent flicker
        try:
            self.update_idletasks()
        except Exception:
            pass

        # Update all colors FIRST - before appearance mode change
        try:
            self._apply_theme_colors()
        except Exception:
            pass

        # Update ALL frames with proper backgrounds BEFORE appearance change
        for task_name, task_data in self.task_frames.items():
            # Update main frame background
            frame = task_data.get("frame")
            if frame:
                try:
                    frame.configure(fg_color=container_bg)
                except Exception:
                    pass

            # Update timings_frame and table_frame backgrounds
            timings_frame = task_data.get("timings_frame")
            table_frame = task_data.get("table_frame")
            if timings_frame:
                timings_frame.configure(fg_color=container_bg)
            if table_frame:
                table_frame.configure(fg_color=container_bg)

            # Update header colors
            if table_frame:
                for widget in table_frame.winfo_children():
                    try:
                        info = widget.grid_info()
                    except Exception:
                        info = {}
                    if isinstance(widget, ctk.CTkLabel) and info.get("row") == 0:
                        widget.configure(fg_color=hdr_bg, text_color=hdr_text_color)

                # Update all table row labels with proper theme colors
                if table_frame:
                    for widget in table_frame.winfo_children():
                        try:
                            info = widget.grid_info()
                        except Exception:
                            info = {}
                        row_num = info.get("row", 0)
                        # Update data rows (row > 0) with proper background
                        if isinstance(widget, ctk.CTkLabel) and row_num > 0:
                            widget.configure(
                                fg_color=container_bg, text_color=text_color
                            )
                        # Update session frames and actions frames
                        elif isinstance(widget, ctk.CTkFrame) and row_num > 0:
                            widget.configure(fg_color=container_bg)
                            # Update children (pencil icon, note button, etc.)
                            for child in widget.winfo_children():
                                if isinstance(child, ctk.CTkButton):
                                    # Check if it's a pencil icon or note button
                                    child_text = child.cget("text")
                                    if child_text == "✏":
                                        # Pencil icon - update theme colors
                                        light_fg = "#E0E0E0"
                                        dark_fg = "#555555"
                                        light_hover = "#BDBDBD"
                                        dark_hover = "#777777"
                                        light_text = "#000000"
                                        dark_text = "#FFFFFF"
                                        child.configure(
                                            fg_color=(
                                                light_fg
                                                if self.current_theme == "Light"
                                                else dark_fg
                                            ),
                                            hover_color=(
                                                light_hover
                                                if self.current_theme == "Light"
                                                else dark_hover
                                            ),
                                            text_color=(
                                                light_text
                                                if self.current_theme == "Light"
                                                else dark_text
                                            ),
                                        )
                                    elif "Note" in child_text or "Add" in child_text:
                                        # Note button - keep yellow colors but
                                        # ensure frame background is correct
                                        pass
                                elif isinstance(child, ctk.CTkLabel):
                                    child.configure(
                                        fg_color=container_bg,
                                        text_color=text_color,
                                    )

        # Update input frame widgets manually to prevent rebuild
        try:
            for widget in self.winfo_children():
                if isinstance(widget, ctk.CTkFrame):
                    # Update input frame and its children
                    for child in widget.winfo_children():
                        if isinstance(child, ctk.CTkEntry):
                            # Entry colors are handled by appearance mode,
                            # but we can update other properties if needed
                            pass
                        elif isinstance(child, ctk.CTkButton):
                            # Button colors are handled by appearance mode,
                            # but we can update other properties if needed
                            pass
        except Exception:
            pass

        # Force all updates to complete before appearance mode change
        self.update_idletasks()

        # Update appearance mode - CustomTkinter will update default widget colors
        # We've already manually updated all our custom widgets above.
        #
        # NOTE: CustomTkinter's set_appearance_mode() internally rebuilds widgets,
        # which can cause the window to appear to close/reopen. This is a known
        # limitation of CustomTkinter. To completely avoid this, we would need to
        # manually update every single widget color without calling
        # set_appearance_mode(), which is complex and error-prone. The current
        # approach minimizes the visual disruption by updating all custom widgets
        # manually first.
        ctk.set_appearance_mode(self.current_theme)

        # Force update after appearance mode change
        self.update_idletasks()

    def _redraw_task_list(self):
        for widget in self.scrollable_frame.winfo_children():
            widget.destroy()
        self.task_frames = {}
        # Sort tasks to show "In Progress" first
        sorted_tasks = sorted(self.tasks.values(), key=lambda t: t.status)
        for task in sorted_tasks:
            self._add_task_to_ui(task)
        # Ensure export button state is kept up-to-date after redrawing
        try:
            self._update_export_button_state()
        except Exception:
            pass
        # Hide scrollbar if content doesn't fill the window
        self._update_scrollbar_visibility()

    def _setup_auto_hide_scrollbar(self):
        """Set up auto-hiding scrollbar by hooking into its set method."""
        try:
            # Access the internal scrollbar
            scrollbar = self.scrollable_frame._scrollbar
            if scrollbar:
                # Store the original set method and grid configuration
                original_set = scrollbar.set
                # Get and store the original grid configuration
                try:
                    grid_config = scrollbar.grid_info()
                except Exception:
                    grid_config = {}

                def auto_hide_set(first, last):
                    """Override set method to auto-hide scrollbar when not needed."""
                    # Call original set method first
                    original_set(first, last)

                    # Hide if content fits (first <= 0 and last >= 1 = no scrolling)
                    if float(first) <= 0.0 and float(last) >= 1.0:
                        try:
                            # Hide the scrollbar using grid_remove
                            scrollbar.grid_remove()
                        except Exception:
                            pass
                    else:
                        # Show the scrollbar when scrolling is needed
                        try:
                            # Restore the scrollbar with original grid configuration
                            if grid_config:
                                scrollbar.grid(**grid_config)
                            else:
                                # Fallback: just call grid() to restore
                                scrollbar.grid()
                        except Exception:
                            pass

                # Replace the set method
                scrollbar.set = auto_hide_set

                # Immediately trigger the check with current values
                try:
                    first, last = scrollbar.get()
                    scrollbar.set(first, last)
                except Exception:
                    pass
        except Exception:
            pass

    def _update_scrollbar_visibility(self):
        """Update scrollbar visibility based on content height."""
        try:
            # Update all idle tasks first
            self.update_idletasks()
            self.scrollable_frame.update_idletasks()

            # Force the scrollable frame to update its scroll region
            canvas = None
            bbox = None
            try:
                canvas = self.scrollable_frame._parent_canvas
                if canvas:
                    # Update scroll region to include all content
                    canvas.update_idletasks()
                    bbox = canvas.bbox("all")
                    if bbox:
                        # Update scroll region - this triggers scrollbar update
                        canvas.config(scrollregion=bbox)
                    canvas.update_idletasks()

                    # Get the yscrollcommand callback and call it to update scrollbar
                    yscrollcommand = canvas.cget("yscrollcommand")
                    if yscrollcommand and bbox:
                        try:
                            canvas_height = canvas.winfo_height()
                            content_height = bbox[3] - bbox[1]
                            if content_height > canvas_height:
                                # Content exceeds viewport - calculate scroll position
                                top = canvas.canvasy(0)
                                first = max(0.0, min(1.0, top / content_height))
                                last = max(
                                    0.0,
                                    min(1.0, (top + canvas_height) / content_height),
                                )
                                # Call the yscrollcommand to update scrollbar
                                # This will trigger our auto-hide logic
                                yscrollcommand(first, last)
                            else:
                                # Content fits - call with values that hide scrollbar
                                yscrollcommand(0.0, 1.0)
                        except Exception:
                            pass
            except Exception:
                pass

            # Also force a check by triggering the scrollbar's set method directly
            # This ensures our auto-hide logic runs
            scrollbar = self.scrollable_frame._scrollbar
            if scrollbar:
                try:
                    first, last = scrollbar.get()
                    scrollbar.set(first, last)
                except Exception:
                    pass
        except Exception:
            pass

    def _apply_theme_colors(self):
        """Apply a small set of container colors based on the active theme.

        This centralizes a few background/foreground choices so dynamic
        theme changes look consistent (avoids pure-black backgrounds).
        """
        if self.current_theme == "Light":
            main_bg = "#F5F5F5"
            container_bg = "#FFFFFF"
        else:
            main_bg = "#1f1f1f"
            container_bg = "#2b2b2b"

        try:
            self.configure(fg_color=main_bg)
        except Exception:
            pass

        try:
            self.scrollable_frame.configure(fg_color=container_bg)
        except Exception:
            pass

    def _get_container_bg(self):
        """Return a sensible container background color for the active theme."""
        return "#FFFFFF" if self.current_theme == "Light" else "#2b2b2b"

    def _update_export_button_state(self):
        """Enable/disable export button depending on whether completed tasks exist."""
        completed = any(t.status == "Completed" for t in self.tasks.values())
        try:
            self.export_button.configure(state=("normal" if completed else "disabled"))
        except Exception:
            pass

    def _add_task_to_ui(self, task):
        # Use theme-appropriate background for the main frame
        container_bg = self._get_container_bg()
        frame = ctk.CTkFrame(self.scrollable_frame, fg_color=container_bg)
        # add slightly larger bottom padding so frame's bottom border visible
        frame.pack(fill="x", padx=5, pady=(5, 8))
        frame.grid_columnconfigure(0, weight=1)

        header_frame = ctk.CTkFrame(frame)
        header_frame.grid(row=0, column=0, columnspan=2, sticky="ew", padx=5, pady=5)
        # layout: [edit icon] [task name (expand)] [note] [duration] [collapse]
        header_frame.grid_columnconfigure(0, weight=0)
        header_frame.grid_columnconfigure(1, weight=1)
        header_frame.grid_columnconfigure(2, weight=0)
        header_frame.grid_columnconfigure(3, weight=0)
        header_frame.grid_columnconfigure(4, weight=0)

        # make a clear small "Edit" button with blue background and white text
        edit_icon = ctk.CTkButton(
            header_frame,
            text="Edit",
            width=48,
            height=28,
            fg_color="#0066CC",
            hover_color="#004A99",
            border_width=0,
            corner_radius=6,
            command=lambda t=task: self.handlers.edit_task_name(t),  # noqa: E501
            text_color="#FFFFFF",
            font=ctk.CTkFont(size=10, weight="bold"),
        )
        edit_icon.grid(row=0, column=0, padx=(5, 8), pady=6, sticky="w")

        task_name_label = ctk.CTkLabel(
            header_frame,
            text=task.name,
            font=ctk.CTkFont(size=14, weight="bold"),
        )
        task_name_label.grid(row=0, column=1, padx=5, pady=5, sticky="w")

        # Task note button - muted yellow for both themes
        has_task_note = bool(task.note)
        task_note_btn = ctk.CTkButton(
            header_frame,
            text="Note" if has_task_note else "Add Note",
            width=100,
            height=28,
            fg_color="#F9A825" if has_task_note else "#F5F5DC",
            hover_color="#F57F17" if has_task_note else "#E8E8D3",
            text_color="#000000",
            command=lambda t=task: self.handlers.edit_task_note(t),
            font=ctk.CTkFont(size=10),
        )
        task_note_btn.grid(row=0, column=2, padx=(5, 10), pady=5, sticky="w")

        duration_label = ctk.CTkLabel(header_frame, text="Total: 0h 0m 0s")
        duration_label.grid(row=0, column=3, padx=10, pady=5, sticky="e")

        # collapse/expand timings table button with better contrast
        collapse_button = ctk.CTkButton(
            header_frame,
            text="▾",
            width=28,
            height=24,
            fg_color="#333333",
            hover_color="#555555",
            border_width=1,
            border_color="#888888",
            corner_radius=6,
            text_color="#FFFFFF",
            command=lambda t=task: self.handlers.toggle_collapse(t),
        )
        collapse_button.grid(row=0, column=4, padx=(6, 8), pady=6, sticky="e")

        button_frame = ctk.CTkFrame(frame)
        # give grey button strip more vertical padding to separate from buttons
        button_frame.grid(
            row=1,
            column=0,
            columnspan=2,
            sticky="ew",
            padx=5,
            pady=(6, 6),
        )

        pause_button = ctk.CTkButton(
            button_frame,
            text="Start",
            command=lambda t=task: self.handlers.toggle_pause_resume(t),
        )
        pause_button.pack(side="left", padx=5, pady=4)

        complete_button = ctk.CTkButton(
            button_frame,
            text="Complete Task",
            command=lambda t=task: self.handlers.toggle_complete(t),
        )
        complete_button.pack(side="left", padx=5, pady=4)

        # Copy Results button - to the right of Complete Task
        copy_button = ctk.CTkButton(
            button_frame,
            text="Copy Results",
            fg_color="#4CAF50",
            hover_color="#45a049",
            command=lambda t=task: self.handlers.copy_task_results(t),
        )
        copy_button.pack(side="left", padx=5, pady=4)

        # Delete Task button - far right
        delete_button = ctk.CTkButton(
            button_frame,
            text="Delete Task",
            fg_color="#D32F2F",
            hover_color="#B71C1C",
            command=lambda t_name=task.name: self.handlers.delete_task(  # noqa: E501
                t_name
            ),
        )
        delete_button.pack(side="right", padx=5, pady=4)

        # Use theme-appropriate background for timings_frame
        container_bg = self._get_container_bg()
        timings_frame = ctk.CTkFrame(frame, fg_color=container_bg)
        # add internal bottom padding so timings don't overlap parent border
        timings_frame.grid(
            row=2,
            column=0,
            columnspan=2,
            sticky="ew",
            padx=10,
            pady=(0, 6),
        )
        timings_frame.grid_columnconfigure(0, weight=1)

        # create a table_frame inside timings_frame and add header row
        # (Session | Start | End | Duration | Actions)
        table_frame = ctk.CTkFrame(timings_frame, fg_color=container_bg)
        table_frame.grid(row=0, column=0, sticky="nsew", padx=0, pady=0)
        # Ensure columns are evenly distributed across available width
        table_frame.grid_columnconfigure(0, weight=1, uniform="col")
        table_frame.grid_columnconfigure(1, weight=1, uniform="col")
        table_frame.grid_columnconfigure(2, weight=1, uniform="col")
        table_frame.grid_columnconfigure(3, weight=1, uniform="col")
        # Actions column (fixed width, wider than button)
        table_frame.grid_columnconfigure(4, weight=0, minsize=80)

        # header row with distinct styling (light backgrounds for contrast)
        hdr_font = ctk.CTkFont(size=10, weight="bold")
        # Use light backgrounds to stand out in both light and dark modes
        hdr_bg = "#E0E0E0" if self.current_theme == "Light" else "#3a3a3a"
        hdr_text_color = "#000000" if self.current_theme == "Light" else "#FFFFFF"
        hdr_session = ctk.CTkLabel(
            table_frame,
            text="Session",
            font=hdr_font,
            fg_color=hdr_bg,
            text_color=hdr_text_color,
        )
        hdr_start = ctk.CTkLabel(
            table_frame,
            text="Start",
            font=hdr_font,
            fg_color=hdr_bg,
            text_color=hdr_text_color,
        )
        hdr_end = ctk.CTkLabel(
            table_frame,
            text="End",
            font=hdr_font,
            fg_color=hdr_bg,
            text_color=hdr_text_color,
        )
        hdr_dur = ctk.CTkLabel(
            table_frame,
            text="Duration",
            font=hdr_font,
            fg_color=hdr_bg,
            text_color=hdr_text_color,
        )
        hdr_actions = ctk.CTkLabel(
            table_frame,
            text="Actions",
            font=hdr_font,
            fg_color=hdr_bg,
            text_color=hdr_text_color,
        )

        hdr_session.grid(row=0, column=0, sticky="ew", padx=6, pady=(4, 2))
        hdr_start.grid(row=0, column=1, sticky="ew", padx=6, pady=(4, 2))
        hdr_end.grid(row=0, column=2, sticky="ew", padx=6, pady=(4, 2))
        hdr_dur.grid(row=0, column=3, sticky="ew", padx=6, pady=(4, 2))
        hdr_actions.grid(row=0, column=4, sticky="ew", padx=6, pady=(4, 2))

        self.task_frames[task.name] = {
            "frame": frame,
            "name_label": task_name_label,
            "duration_label": duration_label,
            "pause_button": pause_button,
            "complete_button": complete_button,
            "edit_button": edit_icon,
            "delete_button": delete_button,
            "note_button": task_note_btn,
            "copy_button": copy_button,
            "timings_frame": timings_frame,
            "table_frame": table_frame,
            "table_rows": [],
            "current_row": None,
            "collapsed": False,
            "collapse_button": collapse_button,
        }
        self._update_task_ui(task)
        # Update scrollbar visibility after adding task
        self.after(10, self._update_scrollbar_visibility)

    def _update_timers(self):
        # Only update UI every second for tasks with active timers to avoid flicker
        for task in self.tasks.values():
            if task.timer_active:
                self._update_task_ui(task)
        self.after(1000, self._update_timers)

    def _update_task_ui(self, task):
        """Update the entire UI for a single task."""
        if task.name not in self.task_frames:
            return

        info = self.task_frames[task.name]

        # Update duration (compact format)
        duration = task.get_total_duration()
        duration_str = f"Total: {format_timedelta(duration)}"
        info["duration_label"].configure(text=duration_str)

        # Update pause/resume button text
        if task.timer_active:
            info["pause_button"].configure(text="Pause")
        else:
            info["pause_button"].configure(text="Resume" if task.timings else "Start")

        # Timings table: build/update grid-style table
        # (Session | Start | End | Duration)
        table_frame = info.get("table_frame")
        table_rows = info.get("table_rows", [])
        current_row = info.get("current_row")
        collapsed = info.get("collapsed", False)

        # show/hide table_frame based on collapsed state
        if table_frame:
            if collapsed:
                try:
                    table_frame.grid_remove()
                except Exception:
                    pass
            else:
                try:
                    table_frame.grid()
                except Exception:
                    pass

        # If there are no timings and not running, keep only header (no rows)
        if not task.timings and not task.timer_active:
            # destroy any existing data rows
            for row in table_rows:
                for cell in row:
                    try:
                        cell.destroy()
                    except Exception:
                        pass
            info["table_rows"] = []
            # remove current running row if present
            if current_row:
                for cell in current_row:
                    try:
                        cell.destroy()
                    except Exception:
                        pass
                info["current_row"] = None
        else:
            # rebuild rows if count mismatch
            if len(table_rows) != len(task.timings):
                # clear old rows
                for row in table_rows:
                    for cell in row:
                        try:
                            cell.destroy()
                        except Exception:
                            pass
                table_rows = []
                for i, entry in enumerate(task.timings):
                    start_dt = datetime.fromisoformat(entry["start"])
                    end_dt = datetime.fromisoformat(entry["end"])
                    start = start_dt.strftime("%H:%M:%S")
                    end = end_dt.strftime("%H:%M:%S")
                    dur_str = format_timedelta(end_dt - start_dt)
                    # Use theme-appropriate colors for table rows
                    container_bg = self._get_container_bg()
                    text_color = (
                        "#000000" if self.current_theme == "Light" else "#FFFFFF"
                    )
                    # Use custom session name if available
                    session_name = entry.get("name") or f"Session {i + 1}"
                    # Session name frame to hold pencil icon and name
                    session_frame = ctk.CTkFrame(table_frame, fg_color=container_bg)
                    # Pencil icon button for editing session name - more visible
                    light_fg = "#E0E0E0"
                    dark_fg = "#555555"
                    light_hover = "#BDBDBD"
                    dark_hover = "#777777"
                    light_text = "#000000"
                    dark_text = "#FFFFFF"
                    edit_icon_btn = ctk.CTkButton(
                        session_frame,
                        text="✏",
                        width=28,
                        height=22,
                        fg_color=(
                            light_fg
                            if self.current_theme == "Light"
                            else dark_fg
                        ),
                        hover_color=(
                            light_hover
                            if self.current_theme == "Light"
                            else dark_hover
                        ),
                        text_color=(
                            light_text
                            if self.current_theme == "Light"
                            else dark_text
                        ),
                        command=lambda t=task, idx=i: self.handlers.edit_session_name(
                            t, idx
                        ),
                        font=ctk.CTkFont(size=14, weight="bold"),
                    )
                    edit_icon_btn.pack(side="left", padx=(2, 4))
                    # Session name label
                    lbl_session = ctk.CTkLabel(
                        session_frame,
                        text=session_name,
                        fg_color=container_bg,
                        text_color=text_color,
                    )
                    lbl_session.pack(side="left", padx=0)
                    lbl_start = ctk.CTkLabel(
                        table_frame,
                        text=start,
                        fg_color=container_bg,
                        text_color=text_color,
                    )
                    lbl_end = ctk.CTkLabel(
                        table_frame,
                        text=end,
                        fg_color=container_bg,
                        text_color=text_color,
                    )
                    lbl_dur = ctk.CTkLabel(
                        table_frame,
                        text=dur_str,
                        fg_color=container_bg,
                        text_color=text_color,
                    )
                    # Action buttons frame - only note button now
                    actions_frame = ctk.CTkFrame(table_frame, fg_color=container_bg)
                    # Note button - muted yellow, narrower to fit header
                    has_note = bool(entry.get("note"))
                    note_btn = ctk.CTkButton(
                        actions_frame,
                        text="Note" if has_note else "Add Note",
                        width=70,
                        height=24,
                        fg_color="#F9A825" if has_note else "#F5F5DC",
                        hover_color="#F57F17" if has_note else "#E8E8D3",
                        text_color="#000000",
                        command=lambda t=task, idx=i: self.handlers.edit_session_note(
                            t, idx
                        ),
                        font=ctk.CTkFont(size=9),
                    )
                    note_btn.pack(side="left", padx=2)

                    session_frame.grid(row=i + 1, column=0, sticky="ew", padx=6, pady=2)
                    lbl_start.grid(row=i + 1, column=1, sticky="ew", padx=6, pady=2)
                    lbl_end.grid(row=i + 1, column=2, sticky="ew", padx=6, pady=2)
                    lbl_dur.grid(row=i + 1, column=3, sticky="ew", padx=6, pady=2)
                    actions_frame.grid(
                        row=i + 1, column=4, sticky="ew", padx=2, pady=2
                    )
                    table_rows.append(
                        [session_frame, lbl_start, lbl_end, lbl_dur, actions_frame]
                    )
                info["table_rows"] = table_rows
            else:
                # update existing rows texts
                for i, entry in enumerate(task.timings):
                    start_dt = datetime.fromisoformat(entry["start"])
                    end_dt = datetime.fromisoformat(entry["end"])
                    start = start_dt.strftime("%H:%M:%S")
                    end = end_dt.strftime("%H:%M:%S")
                    dur_str = format_timedelta(end_dt - start_dt)
                    row = table_rows[i]
                    try:
                        # Update colors when theme changes
                        container_bg = self._get_container_bg()
                        text_color = (
                            "#000000"
                            if self.current_theme == "Light"
                            else "#FFFFFF"
                        )
                        # Update session name in frame
                        if isinstance(row[0], ctk.CTkFrame):
                            session_frame = row[0]
                            # Update frame background
                            session_frame.configure(fg_color=container_bg)
                            # Update both the pencil icon button and label
                            for widget in session_frame.winfo_children():
                                if isinstance(widget, ctk.CTkLabel):
                                    session_name = (
                                        entry.get("name") or f"Session {i + 1}"
                                    )
                                    widget.configure(
                                        text=session_name,
                                        fg_color=container_bg,
                                        text_color=text_color,
                                    )
                                elif isinstance(widget, ctk.CTkButton):
                                    # Update pencil icon button colors for theme
                                    light_fg = "#E0E0E0"
                                    dark_fg = "#555555"
                                    light_hover = "#BDBDBD"
                                    dark_hover = "#777777"
                                    light_text = "#000000"
                                    dark_text = "#FFFFFF"
                                    widget.configure(
                                        fg_color=(
                                            light_fg
                                            if self.current_theme == "Light"
                                            else dark_fg
                                        ),
                                        hover_color=(
                                            light_hover
                                            if self.current_theme == "Light"
                                            else dark_hover
                                        ),
                                        text_color=(
                                            light_text
                                            if self.current_theme == "Light"
                                            else dark_text
                                        ),
                                    )
                        # Update action buttons if they exist
                        if (
                            len(row) > ACTIONS_FRAME_INDEX
                            and isinstance(row[ACTIONS_FRAME_INDEX], ctk.CTkFrame)
                        ):
                            actions_frame = row[ACTIONS_FRAME_INDEX]
                            # Update frame background
                            actions_frame.configure(fg_color=container_bg)
                            # Update note button
                            buttons = [
                                w
                                for w in actions_frame.winfo_children()
                                if isinstance(w, ctk.CTkButton)
                            ]
                            if len(buttons) >= 1:
                                note_btn = buttons[0]
                                has_note = bool(entry.get("note"))
                                note_btn.configure(
                                    text="Note" if has_note else "Add Note",
                                    fg_color="#F9A825" if has_note else "#F5F5DC",
                                    hover_color="#F57F17" if has_note else "#E8E8D3",
                                    text_color="#000000",
                                )
                        row[1].configure(
                            text=start,
                            fg_color=container_bg,
                            text_color=text_color,
                        )
                        row[2].configure(
                            text=end,
                            fg_color=container_bg,
                            text_color=text_color,
                        )
                        row[3].configure(
                            text=dur_str,
                            fg_color=container_bg,
                            text_color=text_color,
                        )
                    except Exception:
                        pass

            # handle running current session row (last)
            if task.timer_active and task.current_start_time:
                start = task.current_start_time.strftime("%H:%M:%S")
                running_str = format_timedelta(datetime.now() - task.current_start_time)
                # place at row index len(task.timings)+1
                r = len(task.timings) + 1
                if current_row:
                    try:
                        # Update colors when theme changes
                        container_bg = self._get_container_bg()
                        text_color = (
                            "#000000"
                            if self.current_theme == "Light"
                            else "#FFFFFF"
                        )
                        current_row[0].configure(
                            text=f"Session {r}",
                            fg_color=container_bg,
                            text_color=text_color,
                        )
                        current_row[1].configure(
                            text=start,
                            fg_color=container_bg,
                            text_color=text_color,
                        )
                        current_row[2].configure(
                            text="(running)",
                            fg_color=container_bg,
                            text_color=text_color,
                        )
                        current_row[3].configure(
                            text=running_str,
                            fg_color=container_bg,
                            text_color=text_color,
                        )
                    except Exception:
                        pass
                else:
                    # Use theme-appropriate colors for running row
                    container_bg = self._get_container_bg()
                    text_color = (
                        "#000000"
                        if self.current_theme == "Light"
                        else "#FFFFFF"
                    )
                    cr0 = ctk.CTkLabel(
                        table_frame,
                        text=f"Session {r}",
                        fg_color=container_bg,
                        text_color=text_color,
                    )
                    cr1 = ctk.CTkLabel(
                        table_frame,
                        text=start,
                        fg_color=container_bg,
                        text_color=text_color,
                    )
                    cr2 = ctk.CTkLabel(
                        table_frame,
                        text="(running)",
                        fg_color=container_bg,
                        text_color=text_color,
                    )
                    cr3 = ctk.CTkLabel(
                        table_frame,
                        text=running_str,
                        fg_color=container_bg,
                        text_color=text_color,
                    )
                    cr0.grid(row=r, column=0, sticky="ew", padx=6, pady=2)
                    cr1.grid(row=r, column=1, sticky="ew", padx=6, pady=2)
                    cr2.grid(row=r, column=2, sticky="ew", padx=6, pady=2)
                    cr3.grid(row=r, column=3, sticky="ew", padx=6, pady=2)
                    info["current_row"] = [cr0, cr1, cr2, cr3]
            else:
                if current_row:
                    for cell in current_row:
                        try:
                            cell.destroy()
                        except Exception:
                            pass
                    info["current_row"] = None

        # Visual marker and button states depending on completion
        if task.status == "Completed":
            # green border for completed
            try:
                fg = self._get_container_bg()
                info["frame"].configure(
                    border_width=2, border_color="#4CAF50", fg_color=fg
                )
                info["timings_frame"].configure(fg_color=fg)
            except Exception:
                # fallback if border properties not supported
                fg = self._get_container_bg()
                info["frame"].configure(fg_color=fg)
                info["timings_frame"].configure(fg_color=fg)

            info["pause_button"].configure(state="disabled", text="Completed")
            info["complete_button"].configure(state="normal", text="Undo Completion")
        else:
            # yellow border for active/non-complete
            try:
                fg = self._get_container_bg()
                info["frame"].configure(
                    border_width=2, border_color="#FFB300", fg_color=fg
                )
                info["timings_frame"].configure(fg_color=fg)
            except Exception:
                info["frame"].configure(fg_color=fg)
                info["timings_frame"].configure(fg_color=fg)

            # ensure buttons are enabled
            info["pause_button"].configure(state="normal")
            info["complete_button"].configure(state="normal", text="Complete Task")

        # Update task note button indicator
        if "note_button" in info:
            has_note = bool(task.note)
            # Only update text_color if we need to change it
            config_dict = {
                "text": "Note" if has_note else "Add Note",
                "fg_color": "#F9A825" if has_note else "#F5F5DC",
                "hover_color": "#F57F17" if has_note else "#E8E8D3",
                "text_color": "#000000",
            }
            info["note_button"].configure(**config_dict)

        # Update scrollbar visibility after UI changes (new rows, etc.)
        self.after(10, self._update_scrollbar_visibility)

    def _set_window_icon(self):
        """Set the window icon to match Tkinterviz or use a default."""
        try:
            # Set AppUserModelID for Windows taskbar icon association
            try:
                import ctypes

                # Use a unique ID for this application
                app_id = "com.pychron.app.1.0"
                ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(
                    app_id
                )
            except Exception:
                pass

            # Try to find icon in common locations
            icon_paths = [
                os.path.join(_script_dir, "icon.ico"),
                os.path.join(_script_dir, "app.ico"),
                os.path.join(os.path.dirname(_script_dir), "icon.ico"),
                os.path.join(os.path.dirname(_script_dir), "app.ico"),
            ]

            # Also try to find it in a parent directory (if Tkinterviz is nearby)
            parent_dir = os.path.dirname(os.path.dirname(_script_dir))
            icon_paths.extend(
                [
                    os.path.join(parent_dir, "icon.ico"),
                    os.path.join(parent_dir, "app.ico"),
                ]
            )

            # Try iconbitmap first (works for .ico files)
            for icon_path in icon_paths:
                if os.path.exists(icon_path):
                    try:
                        self.iconbitmap(icon_path)
                        # Icon successfully set, exit
                        return
                    except Exception:
                        # Try iconphoto as fallback
                        try:
                            from tkinter import PhotoImage

                            # For PNG files, use iconphoto
                            if icon_path.lower().endswith((".png", ".gif")):
                                img = PhotoImage(file=icon_path)
                                self.iconphoto(False, img)
                                return
                        except Exception:
                            continue

            # If no icon found, the default Python icon will be used
            # User can add icon.ico or app.ico to the PyChron directory
        except Exception:
            # If icon setting fails, continue without icon
            pass

    def _on_closing(self):
        save_tasks(self.tasks)
        self.destroy()


if __name__ == "__main__":
    app = PyChronApp()
    app.mainloop()
