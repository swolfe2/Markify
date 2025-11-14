"""Formatting utility functions."""

from datetime import timedelta


def format_timedelta(td: timedelta) -> str:
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
