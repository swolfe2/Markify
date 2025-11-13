import csv
import json
import os
import tkinter as tk
from datetime import datetime, timedelta
from tkinter import filedialog, messagebox

import customtkinter as ctk

# --- Constants ---
DATA_FILE = "tasks.json"
CSV_FILE = "task_times.csv"
DESKTOP_PATH = os.path.join(os.path.expanduser("~"), "Desktop")


# --- Data Models ---
class Task:
    """Represents a single task with its timing records."""

    def __init__(self, name, timings=None, status="In Progress"):
        self.name = name
        self.timings = timings if timings else []  # List of {'start': str, 'end': str}
        self.status = status
        self.timer_active = False
        self.current_start_time = None

    def start_pause_timer(self):
        """Toggles the timer on and off (starts, pauses, resumes)."""
        if self.timer_active:  # Pause the timer
            self.timings.append(
                {
                    "start": self.current_start_time.isoformat(),
                    "end": datetime.now().isoformat(),
                }
            )
            self.timer_active = False
            self.current_start_time = None
        else:  # Start or resume the timer
            self.timer_active = True
            self.current_start_time = datetime.now()

    def complete_task(self):
        """Marks the task as completed and stops any active timer."""
        if self.timer_active:
            self.start_pause_timer()  # Log the final session
        self.status = "Completed"

    def undo_complete(self):
        """Revert a completed task back to active/in progress."""
        # Do not alter timings; simply change status back
        self.status = "In Progress"

    def get_total_duration(self):
        total_seconds = 0
        for entry in self.timings:
            start = datetime.fromisoformat(entry["start"])
            end = datetime.fromisoformat(entry["end"])
            total_seconds += (end - start).total_seconds()

        if self.timer_active and self.current_start_time:
            total_seconds += (datetime.now() - self.current_start_time).total_seconds()

        return timedelta(seconds=total_seconds)

    def to_dict(self):
        return {"name": self.name, "timings": self.timings, "status": self.status}

    @classmethod
    def from_dict(cls, data):
        return cls(
            data["name"], data.get("timings", []), data.get("status", "In Progress")
        )


