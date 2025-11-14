"""Dialog functions for user interactions."""

from tkinter import filedialog, messagebox

import customtkinter as ctk
from constants import DESKTOP_PATH


def prompt_task_name(parent):
    """Show a CTk modal to prompt for a task name.

    Args:
        parent: Parent window

    Returns:
        str or None: Task name if entered, None if cancelled
    """
    dlg = ctk.CTkToplevel(parent)
    dlg.title("Enter Task Name")
    dlg.transient(parent)
    dlg.grab_set()

    try:
        parent.update_idletasks()
        w = 380
        h = 140
        x = parent.winfo_rootx() + (parent.winfo_width() - w) // 2
        y = parent.winfo_rooty() + (parent.winfo_height() - h) // 2
        dlg.geometry(f"{w}x{h}+{x}+{y}")
    except Exception:
        pass

    lbl = ctk.CTkLabel(dlg, text="Please enter a task name:")
    lbl.pack(padx=20, pady=(18, 8))

    entry = ctk.CTkEntry(dlg, placeholder_text="Task name")
    entry.pack(padx=20, pady=8, fill="x")
    entry.focus()

    result = {"name": None}

    def _on_ok():
        result["name"] = entry.get().strip()
        dlg.destroy()

    def _on_cancel():
        dlg.destroy()

    btn_frame = ctk.CTkFrame(dlg)
    btn_frame.pack(pady=(0, 12))

    ok_btn = ctk.CTkButton(btn_frame, text="OK", command=_on_ok)
    ok_btn.pack(side="left", padx=12)

    cancel_btn = ctk.CTkButton(btn_frame, text="Cancel", command=_on_cancel)
    cancel_btn.pack(side="left", padx=12)

    entry.bind("<Return>", lambda e: _on_ok())

    dlg.wait_window()
    return result["name"] if result["name"] else None


def prompt_edit_task_name(parent, current_name):
    """Show a CTk modal to edit an existing task name.

    Args:
        parent: Parent window
        current_name: Current task name to edit

    Returns:
        str or None: New task name if entered, None if cancelled
    """
    dlg = ctk.CTkToplevel(parent)
    dlg.title("Edit Task Name")
    dlg.transient(parent)
    dlg.grab_set()

    try:
        parent.update_idletasks()
        w = 380
        h = 140
        x = parent.winfo_rootx() + (parent.winfo_width() - w) // 2
        y = parent.winfo_rooty() + (parent.winfo_height() - h) // 2
        dlg.geometry(f"{w}x{h}+{x}+{y}")
    except Exception:
        pass

    lbl = ctk.CTkLabel(dlg, text="Enter new task name:")
    lbl.pack(padx=20, pady=(18, 8))

    entry = ctk.CTkEntry(dlg, placeholder_text="Task name")
    if current_name:
        entry.insert(0, current_name)
    entry.pack(padx=20, pady=8, fill="x")
    entry.focus()
    entry.select_range(0, "end")

    result = {"name": None}

    def _on_ok():
        result["name"] = entry.get().strip()
        dlg.destroy()

    def _on_cancel():
        dlg.destroy()

    btn_frame = ctk.CTkFrame(dlg)
    btn_frame.pack(pady=(0, 12))

    ok_btn = ctk.CTkButton(btn_frame, text="OK", command=_on_ok)
    ok_btn.pack(side="left", padx=12)

    cancel_btn = ctk.CTkButton(btn_frame, text="Cancel", command=_on_cancel)
    cancel_btn.pack(side="left", padx=12)

    entry.bind("<Return>", lambda e: _on_ok())

    dlg.wait_window()
    return result["name"] if result["name"] else None


def confirm_delete(parent, task_name):
    """Show a CTk-styled modal confirmation and return True if user confirms.

    Args:
        parent: Parent window
        task_name: Name of task to delete

    Returns:
        bool: True if user confirmed deletion
    """
    dlg = ctk.CTkToplevel(parent)
    dlg.title("Confirm Delete")
    dlg.transient(parent)
    dlg.grab_set()

    # center dialog relative to parent
    try:
        parent.update_idletasks()
        w = 360
        h = 120
        x = parent.winfo_rootx() + (parent.winfo_width() - w) // 2
        y = parent.winfo_rooty() + (parent.winfo_height() - h) // 2
        dlg.geometry(f"{w}x{h}+{x}+{y}")
    except Exception:
        pass

    lbl = ctk.CTkLabel(
        dlg,
        text=f"Delete task '{task_name}' and all its timings?",
        wraplength=320,
    )
    lbl.pack(padx=20, pady=(18, 8))

    btn_frame = ctk.CTkFrame(dlg)
    btn_frame.pack(pady=(0, 12))

    result = {"confirm": False}

    def _on_delete():
        result["confirm"] = True
        dlg.destroy()

    def _on_cancel():
        dlg.destroy()

    del_btn = ctk.CTkButton(
        btn_frame,
        text="Delete",
        fg_color="#D32F2F",
        hover_color="#B71C1C",
        command=_on_delete,
    )
    del_btn.pack(side="left", padx=12)

    cancel_btn = ctk.CTkButton(btn_frame, text="Cancel", command=_on_cancel)
    cancel_btn.pack(side="left", padx=12)

    dlg.wait_window()
    return result["confirm"]


