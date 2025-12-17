"""
Logging configuration for Markify.
Provides centralized logging setup with console and optional file output.
"""
from __future__ import annotations

import logging
import os
import sys
from typing import Optional


def _get_log_dir() -> str:
    """Get the directory for log files."""
    if sys.platform == "win32":
        base_path = os.environ.get("APPDATA", "")
    else:
        base_path = os.path.expanduser("~")
    
    log_dir = os.path.join(base_path, "Markify")
    if not os.path.exists(log_dir):
        try:
            os.makedirs(log_dir)
        except OSError:
            # Fallback to temp directory
            import tempfile
            return tempfile.gettempdir()
    return log_dir


def setup_logging(
    level: int = logging.INFO,
    enable_file_logging: bool = False,
    log_filename: str = "markify.log"
) -> None:
    """
    Configure logging for the application.
    
    Args:
        level: Logging level (default: INFO)
        enable_file_logging: If True, also log to a file
        log_filename: Name of the log file
    """
    # Create formatter
    formatter = logging.Formatter(
        fmt="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    
    # Get root logger for markify
    root_logger = logging.getLogger("markify")
    root_logger.setLevel(level)
    
    # Avoid adding handlers multiple times
    if root_logger.handlers:
        return
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)
    
    # Optional file handler
    if enable_file_logging:
        try:
            log_path = os.path.join(_get_log_dir(), log_filename)
            file_handler = logging.FileHandler(log_path, encoding="utf-8")
            file_handler.setLevel(logging.DEBUG)  # File gets more detail
            file_handler.setFormatter(formatter)
            root_logger.addHandler(file_handler)
        except Exception:
            # If file logging fails, continue with console only
            pass


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger for a specific module.
    
    Args:
        name: Module name (e.g., "markify.core")
    
    Returns:
        Configured logger instance
    """
    return logging.getLogger(f"markify.{name}")
