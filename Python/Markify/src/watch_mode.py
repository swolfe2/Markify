"""
Watch Mode for Markify.
Monitors a folder for new/modified DOCX/XLSX files and auto-converts them.
Uses polling-based approach with Python standard library only.
"""
from __future__ import annotations

import os
import time
import threading
from typing import Dict, Optional, Callable, Tuple

from logging_config import get_logger

logger = get_logger("watch_mode")


class FolderWatcher:
    """
    Monitor a folder for new or modified .docx/.xlsx files.
    
    Uses polling-based detection (no external dependencies).
    Runs in a background thread and invokes callbacks on file events.
    """
    
    SUPPORTED_EXTENSIONS = ('.docx', '.xlsx')
    
    def __init__(
        self,
        watch_path: str,
        output_path: Optional[str] = None,
        interval: float = 2.0,
        watch_modified: bool = True,
        on_file_found: Optional[Callable[[str], None]] = None,
        on_convert_start: Optional[Callable[[str], None]] = None,
        on_convert_complete: Optional[Callable[[str, str, bool], None]] = None,
        on_error: Optional[Callable[[str, str], None]] = None,
    ):
        """
        Initialize the folder watcher.
        
        Args:
            watch_path: Folder path to monitor
            output_path: Optional custom output folder (None = same as source)
            interval: Polling interval in seconds (default: 2.0)
            watch_modified: If True, also detect modified files (not just new)
            on_file_found: Callback(filepath) when a new/modified file is detected
            on_convert_start: Callback(filepath) when conversion starts
            on_convert_complete: Callback(filepath, output_path, success) when done
            on_error: Callback(filepath, error_message) on errors
        """
        self.watch_path = os.path.abspath(watch_path)
        self.output_path = output_path
        self.interval = interval
        self.watch_modified = watch_modified
        
        # Callbacks
        self.on_file_found = on_file_found
        self.on_convert_start = on_convert_start
        self.on_convert_complete = on_convert_complete
        self.on_error = on_error
        
        # State
        self._known_files: Dict[str, float] = {}  # filepath -> mtime
        self._running = False
        self._paused = False
        self._thread: Optional[threading.Thread] = None
        self._lock = threading.Lock()
        
        # Statistics
        self.files_converted = 0
        self.files_failed = 0
        
        logger.info(f"FolderWatcher initialized for: {self.watch_path}")
    
    @property
    def is_running(self) -> bool:
        """Check if the watcher is currently active."""
        return self._running and not self._paused
    
    @property
    def is_paused(self) -> bool:
        """Check if the watcher is paused."""
        return self._running and self._paused
    
    def start(self) -> None:
        """Start watching the folder in a background thread."""
        if self._running:
            logger.warning("Watcher already running")
            return
        
        if not os.path.isdir(self.watch_path):
            raise ValueError(f"Watch path is not a valid directory: {self.watch_path}")
        
        # Initialize with current files
        self._known_files = self._get_current_files()
        self._running = True
        self._paused = False
        
        self._thread = threading.Thread(target=self._scan_loop, daemon=True)
        self._thread.start()
        
        logger.info(f"Started watching: {self.watch_path} (interval: {self.interval}s)")
    
    def stop(self) -> None:
        """Stop watching."""
        if not self._running:
            return
        
        self._running = False
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=self.interval + 1)
        
        logger.info(f"Stopped watching: {self.watch_path}")
    
    def pause(self) -> None:
        """Pause watching (keeps thread alive but skips processing)."""
        self._paused = True
        logger.info("Watcher paused")
    
    def resume(self) -> None:
        """Resume watching after pause."""
        self._paused = False
        logger.info("Watcher resumed")
    
    def _get_current_files(self) -> Dict[str, float]:
        """
        Get current files in watch folder with their modification times.
        
        Returns:
            Dict mapping filepath to modification time
        """
        files = {}
        try:
            for entry in os.scandir(self.watch_path):
                if entry.is_file() and entry.name.lower().endswith(self.SUPPORTED_EXTENSIONS):
                    try:
                        files[entry.path] = entry.stat().st_mtime
                    except OSError:
                        # File may have been deleted between scandir and stat
                        pass
        except OSError as e:
            logger.error(f"Error scanning folder: {e}")
        
        return files
    
    def _scan_loop(self) -> None:
        """Main polling loop - runs in background thread."""
        while self._running:
            if not self._paused:
                try:
                    self._check_for_changes()
                except Exception as e:
                    logger.error(f"Error in scan loop: {e}")
            
            # Sleep in small increments for responsive shutdown
            for _ in range(int(self.interval * 10)):
                if not self._running:
                    break
                time.sleep(0.1)
    
    def _check_for_changes(self) -> None:
        """Check for new or modified files and trigger conversions."""
        current_files = self._get_current_files()
        
        with self._lock:
            # Find new and modified files
            files_to_process = []
            
            for filepath, mtime in current_files.items():
                if filepath not in self._known_files:
                    # New file
                    logger.info(f"New file detected: {filepath}")
                    files_to_process.append(filepath)
                elif self.watch_modified and mtime > self._known_files[filepath]:
                    # Modified file
                    logger.info(f"Modified file detected: {filepath}")
                    files_to_process.append(filepath)
            
            # Update known files
            self._known_files = current_files
        
        # Process detected files
        for filepath in files_to_process:
            self._process_file(filepath)
    
    def _process_file(self, filepath: str) -> None:
        """Process a single file - convert to Markdown."""
        if self.on_file_found:
            self.on_file_found(filepath)
        
        if self.on_convert_start:
            self.on_convert_start(filepath)
        
        try:
            output_path = self._convert_file(filepath)
            self.files_converted += 1
            
            if self.on_convert_complete:
                self.on_convert_complete(filepath, output_path, True)
                
        except Exception as e:
            self.files_failed += 1
            error_msg = str(e)
            logger.error(f"Conversion failed for {filepath}: {error_msg}")
            
            if self.on_error:
                self.on_error(filepath, error_msg)
            
            if self.on_convert_complete:
                self.on_convert_complete(filepath, "", False)
    
    def _convert_file(self, filepath: str) -> str:
        """
        Convert a single file to Markdown.
        
        Args:
            filepath: Path to the file to convert
            
        Returns:
            Path to the output .md file
        """
        # Import here to avoid circular imports
        from markify_core import get_docx_content
        from xlsx_core import get_xlsx_content
        
        # Determine output path
        base_name = os.path.splitext(os.path.basename(filepath))[0]
        
        if self.output_path and os.path.isdir(self.output_path):
            output_file = os.path.join(self.output_path, f"{base_name}.md")
        else:
            output_file = os.path.join(os.path.dirname(filepath), f"{base_name}.md")
        
        # Convert based on file type
        if filepath.lower().endswith('.xlsx'):
            content = get_xlsx_content(filepath)
        else:
            markdown_lines = get_docx_content(filepath)
            content = '\n\n'.join(markdown_lines) if markdown_lines else ""
        
        if not content:
            raise ValueError("No content extracted from file")
        
        # Write output
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(content)
        
        logger.info(f"Converted: {filepath} -> {output_file}")
        return output_file
    
    def get_stats(self) -> Tuple[int, int]:
        """
        Get conversion statistics.
        
        Returns:
            Tuple of (files_converted, files_failed)
        """
        return (self.files_converted, self.files_failed)
    
    def reset_stats(self) -> None:
        """Reset conversion statistics."""
        self.files_converted = 0
        self.files_failed = 0


def create_watcher(
    watch_path: str,
    output_path: Optional[str] = None,
    interval: float = 2.0,
    watch_modified: bool = True
) -> FolderWatcher:
    """
    Factory function to create a FolderWatcher instance.
    
    Args:
        watch_path: Folder path to monitor
        output_path: Optional custom output folder
        interval: Polling interval in seconds
        watch_modified: If True, also detect modified files
        
    Returns:
        Configured FolderWatcher instance
    """
    return FolderWatcher(
        watch_path=watch_path,
        output_path=output_path,
        interval=interval,
        watch_modified=watch_modified
    )
