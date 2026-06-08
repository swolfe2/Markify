"""
Git integration utilities for Markify.
Enables automatic staging and committing of converted files.
Zero dependencies - uses only Python built-ins.
"""
from __future__ import annotations

import os
import subprocess  # nosec B404 - Safe: required for Git CLI operations

from logging_config import get_logger

logger = get_logger("git_integration")


def is_git_repository(file_path: str) -> bool:
    """Check if the directory of the file_path is inside a Git repository."""
    dir_path = os.path.dirname(os.path.abspath(file_path))
    if not os.path.isdir(dir_path):
        return False
    try:
        # Run git command
        res = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],  # nosec B603 B607 - Safe: running standard git executable in user CWD
            cwd=dir_path,
            capture_output=True,
            text=True,
            check=False,
        )
        return res.returncode == 0 and res.stdout.strip() == "true"
    except FileNotFoundError:
        logger.warning("Git executable not found on system path.")
        return False
    except Exception as e:
        logger.warning(f"Error checking Git status: {e}")
        return False


def commit_file(file_path: str, source_filename: str) -> tuple[bool, str]:
    """Stage and commit the specified file with a Markify auto-commit message."""
    abs_file = os.path.abspath(file_path)
    dir_path = os.path.dirname(abs_file)
    base_file = os.path.basename(abs_file)

    try:
        # 1. Stage the file
        res_add = subprocess.run(
            ["git", "add", base_file],  # nosec B603 B607 - Safe: staging the generated file in its local directory
            cwd=dir_path,
            capture_output=True,
            text=True,
            check=False,
        )
        if res_add.returncode != 0:
            err = res_add.stderr.strip() or res_add.stdout.strip()
            return False, f"Git add failed: {err}"

        # 2. Commit the file
        commit_msg = f"Markify: converted {source_filename}"
        res_commit = subprocess.run(
            ["git", "commit", "-m", commit_msg],  # nosec B603 B607 - Safe: committing locally with a fixed message format
            cwd=dir_path,
            capture_output=True,
            text=True,
            check=False,
        )
        if res_commit.returncode != 0:
            stdout_str = res_commit.stdout.strip()
            stderr_str = res_commit.stderr.strip()
            combined = f"{stdout_str}\n{stderr_str}"
            if "nothing to commit" in combined.lower() or "no changes added to commit" in combined.lower():
                return True, "No changes to commit (already up to date)."
            return False, f"Git commit failed: {stderr_str or stdout_str}"

        # Extract commit info
        first_line = res_commit.stdout.splitlines()[0] if res_commit.stdout else "Committed successfully"
        return True, first_line
    except FileNotFoundError:
        return False, "Git executable not found."
    except Exception as e:
        logger.error(f"Failed to auto-commit file: {e}")
        return False, str(e)
