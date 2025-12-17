"""
Success dialog for Markify.
Displays conversion results and provides open/preview actions.
"""
import os
import subprocess  # nosec B404
import threading
import webbrowser
import tkinter as tk
from tkinter import ttk, messagebox
from typing import Callable, Dict, List


def show_success_dialog(
    parent: tk.Tk,
    colors: Dict[str, str],
    path_arg: str,
    single_mode: bool = True,
    count: int = 0,
    on_run_cmd: Callable[[List[str]], None] = None
) -> None:
    """
    Show a success dialog after conversion.
    
    Args:
        parent: Parent Tk window (for centering and clipboard).
        colors: Theme color dictionary.
        path_arg: File path (single mode) or folder path (batch mode).
        single_mode: True for single file, False for batch.
        count: Number of files converted in batch mode.
        on_run_cmd: Callback to run external commands (e.g., open in VS Code).
    """
    c = colors
    dialog = tk.Toplevel(parent)
    dialog.title("Success")
    dialog.geometry("650x300")
    dialog.configure(bg=c["bg"])
    
    # Center
    x = parent.winfo_x() + (parent.winfo_width() // 2) - 325
    y = parent.winfo_y() + (parent.winfo_height() // 2) - 150
    dialog.geometry(f"+{x}+{y}")

    if single_mode:
        msg = "✔ Conversion Successful"
        sub_msg = "File saved to:"
        path_val = path_arg
    else:
        msg = f"✔ Batch Complete ({count} files)"
        sub_msg = "Files saved to folder:"
        path_val = path_arg

    # Success Icon/Text
    ttk.Label(dialog, text=msg, style="Success.TLabel").pack(pady=(20, 5))
    
    # File Saved As Label
    ttk.Label(dialog, text=sub_msg, style="Sub.TLabel").pack()
    
    # Clickable Full Path
    path_font = ("Consolas", 9, "underline")
    abs_path = os.path.abspath(path_val)
    
    path_lbl = tk.Label(
        dialog, 
        text=abs_path, 
        bg=c["bg"], 
        fg=c["accent"],
        font=path_font,
        cursor="hand2",
        wraplength=600,
        justify="center"
    )
    path_lbl.pack(pady=5, padx=20)
    
    # Bind click to open folder
    def open_folder(event=None):
        if single_mode:
            subprocess.Popen(f'explorer /select,"{abs_path}"', shell=True)  # nosec B602
        else:
            subprocess.Popen(f'explorer "{abs_path}"', shell=True)  # nosec B602
            
    path_lbl.bind("<Button-1>", open_folder)
    
    # Tooltip
    tk.Label(dialog, text="(Click path to open folder)", bg=c["bg"], fg=c["muted"], 
             font=("Segoe UI", 8)).pack(pady=(0, 15))

    # Buttons
    btn_frame = tk.Frame(dialog, bg=c["bg"])
    btn_frame.pack(pady=10, fill=tk.X, padx=40)

    def btn_style(bg, fg="#ffffff"): 
        return {
            "font": ("Segoe UI", 10), "bg": bg, "fg": fg, 
            "activebackground": c["border"], "activeforeground": fg, 
            "relief": tk.FLAT, "cursor": "hand2", "pady": 8
        }

    # Row for Open Buttons (Only in single mode)
    if single_mode:
        open_btns_frame = tk.Frame(btn_frame, bg=c["bg"])
        open_btns_frame.pack(fill=tk.X, pady=(0, 5))

        tk.Button(
            open_btns_frame, text="Open in VS Code", 
            command=lambda: on_run_cmd(["code", path_arg]) if on_run_cmd else None,
            **btn_style(c["accent"]), width=20
        ).pack(side=tk.LEFT, padx=(0, 10), expand=True, fill=tk.X)
        
        tk.Button(
            open_btns_frame, text="Open in Notepad", 
            command=lambda: on_run_cmd(["notepad", path_arg]) if on_run_cmd else None,
            **btn_style(c["secondary_bg"], c["fg"]), width=20
        ).pack(side=tk.LEFT, expand=True, fill=tk.X)
        
        # Preview in Browser Button
        def preview_in_browser():
            try:
                with open(path_arg, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                parent.clipboard_clear()
                parent.clipboard_append(content)
                parent.update()
                
                def open_web():
                    webbrowser.open("https://markdownlivepreview.com/")
                threading.Thread(target=open_web, daemon=True).start()
                
                # Copied confirmation dialog
                msg_win = tk.Toplevel(dialog)
                msg_win.title("Copied!")
                msg_win.configure(bg=c["bg"])
                msg_win.attributes('-topmost', True)
                
                w, h = 400, 240
                x_pos = dialog.winfo_x() + (dialog.winfo_width() // 2) - (w // 2)
                y_pos = dialog.winfo_y() + (dialog.winfo_height() // 2) - (h // 2)
                msg_win.geometry(f"{w}x{h}+{x_pos}+{y_pos}")
                
                ttk.Label(msg_win, text="Markdown Copied!", style="Success.TLabel").pack(pady=(20, 15))
                
                instructions = (
                    "1. Browser is opening (might take a second).\n"
                    "2. Click on the left side of the editor to enter text.\n"
                    "3. Press Ctrl+V to paste."
                )
                
                ttk.Label(
                    msg_win, 
                    text=instructions, 
                    style="Body.TLabel", 
                    justify=tk.LEFT
                ).pack(pady=(0, 20), padx=20, anchor=tk.W)
                
                tk.Button(
                    msg_win, text="Got it!", command=msg_win.destroy,
                    **btn_style(c["accent"]), width=15
                ).pack(pady=(0, 5))
                
                timer_lbl = tk.Label(msg_win, text="", bg=c["bg"], fg=c["muted"], font=("Segoe UI", 8))
                timer_lbl.pack(pady=(10, 0))
                
                def countdown(count):
                    if not msg_win.winfo_exists():
                        return
                    if count <= 0:
                        msg_win.destroy()
                        return
                    
                    unit = "second" if count == 1 else "seconds"
                    timer_lbl.config(text=f"Message will close in {count} {unit}")
                    msg_win.after(1000, countdown, count - 1)
                    
                countdown(30)
                msg_win.focus_force()
                
            except Exception as e:
                messagebox.showerror("Error", str(e))
                
        tk.Button(
            btn_frame, text="🌐 Preview in Browser", command=preview_in_browser,
            **btn_style("#2d5a27")
        ).pack(fill=tk.X, pady=(5, 10))
    
    # Close Button
    tk.Button(
        btn_frame, text="Close", command=dialog.destroy,
        **btn_style("#555555") 
    ).pack(fill=tk.X)
