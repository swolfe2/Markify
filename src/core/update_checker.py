"""
Update checker for Markify.
Checks GitHub Releases API for new versions of the application.
"""
from __future__ import annotations

import json
import threading
import urllib.request

from logging_config import get_logger

logger = get_logger("update_checker")


def parse_version(version_str: str) -> tuple[int, ...]:
    """Parse a version string (e.g. 'v1.2.3-beta', '1.2.0') into a tuple of integers."""
    cleaned = version_str.strip().lstrip("vV")
    parts = []
    for part in cleaned.split("."):
        digits = []
        for char in part:
            if char.isdigit():
                digits.append(char)
            else:
                break
        if digits:
            parts.append(int("".join(digits)))
        else:
            parts.append(0)
    return tuple(parts)


def is_newer_version(remote: str, local: str) -> bool:
    """Compare remote version against local version to see if it is newer."""
    try:
        return parse_version(remote) > parse_version(local)
    except Exception as e:
        logger.debug(f"Error comparing versions {remote} and {local}: {e}")
        return False


def get_latest_release() -> str | None:
    """Fetch the latest release tag name from the GitHub repository."""
    url = "https://api.github.com/repos/swolfe2/Markify/releases/latest"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Markify-Update-Checker"}
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as response:  # nosec B310
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                return data.get("tag_name")
    except Exception as e:
        logger.debug(f"Failed to check for updates: {e}")
    return None


def check_for_updates_async(callback: callable) -> None:
    """Check for updates asynchronously in a background thread.

    Calls callback(remote_version) on completion. callback receives None if the check fails.
    """
    def worker():
        try:
            remote_version = get_latest_release()
            callback(remote_version)
        except Exception as e:
            logger.debug(f"Error in update check thread: {e}")
            callback(None)

    thread = threading.Thread(target=worker, daemon=True)
    thread.start()
