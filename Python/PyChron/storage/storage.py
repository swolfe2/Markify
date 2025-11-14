"""Storage functions for persisting tasks to disk."""

import json
import os

from constants import DATA_FILE
from models import Task


def save_tasks(tasks):
    """Save tasks dictionary to JSON file."""
    with open(DATA_FILE, "w") as f:
        json.dump([task.to_dict() for task in tasks.values()], f, indent=4)


def load_tasks():
    """Load tasks from JSON file and return as dictionary."""
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r") as f:
                data = json.load(f)
                return {item["name"]: Task.from_dict(item) for item in data}
        except (json.JSONDecodeError, KeyError):
            return {}
    return {}