def confirm_delete_all(parent):
    """Show a CTk-styled modal confirmation for deleting all tasks.

    Args:
        parent: Parent window

    Returns:
        bool: True if user confirmed deletion
    """
    dlg = ctk.CTkToplevel(parent)
    dlg.title("Confirm Delete All")
    dlg.transient(parent)
    dlg.grab_set()

    # center dialog relative to parent
    try:
        parent.update_idletasks()
        w = 400
        h = 140
        x = parent.winfo_rootx() + (parent.winfo_width() - w) // 2
        y = parent.winfo_rooty() + (parent.winfo_height() - h) // 2
        dlg.geometry(f"{w}x{h}+{x}+{y}")
    except Exception:
        pass

    lbl = ctk.CTkLabel(
        dlg,
        text="Delete ALL tasks and all their timings?\nThis action cannot be undone.",
        wraplength=360,
    )
    lbl.pack(padx=20, pady=(18, 8))

    btn_frame = ctk.CTkFrame(dlg)
    btn_frame.pack(pady=(0, 12))

    result = {"confirm": False}

    def _on_delete():
        result["confirm"] = True
        dlg.destroy()

    def _on_cancel():
        dlg.destroy()

    del_btn = ctk.CTkButton(
        btn_frame,
        text="Delete All",
        fg_color="#D32F2F",
        hover_color="#B71C1C",
        command=_on_delete,
    )
    del_btn.pack(side="left", padx=12)

    cancel_btn = ctk.CTkButton(btn_frame, text="Cancel", command=_on_cancel)
    cancel_btn.pack(side="left", padx=12)

    dlg.wait_window()
    return result["confirm"]


def show_info(parent, title, message):
    """Show a CTk-styled info dialog.

    Args:
        parent: Parent window
        title: Dialog title
        message: Message to display
    """
    dlg = ctk.CTkToplevel(parent)
    dlg.title(title)
    dlg.transient(parent)
    dlg.grab_set()

    try:
        parent.update_idletasks()
        w = 400
        h = 120
        x = parent.winfo_rootx() + (parent.winfo_width() - w) // 2
        y = parent.winfo_rooty() + (parent.winfo_height() - h) // 2
        dlg.geometry(f"{w}x{h}+{x}+{y}")
    except Exception:
        pass

    lbl = ctk.CTkLabel(dlg, text=message, wraplength=360)
    lbl.pack(padx=20, pady=(18, 8))

    btn_frame = ctk.CTkFrame(dlg)
    btn_frame.pack(pady=(0, 12))

    def _on_ok():
        dlg.destroy()

    ok_btn = ctk.CTkButton(btn_frame, text="OK", command=_on_ok)
    ok_btn.pack(side="left", padx=12)

    dlg.wait_window()


def show_warning(parent, title, message):
    """Show a CTk-styled warning dialog.

    Args:
        parent: Parent window
        title: Dialog title
        message: Message to display
    """
    dlg = ctk.CTkToplevel(parent)
    dlg.title(title)
    dlg.transient(parent)
    dlg.grab_set()

    try:
        parent.update_idletasks()
        w = 400
        h = 140
        x = parent.winfo_rootx() + (parent.winfo_width() - w) // 2
        y = parent.winfo_rooty() + (parent.winfo_height() - h) // 2
        dlg.geometry(f"{w}x{h}+{x}+{y}")
    except Exception:
        pass

    lbl = ctk.CTkLabel(dlg, text=message, wraplength=360)
    lbl.pack(padx=20, pady=(18, 8))

    btn_frame = ctk.CTkFrame(dlg)
    btn_frame.pack(pady=(0, 12))

    def _on_ok():
        dlg.destroy()

    ok_btn = ctk.CTkButton(btn_frame, text="OK", command=_on_ok)
    ok_btn.pack(side="left", padx=12)

    dlg.wait_window()


