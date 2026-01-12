"""
User preferences management for Markify.
Stores settings in %APPDATA%/Markify/prefs.json
"""
from __future__ import annotations

import json
import os
import sys
from typing import Any

from logging_config import get_logger

logger = get_logger("prefs")


class Preferences:
    """Manages user preferences with JSON persistence."""

    def __init__(self) -> None:
        self.prefs_dir: str = self._get_prefs_dir()
        self.prefs_file: str = os.path.join(self.prefs_dir, "prefs.json")
        self.settings: dict[str, Any] = {
            "last_directory": "",
            "format_dax": True,
            "format_pq": True,
            "output_mode": "same",  # "same" or "custom"
            "custom_output_dir": "",
            "extract_images": False,
            "theme": "VS Code Dark",
            "recent_files": [],
            "show_preview": True,  # Show preview before saving
            "clipboard_debug_mode": False  # Save raw HTML for debugging
        }

        self.load()

    def add_recent_file(self, source_path: str, output_path: str) -> None:
        """Add a conversion to the recent files list (Max 5).

        Each entry is a dict with:
            - timestamp: ISO format datetime string
            - source: Path to original document
            - output: Path to converted markdown file
            - sort_index: Integer for ordering (1 = most recent)

        Uses sort index to maintain order:
        - New combination: removes #5, shifts others down, inserts new at index 1
        - Existing combination: moves to index 1, shifts others down
        """
        import os
        from datetime import datetime

        recents = self.settings.get("recent_files", [])

        # Migrate old format (list of strings) to new format (list of dicts)
        if recents and isinstance(recents[0], str):
            recents = []

        # Normalize paths for comparison
        norm_source = os.path.normpath(source_path)
        norm_output = os.path.normpath(output_path)

        # Check if this source+output combination already exists
        existing_index = None
        for i, r in enumerate(recents):
            existing_source = os.path.normpath(r.get("source", ""))
            existing_output = os.path.normpath(r.get("output", ""))
            if existing_source == norm_source and existing_output == norm_output:
                existing_index = i
                break

        if existing_index is not None:
            # Combination exists - move it to front
            entry = recents.pop(existing_index)
            entry["timestamp"] = datetime.now().isoformat()  # Update timestamp
            recents.insert(0, entry)
        else:
            # New combination - add to front
            entry = {
                "timestamp": datetime.now().isoformat(),
                "source": source_path,
                "output": output_path
            }
            recents.insert(0, entry)

            # Limit to 5 (removes the oldest)
            if len(recents) > 5:
                recents = recents[:5]

        # Update sort indices (1 = most recent)
        for i, r in enumerate(recents):
            r["sort_index"] = i + 1

        self.set("recent_files", recents)

    def _get_prefs_dir(self) -> str:
        """Get the directory specifically for storing app data."""
        if sys.platform == "win32":
            base_path = os.environ.get("APPDATA")
        else:
            # Fallback for non-Windows dev environments
            base_path = os.path.expanduser("~")

        # Create Markify subfolder
        path = os.path.join(base_path, "Markify")
        if not os.path.exists(path):
            try:
                os.makedirs(path)
            except OSError:
                # Fallback to local execution dir if permission denied
                return os.path.dirname(os.path.abspath(__file__))
        return path

    def load(self) -> None:
        """Load preferences from JSON file."""
        if os.path.exists(self.prefs_file):
            try:
                with open(self.prefs_file) as f:
                    data = json.load(f)
                    # Update settings with loaded data, keeping defaults for missing keys
                    self.settings.update(data)
            except Exception as e:
                logger.warning(f"Failed to load preferences: {e}")

    def save(self) -> None:
        """Save current settings to JSON file."""
        try:
            with open(self.prefs_file, 'w') as f:
                json.dump(self.settings, f, indent=4)
        except Exception as e:
            logger.warning(f"Failed to save preferences: {e}")

    def get(self, key: str, default: Any = None) -> Any:
        """Get a preference value."""
        return self.settings.get(key, default)

    def set(self, key: str, value: Any) -> None:
        """Set a preference value and save."""
        self.settings[key] = value
        self.save()
