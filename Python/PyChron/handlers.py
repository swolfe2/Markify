"""Event handlers for PyChron application."""

from datetime import datetime

from models import Task
from storage import save_tasks
from ui import (
    confirm_delete,
    confirm_delete_all,
    prompt_edit_task_name,
    prompt_note,
    prompt_session_name,
    prompt_task_name,
    show_info,
)


class TaskHandlers:
    """Handles all user interaction events for tasks."""

    def __init__(self, app):
        """Initialize handlers with reference to main app.

        Args:
            app: PyChronApp instance
        """
        self.app = app

    def add_task(self, event=None):
        """Handle adding a new task."""
        task_name = self.app.task_entry.get().strip()
        if not task_name:
            task_name = prompt_task_name(self.app)
            if not task_name:
                return

        if task_name not in self.app.tasks:
            new_task = Task(name=task_name)
            self.app.tasks[task_name] = new_task
            self.app._add_task_to_ui(new_task)
            self.app.task_entry.delete(0, "end")
            save_tasks(self.app.tasks)
            self.app._update_scrollbar_visibility()

    def toggle_collapse(self, task):
        """Toggle collapse/expand state of task details."""
        if task.name in self.app.task_frames:
            info = self.app.task_frames[task.name]
            info["collapsed"] = not info.get("collapsed", False)
            collapse_btn = info.get("collapse_button")
            if collapse_btn:
                collapse_btn.configure(text="▸" if info["collapsed"] else "▾")
            timings_frame = info.get("timings_frame")
            if timings_frame:
                if info["collapsed"]:
                    timings_frame.grid_remove()
                else:
                    timings_frame.grid()
            try:
                self.app.scrollable_frame.update_idletasks()
            except Exception:
                pass
            try:
                self.app.update_idletasks()
            except Exception:
                pass
            self.app.after(10, self.app._update_scrollbar_visibility)
            self.app._update_scrollbar_visibility()

    def toggle_complete(self, task):
        """Toggle task completion status."""
        if task.status != "Completed":
            task.complete_task()
        else:
            task.undo_complete()
        self.app._update_task_ui(task)
        save_tasks(self.app.tasks)
        self.app._redraw_task_list()
        self.app._update_export_button_state()

    def toggle_pause_resume(self, task):
        """Toggle timer pause/resume."""
        task.start_pause_timer()
        self.app._update_task_ui(task)
        save_tasks(self.app.tasks)
        self.app.after(10, self.app._update_scrollbar_visibility)
        self.app._update_scrollbar_visibility()

    def edit_task_name(self, task):
        """Edit task name."""
        new_name = prompt_edit_task_name(self.app, current_name=task.name)

        if new_name and new_name.strip() and new_name not in self.app.tasks:
            old_name = task.name
            self.app.tasks[new_name] = self.app.tasks.pop(old_name)
            task.name = new_name
            self.app.task_frames[new_name] = self.app.task_frames.pop(old_name)
            self.app.task_frames[new_name]["name_label"].configure(text=new_name)
            delete_btn = self.app.task_frames[new_name]["delete_button"]
            delete_btn.configure(
                command=lambda t_name=new_name: self.delete_task(t_name)
            )
            save_tasks(self.app.tasks)

    def delete_task(self, task_name):
        """Delete a task after confirmation."""
        if task_name in self.app.tasks:
            if confirm_delete(self.app, task_name):
                del self.app.tasks[task_name]
                save_tasks(self.app.tasks)
                self.app._redraw_task_list()
                self.app._update_scrollbar_visibility()

    def delete_all_tasks(self):
        """Delete all tasks after confirmation."""
        if not self.app.tasks:
            return

        if confirm_delete_all(self.app):
            self.app.tasks.clear()
            save_tasks(self.app.tasks)
            self.app._redraw_task_list()
            self.app._update_scrollbar_visibility()
            self.app._update_export_button_state()

    def edit_session_name(self, task, session_index):
        """Edit the name of a specific session."""
        if session_index >= len(task.timings):
            return
        entry = task.timings[session_index]
        current_name = entry.get("name")
        new_name = prompt_session_name(self.app, current_name=current_name)
        if new_name is not None:
            entry["name"] = new_name if new_name.strip() else None
            save_tasks(self.app.tasks)
            self.app._update_task_ui(task)

    def edit_session_note(self, task, session_index):
        """Edit the note for a specific session."""
        entry = task.timings[session_index]
        current_note = entry.get("note")
        title = f"Edit Note - Session {session_index + 1}"
        new_note = prompt_note(self.app, current_note, title=title)
        if new_note is not None:
            entry["note"] = new_note if new_note else None
            save_tasks(self.app.tasks)
            self.app._update_task_ui(task)

    def edit_task_note(self, task):
        """Edit the note for a task."""
        new_note = prompt_note(self.app, task.note, title=f"Edit Note - {task.name}")
        if new_note is not None:
            task.note = new_note if new_note else None
            save_tasks(self.app.tasks)
            self.app._update_task_ui(task)

    def copy_task_results(self, task):
        """Copy task results to clipboard in Excel-friendly format."""
        lines = []
        # Header with all columns including Task Note
        header = (
            "Session\tStart Time\tEnd Time\t"
            "Duration (seconds)\tSession Note\tTask Note"
        )
        lines.append(header)

        # Get task note once
        task_note = task.note if task.note else ""

        # Add a row for each session
        for i, entry in enumerate(task.timings):
            start_dt = datetime.fromisoformat(entry["start"])
            end_dt = datetime.fromisoformat(entry["end"])
            start = start_dt.strftime("%H:%M:%S")
            end = end_dt.strftime("%H:%M:%S")
            duration_seconds = int((end_dt - start_dt).total_seconds())
            session_name = entry.get("name") or f"Session {i + 1}"
            session_note = entry.get("note") or ""
            hours = duration_seconds // 3600
            minutes = (duration_seconds % 3600) // 60
            seconds = duration_seconds % 60
            duration_time = f"{hours:02d}:{minutes:02d}:{seconds:02d}"
            row = (
                f"{session_name}\t{start}\t{end}\t{duration_time}\t"
                f"{session_note}\t{task_note}"
            )
            lines.append(row)

        text = "\n".join(lines)
        self.app.clipboard_clear()
        self.app.clipboard_append(text)
        show_info(self.app, "Copied", "Task results copied to clipboard!")

    def perform_export(self, out_dir, name, formats):
        """Wrapper to call the export module function."""
        from export import perform_export

        perform_export(self.app.tasks, out_dir, name, formats, parent=self.app)