def show_error(parent, title, message):
    """Show a CTk-styled error dialog.

    Args:
        parent: Parent window
        title: Dialog title
        message: Message to display
    """
    dlg = ctk.CTkToplevel(parent)
    dlg.title(title)
    dlg.transient(parent)
    dlg.grab_set()

    try:
        parent.update_idletasks()
        w = 400
        h = 140
        x = parent.winfo_rootx() + (parent.winfo_width() - w) // 2
        y = parent.winfo_rooty() + (parent.winfo_height() - h) // 2
        dlg.geometry(f"{w}x{h}+{x}+{y}")
    except Exception:
        pass

    lbl = ctk.CTkLabel(dlg, text=message, wraplength=360)
    lbl.pack(padx=20, pady=(18, 8))

    btn_frame = ctk.CTkFrame(dlg)
    btn_frame.pack(pady=(0, 12))

    def _on_ok():
        dlg.destroy()

    ok_btn = ctk.CTkButton(
        btn_frame,
        text="OK",
        fg_color="#D32F2F",
        hover_color="#B71C1C",
        command=_on_ok,
    )
    ok_btn.pack(side="left", padx=12)

    dlg.wait_window()


def export_dialog(parent, perform_export_callback):
    """Show themed dialog for filename, formats, directory, then export.

    Args:
        parent: Parent window
        perform_export_callback: Function to call with (out_dir, name, formats)
    """
    dlg = ctk.CTkToplevel(parent)
    dlg.title("Export Tasks")
    dlg.transient(parent)
    dlg.grab_set()

    # Center dialog roughly
    try:
        parent.update_idletasks()
        w = 480
        h = 240
        x = parent.winfo_x() + (parent.winfo_width() - w) // 2
        y = parent.winfo_y() + (parent.winfo_height() - h) // 2
        dlg.geometry(f"{w}x{h}+{x}+{y}")
    except Exception:
        pass

    frm = ctk.CTkFrame(dlg)
    frm.pack(fill="both", expand=True, padx=12, pady=(12, 8))

    ctk.CTkLabel(frm, text="Filename (no extension):").grid(row=0, column=0, sticky="w")
    name_var = ctk.StringVar(value="task_times")
    name_entry = ctk.CTkEntry(frm, textvariable=name_var)
    name_entry.grid(row=0, column=1, sticky="ew", padx=(8, 0))
    frm.grid_columnconfigure(1, weight=1)

    ctk.CTkLabel(frm, text="Export Formats:").grid(
        row=1, column=0, sticky="w", pady=(8, 0)
    )
    csv_var = ctk.BooleanVar(value=True)
    json_var = ctk.BooleanVar(value=False)
    xlsx_var = ctk.BooleanVar(value=False)
    cb_csv = ctk.CTkCheckBox(frm, text="CSV", variable=csv_var)
    cb_json = ctk.CTkCheckBox(frm, text="JSON", variable=json_var)
    cb_xlsx = ctk.CTkCheckBox(frm, text="XLSX", variable=xlsx_var)
    cb_csv.grid(row=1, column=1, sticky="w")
    cb_json.grid(row=1, column=1, sticky="w", padx=(70, 0))
    cb_xlsx.grid(row=1, column=1, sticky="w", padx=(150, 0))

    # directory selector
    dir_var = ctk.StringVar(value=DESKTOP_PATH)

    def _choose_dir():
        p = filedialog.askdirectory(initialdir=DESKTOP_PATH)
        if p:
            dir_var.set(p)

    ctk.CTkLabel(frm, text="Directory:").grid(row=2, column=0, sticky="w", pady=(8, 0))
    dir_lbl = ctk.CTkLabel(frm, textvariable=dir_var, anchor="w", justify="left")
    dir_lbl.grid(row=2, column=1, sticky="nw", padx=(4, 0), pady=(20, 0))
    frm.grid_columnconfigure(1, weight=1)

    dir_btn = ctk.CTkButton(frm, text="Browse...", command=_choose_dir, width=96)
    dir_btn.grid(row=3, column=0, columnspan=2, pady=(20, 0))

    btn_frame = ctk.CTkFrame(frm, fg_color="transparent")
    btn_frame.grid(row=4, column=0, columnspan=2, pady=(20, 0))

    def _on_export():
        name = name_var.get().strip()
        formats = []
        if csv_var.get():
            formats.append("csv")
        if json_var.get():
            formats.append("json")
        if xlsx_var.get():
            formats.append("xlsx")
        if not name:
            messagebox.showerror("Export", "Please provide a filename.")
            return
        if not formats:
            messagebox.showerror("Export", "Please select at least one format.")
            return
        out_dir = dir_var.get()
        dlg.grab_release()
        dlg.destroy()
        perform_export_callback(out_dir, name, formats)

    def _on_cancel():
        dlg.grab_release()
        dlg.destroy()

    exp_btn = ctk.CTkButton(btn_frame, text="Export", command=_on_export)
    exp_btn.pack(side="right", padx=12)
    cancel_btn = ctk.CTkButton(btn_frame, text="Cancel", command=_on_cancel)
    cancel_btn.pack(side="left", padx=12)

    dlg.wait_window()


