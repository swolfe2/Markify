"""Export functions for writing tasks to CSV, JSON, and XLSX formats."""

import csv
import json
import os
from datetime import datetime


def perform_export(tasks, out_dir, name, formats, parent=None):
    """Write selected formats for completed tasks to the chosen directory.

    Supports csv and json out of the box. Attempts to write xlsx using
    pandas or openpyxl if available; otherwise notifies the user.

    Args:
        tasks: Dictionary of Task objects
        out_dir: Output directory path
        name: Base filename (without extension)
        formats: List of format strings ("csv", "json", "xlsx")
        parent: Parent window for dialogs (optional, for themed dialogs)
    """
    # Import here to avoid circular dependencies
    if parent:
        from ui import show_error, show_info
    else:
        from tkinter import messagebox

    completed_tasks = [t for t in tasks.values() if t.status == "Completed"]
    if not completed_tasks:
        if parent:
            show_info(parent, "Export", "No completed tasks to export.")
        else:
            messagebox.showinfo("Export", "No completed tasks to export.")
        return

    # Determine whether the user entered a full path in the name box.
    if os.path.isabs(name) or os.path.dirname(name):
        abs_path = os.path.abspath(name)
        base_dir = os.path.dirname(abs_path)
        base_name = os.path.splitext(os.path.basename(abs_path))[0]
    else:
        base_dir = out_dir
        base_name = name

    # Ensure output directory exists (try to create if missing)
    try:
        os.makedirs(base_dir, exist_ok=True)
    except Exception as e:
        if parent:
            show_error(parent, "Export", f"Output directory unavailable: {e}")
        else:
            messagebox.showerror("Export", f"Output directory unavailable: {e}")
        return

    rows = []
    for task in completed_tasks:
        # Get task note - use direct attribute access
        # Debug: Check if note attribute exists and its value
        task_note = task.note if hasattr(task, "note") and task.note else ""
        for i, entry in enumerate(task.timings):
            start_str = entry.get("start")
            end_str = entry.get("end")
            start = (
                datetime.fromisoformat(start_str) if start_str else None
            )
            end = datetime.fromisoformat(end_str) if end_str else None
            duration = (
                int((end - start).total_seconds()) if start and end else ""
            )
            # Use custom session name if available, otherwise default
            session_name = (
                entry.get("name") if entry.get("name") else f"Session {i + 1}"
            )
            # Get session note - handle both key and None cases
            session_note = entry.get("note") if entry.get("note") else ""
            start_time_str = (
                start.strftime("%Y-%m-%d %H:%M:%S") if start else ""
            )
            end_time_str = (
                end.strftime("%Y-%m-%d %H:%M:%S") if end else ""
            )
            rows.append(
                {
                    "Task Name": task.name,
                    "Session": session_name,
                    "Start Time": start_time_str,
                    "End Time": end_time_str,
                    "Duration (seconds)": duration,
                    "Session Note": session_note,
                    "Task Note": task_note,
                }
            )

    # CSV
    if "csv" in formats:
        csv_path = os.path.join(base_dir, f"{base_name}.csv")
        try:
            with open(csv_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(
                    [
                        "Task Name",
                        "Session",
                        "Start Time",
                        "End Time",
                        "Duration (seconds)",
                        "Session Note",
                        "Task Note",
                    ]
                )
                for r in rows:
                    writer.writerow(
                        [
                            r["Task Name"],
                            r["Session"],
                            r["Start Time"],
                            r["End Time"],
                            r["Duration (seconds)"],
                            r["Session Note"],
                            r["Task Note"],
                        ]
                    )
        except Exception as e:
            if parent:
                show_error(parent, "Export", f"CSV export failed: {e}")
            else:
                messagebox.showerror("Export", f"CSV export failed: {e}")
            # Don't return - continue with other formats

    # JSON
    if "json" in formats:
        json_path = os.path.join(base_dir, f"{base_name}.json")
        try:
            with open(json_path, "w", encoding="utf-8") as f:
                json.dump(rows, f, indent=2)
        except Exception as e:
            if parent:
                show_error(parent, "Export", f"JSON export failed: {e}")
            else:
                messagebox.showerror("Export", f"JSON export failed: {e}")
            # Don't return - continue with other formats

    # XLSX - try pandas then openpyxl
    if "xlsx" in formats:
        xlsx_path = os.path.join(base_dir, f"{base_name}.xlsx")
        wrote_xlsx = False

        # Try pandas first (requires openpyxl as dependency)
        try:
            import pandas as pd

            # Check if openpyxl is available for pandas
            try:
                import importlib.util

                if importlib.util.find_spec("openpyxl") is None:
                    raise ImportError("pandas requires openpyxl for Excel export")
            except ImportError:
                raise ImportError("pandas requires openpyxl for Excel export")

            df = pd.DataFrame(rows)
            xlsx_path_abs = os.path.abspath(xlsx_path)
            df.to_excel(xlsx_path_abs, index=False, engine="openpyxl")
            if os.path.exists(xlsx_path_abs):
                wrote_xlsx = True
            else:
                raise Exception("File was not created after pandas save")
        except ImportError:
            # pandas or openpyxl not available, try openpyxl directly
            pass
        except Exception:
            # pandas failed for another reason, try openpyxl directly
            pass

        # Fallback to openpyxl directly
        if not wrote_xlsx:
            try:
                from openpyxl import Workbook

                wb = Workbook()
                ws = wb.active
                # Write header row
                header = [
                    "Task Name",
                    "Session",
                    "Start Time",
                    "End Time",
                    "Duration (seconds)",
                    "Session Note",
                    "Task Note",
                ]
                ws.append(header)

                # Write data rows - ensure all values are strings or numbers
                for r in rows:
                    duration_val = r.get("Duration (seconds)", 0)
                    duration_num = (
                        duration_val
                        if isinstance(duration_val, (int, float))
                        else 0
                    )
                    row_data = [
                        str(r.get("Task Name", "")),
                        str(r.get("Session", "")),
                        str(r.get("Start Time", "")),
                        str(r.get("End Time", "")),
                        duration_num,
                        str(r.get("Session Note", "")),
                        str(r.get("Task Note", "")),
                    ]
                    ws.append(row_data)

                # Save the workbook - use absolute path
                xlsx_path_abs = os.path.abspath(xlsx_path)
                try:
                    wb.save(xlsx_path_abs)
                except PermissionError as perm_err:
                    error_msg = (
                        f"Permission denied saving XLSX file.\n"
                        f"Path: {xlsx_path_abs}\n"
                        f"Error: {str(perm_err)}\n\n"
                        "The file may be open in another program."
                    )
                    if parent:
                        show_error(parent, "Export", error_msg)
                    else:
                        messagebox.showerror("Export", error_msg)
                    return
                except Exception as save_error:
                    error_msg = (
                        f"Failed to save XLSX file.\n"
                        f"Path: {xlsx_path_abs}\n"
                        f"Error: {str(save_error)}\n\n"
                        "Check file permissions and disk space."
                    )
                    if parent:
                        show_error(parent, "Export", error_msg)
                    else:
                        messagebox.showerror("Export", error_msg)
                    return

                # Verify file was created (check both paths)
                if not os.path.exists(xlsx_path_abs) and not os.path.exists(
                    xlsx_path
                ):
                    dir_exists = os.path.exists(base_dir)
                    dir_writable = (
                        os.access(base_dir, os.W_OK)
                        if dir_exists
                        else "N/A"
                    )
                    error_msg = (
                        f"XLSX file was not created.\n"
                        f"Expected path: {xlsx_path_abs}\n"
                        f"Directory exists: {dir_exists}\n"
                        f"Directory writable: {dir_writable}\n\n"
                        "Check file permissions and disk space."
                    )
                    if parent:
                        show_error(parent, "Export", error_msg)
                    else:
                        messagebox.showerror("Export", error_msg)
                    return

                wrote_xlsx = True
            except ImportError as import_err:
                msg = (
                    f"XLSX export failed: openpyxl is not available "
                    f"({str(import_err)}). "
                    "Install openpyxl to enable xlsx exports."
                )
                if parent:
                    show_error(parent, "Export", msg)
                else:
                    messagebox.showerror("Export", msg)
            except Exception as e:
                import traceback

                error_details = traceback.format_exc()
                msg = (
                    f"XLSX export failed: {str(e)}\n\n"
                    f"Details: {error_details}\n\n"
                    "Make sure openpyxl is installed and "
                    "the output directory is writable."
                )
                if parent:
                    show_error(parent, "Export", msg)
                else:
                    messagebox.showerror("Export", msg)
                # Don't return - continue to show success for other formats

        # Report XLSX status - if we requested XLSX but didn't write it
        if "xlsx" in formats and not wrote_xlsx:
            # Error already shown above, but continue to show success for other formats
            pass

    # Show success message - include info about which formats succeeded
    formats_succeeded = []
    if "csv" in formats:
        csv_file = os.path.join(base_dir, f"{base_name}.csv")
        if os.path.exists(csv_file):
            formats_succeeded.append("CSV")
    if "json" in formats:
        json_file = os.path.join(base_dir, f"{base_name}.json")
        if os.path.exists(json_file):
            formats_succeeded.append("JSON")
    if "xlsx" in formats:
        xlsx_file = os.path.join(base_dir, f"{base_name}.xlsx")
        if os.path.exists(xlsx_file):
            formats_succeeded.append("XLSX")

    if formats_succeeded:
        formats_str = ", ".join(formats_succeeded)
        success_msg = (
            f"Export completed to: {base_dir}\nFormats: {formats_str}"
        )
        if parent:
            show_info(parent, "Export", success_msg)
        else:
            messagebox.showinfo("Export", success_msg)
    else:
        # No formats succeeded
        error_msg = (
            "All export formats failed. Check error messages above."
        )
        if parent:
            show_error(parent, "Export", error_msg)
        else:
            messagebox.showerror("Export", error_msg)
