"""Task data model."""

from datetime import datetime, timedelta


class Task:
    """Represents a single task with its timing records."""

    def __init__(self, name, timings=None, status="In Progress", note=None):
        self.name = name
        # List of {'start': str, 'end': str, 'name': str, 'note': str}
        self.timings = timings if timings else []
        self.status = status
        self.note = note  # Task-level note
        self.timer_active = False
        self.current_start_time = None

    def start_pause_timer(self):
        """Toggles the timer on and off (starts, pauses, resumes)."""
        if self.timer_active:  # Pause the timer
            self.timings.append(
                {
                    "start": self.current_start_time.isoformat(),
                    "end": datetime.now().isoformat(),
                    "name": None,  # Custom session name (None = use default)
                    "note": None,  # Session note
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
        """Get total duration as sum of rounded individual session durations."""
        total_seconds = 0
        for entry in self.timings:
            start = datetime.fromisoformat(entry["start"])
            end = datetime.fromisoformat(entry["end"])
            # Round each session duration to whole seconds before summing
            session_seconds = int((end - start).total_seconds())
            total_seconds += session_seconds

        if self.timer_active and self.current_start_time:
            # Round current running session to whole seconds
            elapsed = datetime.now() - self.current_start_time
            running_seconds = int(elapsed.total_seconds())
            total_seconds += running_seconds

        return timedelta(seconds=total_seconds)

    def to_dict(self):
        return {
            "name": self.name,
            "timings": self.timings,
            "status": self.status,
            "note": self.note,
        }

    @classmethod
    def from_dict(cls, data):
        # Ensure old data format is compatible
        timings = data.get("timings", [])
        # Migrate old timing entries to include name and note fields
        for entry in timings:
            if "name" not in entry:
                entry["name"] = None
            if "note" not in entry:
                entry["note"] = None
        return cls(
            data["name"],
            timings,
            data.get("status", "In Progress"),
            data.get("note"),
        )