def prompt_session_name(parent, current_name=None):
    """Show a CTk modal to prompt for a session name.

    Args:
        parent: Parent window
        current_name: Current session name (if editing)

    Returns:
        str or None: Session name if entered, None if cancelled,
        empty string to use default
    """
    dlg = ctk.CTkToplevel(parent)
    dlg.title("Edit Session Name")
    dlg.transient(parent)
    dlg.grab_set()

    try:
        parent.update_idletasks()
        w = 400
        h = 160
        x = parent.winfo_rootx() + (parent.winfo_width() - w) // 2
        y = parent.winfo_rooty() + (parent.winfo_height() - h) // 2
        dlg.geometry(f"{w}x{h}+{x}+{y}")
    except Exception:
        pass

    lbl = ctk.CTkLabel(
        dlg,
        text=(
            "Enter session name "
            "(leave empty for default 'Session N'):"
        ),
    )
    lbl.pack(padx=20, pady=(18, 8))

    entry = ctk.CTkEntry(dlg, placeholder_text="Session name")
    if current_name:
        entry.insert(0, current_name)
    entry.pack(padx=20, pady=8, fill="x")
    entry.focus()

    result = {"name": None}

    def _on_ok():
        name = entry.get().strip()
        # Empty string means use default, None means cancelled
        result["name"] = name if name else ""
        dlg.destroy()

    def _on_cancel():
        dlg.destroy()

    btn_frame = ctk.CTkFrame(dlg)
    btn_frame.pack(pady=(0, 12))

    ok_btn = ctk.CTkButton(btn_frame, text="OK", command=_on_ok)
    ok_btn.pack(side="left", padx=12)

    cancel_btn = ctk.CTkButton(btn_frame, text="Cancel", command=_on_cancel)
    cancel_btn.pack(side="left", padx=12)

    entry.bind("<Return>", lambda e: _on_ok())

    dlg.wait_window()
    return result.get("name")


def prompt_note(parent, current_note=None, title="Edit Note"):
    """Show a CTk modal to prompt for a note.

    Args:
        parent: Parent window
        current_note: Current note text (if editing)
        title: Dialog title

    Returns:
        str or None: Note text if entered, None if cancelled, empty string to clear
    """
    dlg = ctk.CTkToplevel(parent)
    dlg.title(title)
    dlg.transient(parent)
    dlg.grab_set()

    try:
        parent.update_idletasks()
        w = 450
        h = 220
        x = parent.winfo_rootx() + (parent.winfo_width() - w) // 2
        y = parent.winfo_rooty() + (parent.winfo_height() - h) // 2
        dlg.geometry(f"{w}x{h}+{x}+{y}")
    except Exception:
        pass

    lbl = ctk.CTkLabel(dlg, text="Enter note (leave empty to remove note):")
    lbl.pack(padx=20, pady=(18, 8))

    # Use CTkTextbox for multi-line notes
    textbox = ctk.CTkTextbox(dlg, height=80)
    if current_note:
        textbox.insert("1.0", current_note)
    textbox.pack(padx=20, pady=8, fill="both", expand=True)
    textbox.focus()

    result = {"note": None}

    def _on_ok():
        note = textbox.get("1.0", "end-1c").strip()
        # Empty string means clear note, None means cancelled
        result["note"] = note if note else ""
        dlg.destroy()

    def _on_cancel():
        dlg.destroy()

    btn_frame = ctk.CTkFrame(dlg)
    btn_frame.pack(pady=(0, 12))

    ok_btn = ctk.CTkButton(btn_frame, text="OK", command=_on_ok)
    ok_btn.pack(side="left", padx=12)

    cancel_btn = ctk.CTkButton(btn_frame, text="Cancel", command=_on_cancel)
    cancel_btn.pack(side="left", padx=12)

    dlg.wait_window()
    return result.get("note")
