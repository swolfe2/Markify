"""
Folder scanning utilities for Markify.
Recursively discovers convertible files (.docx, .xlsx) in directories.
Zero dependencies - uses only Python built-ins.
"""
from __future__ import annotations

import os
from typing import List, Optional, Set, Tuple


# Default extensions that Markify can convert
DEFAULT_EXTENSIONS: Set[str] = {'.docx', '.xlsx'}


def is_convertible_file(path: str, extensions: Optional[Set[str]] = None) -> bool:
    """
    Check if a file is convertible based on its extension.
    
    Args:
        path: Path to the file
        extensions: Set of extensions to match (with leading dot).
                   Defaults to {'.docx', '.xlsx'}
    
    Returns:
        True if the file extension matches, False otherwise
    """
    if extensions is None:
        extensions = DEFAULT_EXTENSIONS
    
    _, ext = os.path.splitext(path)
    return ext.lower() in extensions


def scan_folder(
    path: str,
    extensions: Optional[Set[str]] = None,
    recursive: bool = True
) -> List[str]:
    """
    Scan a folder for convertible files.
    
    Args:
        path: Path to the folder to scan
        extensions: Set of extensions to match (with leading dot).
                   Defaults to {'.docx', '.xlsx'}
        recursive: If True, scan subdirectories recursively
    
    Returns:
        List of absolute paths to matching files, sorted alphabetically
    """
    if extensions is None:
        extensions = DEFAULT_EXTENSIONS
    
    if not os.path.isdir(path):
        return []
    
    results: List[str] = []
    
    if recursive:
        for root, _dirs, files in os.walk(path):
            for filename in files:
                filepath = os.path.join(root, filename)
                if is_convertible_file(filepath, extensions):
                    results.append(filepath)
    else:
        # Non-recursive: only check immediate children
        for entry in os.listdir(path):
            filepath = os.path.join(path, entry)
            if os.path.isfile(filepath) and is_convertible_file(filepath, extensions):
                results.append(filepath)
    
    return sorted(results)


def expand_paths(paths: List[str], extensions: Optional[Set[str]] = None) -> List[str]:
    """
    Expand a mixed list of files and folders into a flat list of files.
    
    This is the main entry point for handling drag-and-drop that may
    include both individual files and folders.
    
    Args:
        paths: List of file and/or folder paths
        extensions: Set of extensions to match for folder scanning.
                   Defaults to {'.docx', '.xlsx'}
    
    Returns:
        List of absolute file paths, with folders expanded to their contents
    """
    if extensions is None:
        extensions = DEFAULT_EXTENSIONS
    
    results: List[str] = []
    seen: Set[str] = set()  # Avoid duplicates
    
    for path in paths:
        if os.path.isdir(path):
            # Expand folder to files
            for filepath in scan_folder(path, extensions):
                abs_path = os.path.abspath(filepath)
                if abs_path not in seen:
                    seen.add(abs_path)
                    results.append(abs_path)
        elif os.path.isfile(path):
            # Individual file - check extension if specified
            if is_convertible_file(path, extensions):
                abs_path = os.path.abspath(path)
                if abs_path not in seen:
                    seen.add(abs_path)
                    results.append(abs_path)
    
    return sorted(results)


def get_folder_stats(path: str, extensions: Optional[Set[str]] = None) -> Tuple[int, int]:
    """
    Get statistics about a folder's convertible files.
    
    Args:
        path: Path to the folder
        extensions: Extensions to count. Defaults to {'.docx', '.xlsx'}
    
    Returns:
        Tuple of (file_count, folder_count) where folder_count is the number
        of subdirectories containing at least one convertible file
    """
    if extensions is None:
        extensions = DEFAULT_EXTENSIONS
    
    if not os.path.isdir(path):
        return (0, 0)
    
    file_count = 0
    folders_with_files: Set[str] = set()
    
    for root, _dirs, files in os.walk(path):
        for filename in files:
            filepath = os.path.join(root, filename)
            if is_convertible_file(filepath, extensions):
                file_count += 1
                folders_with_files.add(root)
    
    return (file_count, len(folders_with_files))