# --- Main Application ---
class TaskTrackerApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("Task Tracker")
        self.geometry("800x700")
        self.current_theme = "Dark"
        ctk.set_appearance_mode(self.current_theme)

        self.tasks = {}
        self.task_frames = {}

        self._load_tasks()

        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)

        input_frame = ctk.CTkFrame(self)
        input_frame.grid(row=0, column=0, padx=10, pady=10, sticky="ew")
        input_frame.grid_columnconfigure(0, weight=1)

        self.task_entry = ctk.CTkEntry(
            input_frame, placeholder_text="Enter new task name"
        )
        self.task_entry.grid(row=0, column=0, padx=5, pady=5, sticky="ew")
        self.task_entry.bind("<Return>", self._add_task_event)

        self.add_button = ctk.CTkButton(
            input_frame, text="Add Task", command=self._add_task_event
        )
        self.add_button.grid(row=0, column=1, padx=5, pady=5)

        # theme toggle switch (visual toggle)
        theme_frame = ctk.CTkFrame(input_frame, fg_color="transparent")
        theme_frame.grid(row=0, column=2, padx=5, pady=5, sticky="ew")
        # columns: spacer | sun | switch | moon
        theme_frame.grid_columnconfigure(
            0, weight=1
        )  # spacer pushes controls to the right
        theme_frame.grid_columnconfigure(1, weight=0)
        theme_frame.grid_columnconfigure(2, weight=0)
        theme_frame.grid_columnconfigure(3, weight=0)

        theme_label = ctk.CTkLabel(theme_frame, text="☀️", font=ctk.CTkFont(size=14))
        # place sun left of switch with extra padding to its right
        theme_label.grid(row=0, column=1, padx=(6, 12), sticky="e")

        theme_switch = ctk.CTkSwitch(
            theme_frame,
            text="",
            command=self._toggle_theme,
            onvalue="Light",
            offvalue="Dark",
        )
        # small padding to separate switch from moon
        theme_switch.grid(row=0, column=2, padx=(0, 8))
        theme_switch.deselect()

        theme_moon = ctk.CTkLabel(theme_frame, text="🌙", font=ctk.CTkFont(size=14))
        # anchor moon to the far right
        theme_moon.grid(row=0, column=3, padx=(8, 6), sticky="e")

        self.theme_switch = theme_switch

        self.scrollable_frame = ctk.CTkScrollableFrame(self, label_text="Tasks")
        self.scrollable_frame.grid(row=1, column=0, padx=10, pady=10, sticky="nsew")
        self.scrollable_frame.grid_columnconfigure(0, weight=1)

        actions_frame = ctk.CTkFrame(self)
        actions_frame.grid(row=2, column=0, padx=10, pady=10, sticky="ew")

        self.export_button = ctk.CTkButton(
            actions_frame, text="Export Completed...", command=self._export_dialog
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
        self._update_timers()

        self.protocol("WM_DELETE_WINDOW", self._on_closing)

    def _add_task_event(self, event=None):
        task_name = self.task_entry.get().strip()
        if not task_name:
            # prompt for task name via CTk modal to match app theme
            task_name = self._prompt_task_name()
            if not task_name:
                return

        if task_name not in self.tasks:
            new_task = Task(name=task_name)
            self.tasks[task_name] = new_task
            self._add_task_to_ui(new_task)
            self.task_entry.delete(0, "end")
            self._save_tasks()

    def _toggle_theme(self):
        """Toggle between light and dark theme with a multi-step fade to reduce jarring redraws."""
        try:
            # smoother fade-out
            for a in (1.0, 0.95, 0.9, 0.85):
                self.attributes("-alpha", a)
                self.update_idletasks()
                time.sleep(0.02)
        except Exception:
            pass

        # swap the appearance mode without destroying widgets
        self.current_theme = "Light" if self.current_theme == "Dark" else "Dark"
        ctk.set_appearance_mode(self.current_theme)

        # update switch state (without triggering callback)
        if self.current_theme == "Light":
            self.theme_switch.select()
        else:
            self.theme_switch.deselect()

        # Apply theme colors to main containers
        try:
            self._apply_theme_colors()
        except Exception:
            pass

        # Update header colors for all tasks (headers are row==0 labels in table_frame)
        hdr_bg = "#E0E0E0" if self.current_theme == "Light" else "#3a3a3a"
        hdr_text_color = "#000000" if self.current_theme == "Light" else "#FFFFFF"
        for task_name, task_data in self.task_frames.items():
            table_frame = task_data.get("table_frame")
            if table_frame:
                for widget in table_frame.winfo_children():
                    try:
                        info = widget.grid_info()
                    except Exception:
                        info = {}
                    if isinstance(widget, ctk.CTkLabel) and info.get("row") == 0:
                        widget.configure(fg_color=hdr_bg, text_color=hdr_text_color)

        # smoother fade-in
        try:
            for a in (0.85, 0.9, 0.95, 1.0):
                self.attributes("-alpha", a)
                self.update_idletasks()
                time.sleep(0.02)
        except Exception:
            pass

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
        frame = ctk.CTkFrame(self.scrollable_frame)
        # add a slightly larger bottom padding so the frame's bottom border remains visible
        frame.pack(fill="x", padx=5, pady=(5, 8))
        frame.grid_columnconfigure(0, weight=1)

        header_frame = ctk.CTkFrame(frame)
        header_frame.grid(row=0, column=0, columnspan=2, sticky="ew", padx=5, pady=5)
        # layout: [edit icon] [task name (expand)] [duration]
        header_frame.grid_columnconfigure(0, weight=0)
        header_frame.grid_columnconfigure(1, weight=1)
        header_frame.grid_columnconfigure(2, weight=0)
        header_frame.grid_columnconfigure(3, weight=0)

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
            command=lambda t=task: self._edit_task_name(t),
            text_color="#FFFFFF",
            font=ctk.CTkFont(size=10, weight="bold"),
        )
        edit_icon.grid(row=0, column=0, padx=(5, 8), pady=6, sticky="w")

        task_name_label = ctk.CTkLabel(
            header_frame, text=task.name, font=ctk.CTkFont(size=14, weight="bold")
        )
        task_name_label.grid(row=0, column=1, padx=5, pady=5, sticky="w")

        duration_label = ctk.CTkLabel(header_frame, text="Total: 0h 0m 0s")
        duration_label.grid(row=0, column=2, padx=10, pady=5, sticky="e")

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
            command=lambda t=task: self._toggle_collapse(t),
        )
        collapse_button.grid(row=0, column=3, padx=(6, 8), pady=6, sticky="e")

        button_frame = ctk.CTkFrame(frame)
        # give the grey button strip a little more vertical padding to separate it from buttons
        button_frame.grid(
            row=1, column=0, columnspan=2, sticky="ew", padx=5, pady=(6, 6)
        )

        pause_button = ctk.CTkButton(
            button_frame,
            text="Start",
            command=lambda t=task: self._toggle_pause_resume(t),
        )
        pause_button.pack(side="left", padx=5, pady=4)

        complete_button = ctk.CTkButton(
            button_frame,
            text="Complete Task",
            command=lambda t=task: self._toggle_complete(t),
        )
        complete_button.pack(side="left", padx=5, pady=4)

        delete_button = ctk.CTkButton(
            button_frame,
            text="Delete Task",
            fg_color="#D32F2F",
            hover_color="#B71C1C",
            command=lambda t_name=task.name: self._delete_task(t_name),
        )
        delete_button.pack(side="right", padx=5, pady=4)

        timings_frame = ctk.CTkFrame(frame, fg_color="transparent")
        # add internal bottom padding so timings don't visually overlap the parent's border
        timings_frame.grid(
            row=2, column=0, columnspan=2, sticky="ew", padx=10, pady=(0, 6)
        )

        # create a table_frame inside timings_frame and add a header row (Session | Start | End | Duration)
        table_frame = ctk.CTkFrame(timings_frame, fg_color="transparent")
        table_frame.grid(row=0, column=0, sticky="nsew", padx=0, pady=0)
        table_frame.grid_columnconfigure(0, weight=1, minsize=80)
        table_frame.grid_columnconfigure(1, weight=1, minsize=80)
        table_frame.grid_columnconfigure(2, weight=1, minsize=80)
        table_frame.grid_columnconfigure(3, weight=1, minsize=80)

        # header row with distinct styling (light backgrounds for both themes for contrast)
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

        hdr_session.grid(row=0, column=0, sticky="ew", padx=6, pady=(4, 2))
        hdr_start.grid(row=0, column=1, sticky="ew", padx=6, pady=(4, 2))
        hdr_end.grid(row=0, column=2, sticky="ew", padx=6, pady=(4, 2))
        hdr_dur.grid(row=0, column=3, sticky="ew", padx=6, pady=(4, 2))

        self.task_frames[task.name] = {
            "frame": frame,
            "name_label": task_name_label,
            "duration_label": duration_label,
            "pause_button": pause_button,
            "complete_button": complete_button,
            "edit_button": edit_icon,
            "delete_button": delete_button,
            "timings_frame": timings_frame,
            "table_frame": table_frame,
            "table_rows": [],
            "current_row": None,
            "collapsed": False,
            "collapse_button": collapse_button,
        }
        self._update_task_ui(task)

    def _toggle_collapse(self, task):
        """Toggle the collapse/expand state of the timing table for a task."""
        if task.name in self.task_frames:
            info = self.task_frames[task.name]
            info["collapsed"] = not info.get("collapsed", False)
            collapse_btn = info.get("collapse_button")
            if collapse_btn:
                collapse_btn.configure(text="▸" if info["collapsed"] else "▾")
            timings_frame = info.get("timings_frame")
            if timings_frame:
                # Hide or show the timings frame directly
                if info["collapsed"]:
                    timings_frame.grid_remove()
                else:
                    timings_frame.grid()
            # Force layout recalculation on the scrollable frame and main window
            try:
                self.scrollable_frame.update_idletasks()
            except Exception:
                pass
            try:
                # use the CTk root (self) to update idle tasks
                self.update_idletasks()
            except Exception:
                pass

    def _prompt_task_name(self):
        """Show a CTk modal to prompt for a task name."""
        dlg = ctk.CTkToplevel(self)
        dlg.title("Enter Task Name")
        dlg.transient(self)
        dlg.grab_set()

        try:
            self.update_idletasks()
            w = 380
            h = 140
            x = self.winfo_rootx() + (self.winfo_width() - w) // 2
            y = self.winfo_rooty() + (self.winfo_height() - h) // 2
            dlg.geometry(f"{w}x{h}+{x}+{y}")
        except Exception:
            pass

        lbl = ctk.CTkLabel(dlg, text="Please enter a task name:")
        lbl.pack(padx=20, pady=(18, 8))

        entry = ctk.CTkEntry(dlg, placeholder_text="Task name")
        entry.pack(padx=20, pady=8, fill="x")
        entry.focus()

        result = {"name": None}

        def _on_ok():
            result["name"] = entry.get().strip()
            dlg.destroy()

        def _on_cancel():
            dlg.destroy()

        btn_frame = ctk.CTkFrame(dlg)
        btn_frame.pack(pady=(0, 12))

        ok_btn = ctk.CTkButton(btn_frame, text="OK", command=_on_ok)
        ok_btn.pack(side="left", padx=12)

        cancel_btn = ctk.CTkButton(btn_frame, text="Cancel", command=_on_cancel)
        cancel_btn.pack(side="left", padx=12)

        entry.bind("<Return>", lambda e: _on_ok())

        dlg.wait_window()
        return result["name"] if result["name"] else None
        task.start_pause_timer()
        self._update_task_ui(task)
        self._save_tasks()

    def _toggle_complete(self, task):
        """Toggle a task between Completed and In Progress (undo)."""
        if task.status != "Completed":
            task.complete_task()
        else:
            task.undo_complete()

        self._update_task_ui(task)
        self._save_tasks()
        self._redraw_task_list()  # Redraw to reposition according to status

    def _toggle_pause_resume(self, task):
        """Toggle a task's timer between running and paused."""
        task.start_pause_timer()
        self._update_task_ui(task)
        self._save_tasks()

    def _edit_task_name(self, task):
        dialog = ctk.CTkInputDialog(text="Enter new task name:", title="Edit Task")
        new_name = dialog.get_input()

        if new_name and new_name.strip() and new_name not in self.tasks:
            old_name = task.name
            self.tasks[new_name] = self.tasks.pop(old_name)
            task.name = new_name

            self.task_frames[new_name] = self.task_frames.pop(old_name)
            self.task_frames[new_name]["name_label"].configure(text=new_name)
            # Re-assign lambda for delete button
            self.task_frames[new_name]["delete_button"].configure(
                command=lambda t_name=new_name: self._delete_task(t_name)
            )
            self._save_tasks()

    def _delete_task(self, task_name):
        if task_name in self.tasks:
            # Ask user to confirm deletion using a CTk modal that matches the app style
            if self._confirm_delete(task_name):
                del self.tasks[task_name]
                self._save_tasks()
                self._redraw_task_list()

    def _update_timers(self):
        # Only update UI every second for tasks with active timers to avoid flicker
        for task in self.tasks.values():
            if task.timer_active:
                self._update_task_ui(task)
        self.after(1000, self._update_timers)

    def _format_timedelta(self, td: timedelta) -> str:
        """Format a timedelta into a compact human-friendly string.

        Examples:
        - 12s
        - 2m 5s
        - 1h 2m 5s
        """
        total = int(td.total_seconds())
        hours, rem = divmod(total, 3600)
        minutes, seconds = divmod(rem, 60)
        parts = []
        if hours:
            parts.append(f"{hours}h")
        if minutes:
            parts.append(f"{minutes}m")
        if seconds or not parts:
            parts.append(f"{seconds}s")
        return " ".join(parts)

    def _update_task_ui(self, task):
        """Update the entire UI for a single task."""
        if task.name not in self.task_frames:
            return

        info = self.task_frames[task.name]

        # Update duration (compact format)
        duration = task.get_total_duration()
        duration_str = f"Total: {self._format_timedelta(duration)}"
        info["duration_label"].configure(text=duration_str)

        # Update pause/resume button text
        if task.timer_active:
            info["pause_button"].configure(text="Pause")
        else:
            info["pause_button"].configure(text="Resume" if task.timings else "Start")

        # Timings table: build/update a grid-style table (Session | Start | End | Duration)
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
                    dur_str = self._format_timedelta(end_dt - start_dt)
                    lbl_session = ctk.CTkLabel(table_frame, text=f"Session {i+1}")
                    lbl_start = ctk.CTkLabel(table_frame, text=start)
                    lbl_end = ctk.CTkLabel(table_frame, text=end)
                    lbl_dur = ctk.CTkLabel(table_frame, text=dur_str)
                    lbl_session.grid(row=i + 1, column=0, sticky="ew", padx=6, pady=2)
                    lbl_start.grid(row=i + 1, column=1, sticky="ew", padx=6, pady=2)
                    lbl_end.grid(row=i + 1, column=2, sticky="ew", padx=6, pady=2)
                    lbl_dur.grid(row=i + 1, column=3, sticky="ew", padx=6, pady=2)
                    table_rows.append([lbl_session, lbl_start, lbl_end, lbl_dur])
                info["table_rows"] = table_rows
            else:
                # update existing rows texts
                for i, entry in enumerate(task.timings):
                    start_dt = datetime.fromisoformat(entry["start"])
                    end_dt = datetime.fromisoformat(entry["end"])
                    start = start_dt.strftime("%H:%M:%S")
                    end = end_dt.strftime("%H:%M:%S")
                    dur_str = self._format_timedelta(end_dt - start_dt)
                    row = table_rows[i]
                    try:
                        row[0].configure(text=f"Session {i+1}")
                        row[1].configure(text=start)
                        row[2].configure(text=end)
                        row[3].configure(text=dur_str)
                    except Exception:
                        pass

            # handle running current session row (last)
            if task.timer_active and task.current_start_time:
                start = task.current_start_time.strftime("%H:%M:%S")
                running_str = self._format_timedelta(
                    datetime.now() - task.current_start_time
                )
                # place at row index len(task.timings)+1
                r = len(task.timings) + 1
                if current_row:
                    try:
                        current_row[0].configure(text=f"Session {r}")
                        current_row[1].configure(text=start)
                        current_row[2].configure(text="(running)")
                        current_row[3].configure(text=running_str)
                    except Exception:
                        pass
                else:
                    cr0 = ctk.CTkLabel(table_frame, text=f"Session {r}")
                    cr1 = ctk.CTkLabel(table_frame, text=start)
                    cr2 = ctk.CTkLabel(table_frame, text="(running)")
                    cr3 = ctk.CTkLabel(table_frame, text=running_str)
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

    def _confirm_delete(self, task_name):
        """Show a CTk-styled modal confirmation and return True if user confirms."""
        dlg = ctk.CTkToplevel(self)
        dlg.title("Confirm Delete")
        dlg.transient(self)
        dlg.grab_set()

        # center dialog relative to parent
        try:
            self.update_idletasks()
            w = 360
            h = 120
            x = self.winfo_rootx() + (self.winfo_width() - w) // 2
            y = self.winfo_rooty() + (self.winfo_height() - h) // 2
            dlg.geometry(f"{w}x{h}+{x}+{y}")
        except Exception:
            pass

        lbl = ctk.CTkLabel(
            dlg, text=f"Delete task '{task_name}' and all its timings?", wraplength=320
        )
        lbl.pack(padx=20, pady=(18, 8))

        btn_frame = ctk.CTkFrame(dlg)
        btn_frame.pack(pady=(0, 12))

        result = {"confirm": False}

        def _on_delete():
            result["confirm"] = True
            dlg.destroy()

        def _on_cancel():
            dlg.destroy()

        del_btn = ctk.CTkButton(
            btn_frame,
            text="Delete",
            fg_color="#D32F2F",
            hover_color="#B71C1C",
            command=_on_delete,
        )
        del_btn.pack(side="left", padx=12)

        cancel_btn = ctk.CTkButton(btn_frame, text="Cancel", command=_on_cancel)
        cancel_btn.pack(side="left", padx=12)

        dlg.wait_window()
        return result["confirm"]

    def _save_tasks(self):
        with open(DATA_FILE, "w") as f:
            json.dump([task.to_dict() for task in self.tasks.values()], f, indent=4)

    def _load_tasks(self):
        if os.path.exists(DATA_FILE):
            try:
                with open(DATA_FILE, "r") as f:
                    data = json.load(f)
                    self.tasks = {item["name"]: Task.from_dict(item) for item in data}
            except (json.JSONDecodeError, KeyError):
                self.tasks = {}

    def _export_to_csv(self):
        filepath = os.path.join(DESKTOP_PATH, CSV_FILE)
        completed_tasks = [t for t in self.tasks.values() if t.status == "Completed"]

        with open(filepath, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(
                ["Task Name", "Start Time", "End Time", "Duration (seconds)"]
            )

            for task in completed_tasks:
                for entry in task.timings:
                    start = datetime.fromisoformat(entry["start"])
                    end = datetime.fromisoformat(entry["end"])
                    duration = (end - start).total_seconds()
                    writer.writerow(
                        [
                            task.name,
                            start.strftime("%Y-%m-%d %H:%M:%S"),
                            end.strftime("%Y-%m-%d %H:%M:%S"),
                            duration,
                        ]
                    )

        # Optional: show a confirmation message
        dialog = ctk.CTkInputDialog(
            text=f"Exported to:\n{filepath}", title="Export Successful"
        )
        dialog.get_input()

    def _export_dialog(self):
        """Show a themed dialog letting user pick filename, formats and directory, then export."""
        dlg = ctk.CTkToplevel(self)
        dlg.title("Export Tasks")
        dlg.transient(self)
        dlg.grab_set()

        # Center dialog roughly
        try:
            self.update_idletasks()
            w = 480
            h = 220
            x = self.winfo_x() + (self.winfo_width() - w) // 2
            y = self.winfo_y() + (self.winfo_height() - h) // 2
            dlg.geometry(f"{w}x{h}+{x}+{y}")
        except Exception:
            pass

        frm = ctk.CTkFrame(dlg)
        frm.pack(fill="both", expand=True, padx=12, pady=12)

        ctk.CTkLabel(frm, text="Filename (no extension):").grid(
            row=0, column=0, sticky="w"
        )
        name_var = ctk.StringVar(value="task_times")
        name_entry = ctk.CTkEntry(frm, textvariable=name_var)
        name_entry.grid(row=0, column=1, sticky="ew", padx=(8, 0))
        frm.grid_columnconfigure(1, weight=1)

        ctk.CTkLabel(frm, text="Export Formats:").grid(
            row=1, column=0, sticky="w", pady=(8, 0)
        )
        csv_var = ctk.BooleanVar(value=True)
        json_var = ctk.BooleanVar(value=False)
        xlsx_var = ctk.BooleanVar(value=False)
        cb_csv = ctk.CTkCheckBox(frm, text="CSV", variable=csv_var)
        cb_json = ctk.CTkCheckBox(frm, text="JSON", variable=json_var)
        cb_xlsx = ctk.CTkCheckBox(frm, text="XLSX", variable=xlsx_var)
        cb_csv.grid(row=1, column=1, sticky="w")
        cb_json.grid(row=1, column=1, sticky="w", padx=(70, 0))
        cb_xlsx.grid(row=1, column=1, sticky="w", padx=(150, 0))

        # directory selector
        dir_var = ctk.StringVar(value=DESKTOP_PATH)

        def _choose_dir():
            p = filedialog.askdirectory(initialdir=DESKTOP_PATH)
            if p:
                dir_var.set(p)

        ctk.CTkLabel(frm, text="Directory:").grid(
            row=2, column=0, sticky="w", pady=(8, 0)
        )
        dir_lbl = ctk.CTkLabel(frm, textvariable=dir_var, anchor="w")
        dir_lbl.grid(row=2, column=1, sticky="ew", padx=(8, 0))
        dir_btn = ctk.CTkButton(frm, text="Browse...", command=_choose_dir, width=96)
        dir_btn.grid(row=2, column=2, padx=(8, 0))

        btn_frame = ctk.CTkFrame(frm, fg_color="transparent")
        btn_frame.grid(row=3, column=0, columnspan=3, pady=(12, 0))

        def _on_export():
            name = name_var.get().strip()
            formats = []
            if csv_var.get():
                formats.append("csv")
            if json_var.get():
                formats.append("json")
            if xlsx_var.get():
                formats.append("xlsx")
            if not name:
                messagebox.showerror("Export", "Please provide a filename.")
                return
            if not formats:
                messagebox.showerror("Export", "Please select at least one format.")
                return
            out_dir = dir_var.get()
            dlg.grab_release()
            dlg.destroy()
            self._perform_export(out_dir, name, formats)

        def _on_cancel():
            dlg.grab_release()
            dlg.destroy()

        exp_btn = ctk.CTkButton(btn_frame, text="Export", command=_on_export)
        exp_btn.pack(side="right", padx=12)
        cancel_btn = ctk.CTkButton(btn_frame, text="Cancel", command=_on_cancel)
        cancel_btn.pack(side="left", padx=12)

        dlg.wait_window()

    def _perform_export(self, out_dir, name, formats):
        """Write selected formats for completed tasks to the chosen directory.

        Supports csv and json out of the box. Attempts to write xlsx using
        pandas or openpyxl if available; otherwise notifies the user.
        """
        completed_tasks = [t for t in self.tasks.values() if t.status == "Completed"]
        if not completed_tasks:
            messagebox.showinfo("Export", "No completed tasks to export.")
            return

        # Determine whether the user entered a full path in the name box.
        if os.path.isabs(name) or os.path.dirname(name):
            abs_path = os.path.abspath(name)
            base_dir = os.path.dirname(abs_path)
            base_name = os.path.splitext(os.path.basename(abs_path))[0]
        else:
            base_dir = out_dir
            base_name = name

        # Ensure output directory exists (try to create if missing)
        try:
            os.makedirs(base_dir, exist_ok=True)
        except Exception as e:
            messagebox.showerror("Export", f"Output directory unavailable: {e}")
            return

        rows = []
        for task in completed_tasks:
            for entry in task.timings:
                start = (
                    datetime.fromisoformat(entry.get("start"))
                    if entry.get("start")
                    else None
                )
                end = (
                    datetime.fromisoformat(entry.get("end"))
                    if entry.get("end")
                    else None
                )
                duration = (end - start).total_seconds() if start and end else ""
                rows.append(
                    {
                        "Task Name": task.name,
                        "Start Time": (
                            start.strftime("%Y-%m-%d %H:%M:%S") if start else ""
                        ),
                        "End Time": end.strftime("%Y-%m-%d %H:%M:%S") if end else "",
                        "Duration (seconds)": duration,
                    }
                )

        # CSV
        if "csv" in formats:
            csv_path = os.path.join(base_dir, f"{base_name}.csv")
            try:
                with open(csv_path, "w", newline="", encoding="utf-8") as f:
                    writer = csv.writer(f)
                    writer.writerow(
                        ["Task Name", "Start Time", "End Time", "Duration (seconds)"]
                    )
                    for r in rows:
                        writer.writerow(
                            [
                                r["Task Name"],
                                r["Start Time"],
                                r["End Time"],
                                r["Duration (seconds)"],
                            ]
                        )
            except Exception as e:
                messagebox.showerror("Export", f"CSV export failed: {e}")
                return

        # JSON
        if "json" in formats:
            json_path = os.path.join(base_dir, f"{base_name}.json")
            try:
                with open(json_path, "w", encoding="utf-8") as f:
                    json.dump(rows, f, indent=2)
            except Exception as e:
                messagebox.showerror("Export", f"JSON export failed: {e}")
                return

        # XLSX - try pandas then openpyxl
        if "xlsx" in formats:
            xlsx_path = os.path.join(base_dir, f"{base_name}.xlsx")
            wrote_xlsx = False
            try:
                import pandas as pd

                df = pd.DataFrame(rows)
                df.to_excel(xlsx_path, index=False)
                wrote_xlsx = True
            except Exception:
                try:
                    from openpyxl import Workbook

                    wb = Workbook()
                    ws = wb.active
                    ws.append(
                        ["Task Name", "Start Time", "End Time", "Duration (seconds)"]
                    )
                    for r in rows:
                        ws.append(
                            [
                                r["Task Name"],
                                r["Start Time"],
                                r["End Time"],
                                r["Duration (seconds)"],
                            ]
                        )
                    wb.save(xlsx_path)
                    wrote_xlsx = True
                except Exception as e:
                    messagebox.showwarning(
                        "Export",
                        "XLSX export failed: pandas/openpyxl not available or error occurred. Install pandas or openpyxl to enable xlsx exports.",
                    )

            if not wrote_xlsx:
                # continue, since other formats may have succeeded
                pass

        messagebox.showinfo("Export", f"Export completed to: {base_dir}")

    def _on_closing(self):
        self._save_tasks()
        self.destroy()


if __name__ == "__main__":
    app = TaskTrackerApp()
    app.mainloop()
