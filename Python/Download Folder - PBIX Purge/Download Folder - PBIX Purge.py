"""
PBIX Purge Utility — Enhanced (Safe Delete by Default)

Default behavior:
  • SAFE DELETE (send files to Recycle Bin via send2trash) and overwrite a single log file
  • If send2trash is not installed, falls back to PERMANENT delete (and logs a warning)

Flags:
  --dry-run                 Preview only; do not delete
  --mode {safe,permanent}   Choose deletion mode (default: safe)
  --downloads-path PATH     Override target Downloads folder
  --log-dir PATH            Override directory for logs
  --log-mode {overwrite,timestamp}  Log file strategy (default: overwrite)

Exit codes:
  0 = success, 1 = completed with errors, 2 = downloads folder missing

Author: Steve Wolfe
"""

import argparse
import os
from datetime import datetime

try:
    from send2trash import send2trash  # type: ignore
except Exception:  # pragma: no cover
    send2trash = None

EXT = ".pbix"
DEFAULT_LOG_NAME = "PBIX_Purge_Log.txt"


def default_downloads_path() -> str:
    username = os.environ.get("USERNAME", "")
    return os.path.join("C:\\Users", username, "OneDrive - Kimberly-Clark", "Downloads")


def default_log_dir() -> str:
    username = os.environ.get("USERNAME", "")
    return os.path.join(
        "C:\\Users",
        username,
        "OneDrive - Kimberly-Clark",
        "Desktop",
        "Code",
        "Python",
        "Download Folder - PBIX Purge",
    )


def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def find_target_files(folder: str) -> list[str]:
    if not os.path.exists(folder):
        return []
    return [f for f in os.listdir(folder) if f.lower().endswith(EXT)]


def delete_files(
    folder: str, names: list[str], dry_run: bool, mode: str
) -> tuple[list[str], list[str]]:
    """Delete or simulate deleting the provided files.

    Returns (deleted_list, errors_list)
    """
    deleted: list[str] = []
    errors: list[str] = []

    for name in names:
        full = os.path.join(folder, name)
        if dry_run:
            deleted.append(f"[DRY RUN] {name}")
            continue
        try:
            if mode == "safe" and send2trash is not None:
                send2trash(full)
            else:
                # Either permanent mode OR safe requested but send2trash unavailable
                os.remove(full)
            deleted.append(name)
        except OSError as e:
            errors.append(f"Error deleting {name}: {e}")
    return deleted, errors


def write_log(
    log_dir: str,
    log_mode: str,
    downloads_folder: str,
    dry_run: bool,
    mode: str,
    names: list[str],
    deleted: list[str],
    errors: list[str],
) -> str:
    ensure_dir(log_dir)
    now = datetime.now()
    if log_mode == "timestamp":
        log_path = os.path.join(
            log_dir, f"PBIX_Purge_Log_{now.strftime('%Y%m%d_%H%M')}.txt"
        )
    else:
        log_path = os.path.join(log_dir, DEFAULT_LOG_NAME)

    with open(log_path, "w", encoding="utf-8") as log:
        log.write(f"PBIX Purge Run: {now.isoformat(timespec='seconds')}\n")
        log.write(f"Target folder: {downloads_folder}\n")
        # Effective mode description
        if dry_run:
            log.write("Mode: DRY RUN (no deletions performed)\n")
        else:
            if mode == "safe" and send2trash is not None:
                log.write("Mode: SAFE DELETE (Recycle Bin)\n")
            elif mode == "safe" and send2trash is None:
                log.write(
                    "Mode: SAFE DELETE requested but send2trash not installed — performed PERMANENT delete\n"
                )
            else:
                log.write("Mode: PERMANENT delete\n")
        log.write("\n")

        if dry_run:
            log.write(f"Total {EXT} files found: {len(names)}\n")
        else:
            log.write(
                f"Total {EXT} files deleted: {len([d for d in deleted if not d.startswith('[DRY RUN]')])}\n"
            )

        if dry_run and names:
            log.write("Files (preview):\n")
            for n in names:
                log.write(f"- {n}\n")
        elif deleted:
            log.write("Deleted files:\n")
            for name in deleted:
                log.write(f"- {name}\n")
        else:
            log.write(f"No {EXT} files {'found' if dry_run else 'deleted'}.\n")

        if errors:
            log.write("\nErrors:\n")
            for err in errors:
                log.write(f"- {err}\n")

    return log_path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="PBIX Purge Utility (safe delete by default)"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="List files without deleting"
    )
    parser.add_argument(
        "--mode",
        choices=["safe", "permanent"],
        default="safe",
        help="Deletion mode (default: safe)",
    )
    parser.add_argument(
        "--downloads-path",
        default=default_downloads_path(),
        help="Path to the Downloads folder to scan",
    )
    parser.add_argument(
        "--log-dir",
        default=default_log_dir(),
        help="Directory where the log file will be written",
    )
    parser.add_argument(
        "--log-mode",
        choices=["overwrite", "timestamp"],
        default="overwrite",
        help="'overwrite' writes PBIX_Purge_Log.txt; 'timestamp' creates a dated file",
    )

    args = parser.parse_args()

    downloads_folder = args.downloads_path
    log_dir = args.log_dir

    if not os.path.exists(downloads_folder):
        ensure_dir(log_dir)
        # Maintain original behavior: when missing, write a simple message
        log_name = (
            DEFAULT_LOG_NAME
            if args.log_mode == "overwrite"
            else f"PBIX_Purge_Log_{datetime.now().strftime('%Y%m%d_%H%M')}.txt"
        )
        log_path = os.path.join(log_dir, log_name)
        with open(log_path, "w", encoding="utf-8") as log:
            log.write(f"Downloads folder not found at: {downloads_folder}\n")
        print(
            f"Downloads folder not found: {downloads_folder}\nLog written: {log_path}"
        )
        return 2

    names = find_target_files(downloads_folder)

    deleted, errors = delete_files(downloads_folder, names, args.dry_run, args.mode)

    log_path = write_log(
        log_dir,
        args.log_mode,
        downloads_folder,
        args.dry_run,
        args.mode,
        names,
        deleted,
        errors,
    )

    print(f"PBIX purge complete. Log: {log_path}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
