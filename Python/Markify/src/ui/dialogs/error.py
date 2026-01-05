"""
Error dialog for Markify.
Displays error messages with details and hints.
"""
import tkinter as tk


def show_error_dialog(
    parent: tk.Tk,
    colors: dict[str, str],
    title: str = "Error",
    message: str = "An error occurred",
    details: str = "",
    hint: str = "",
    icon_path: str = None
) -> None:
    """
    Show a modern styled error dialog.

    Args:
        parent: Parent Tk window (for centering).
        colors: Theme color dictionary.
        title: Dialog window title.
        message: Main error message.
        details: Optional detailed error information.
        hint: Optional hint for resolution.
        icon_path: Path to application icon.
    """
    c = colors
    dialog = tk.Toplevel(parent)
    dialog.title(title)
    dialog.geometry("500x280")
    dialog.configure(bg=c["bg"])
    dialog.resizable(False, False)

    # Set icon if provided
    if icon_path:
        try:
            dialog.iconbitmap(icon_path)
        except Exception:  # nosec B110 - Safe: icon loading is optional, gracefully degrade
            pass

    # Center on parent
    dialog.transient(parent)
    x = parent.winfo_x() + (parent.winfo_width() // 2) - 250
    y = parent.winfo_y() + (parent.winfo_height() // 2) - 140
    dialog.geometry(f"+{x}+{y}")

    # Main frame with padding
    main_frame = tk.Frame(dialog, bg=c["bg"], padx=30, pady=25)
    main_frame.pack(fill="both", expand=True)

    # Error icon and title row
    title_frame = tk.Frame(main_frame, bg=c["bg"])
    title_frame.pack(fill="x", pady=(0, 15))

    icon_label = tk.Label(title_frame, text="⚠️", font=("Segoe UI", 32), bg=c["bg"], fg=c["error"])
    icon_label.pack(side="left", padx=(0, 15))

    title_label = tk.Label(title_frame, text=message, font=("Segoe UI", 14, "bold"),
                           bg=c["bg"], fg=c["fg"], wraplength=350, justify="left")
    title_label.pack(side="left", fill="x", expand=True)

    # Details section
    if details:
        details_frame = tk.Frame(main_frame, bg=c["secondary_bg"], padx=15, pady=12)
        details_frame.pack(fill="x", pady=(0, 10))

        details_label = tk.Label(details_frame, text=details, font=("Segoe UI", 11),
                                 bg=c["secondary_bg"], fg=c["fg"], wraplength=420, justify="left")
        details_label.pack(fill="x")

    # Hint section
    if hint:
        hint_label = tk.Label(main_frame, text=f"💡 {hint}", font=("Segoe UI", 10),
                              bg=c["bg"], fg=c["accent"], wraplength=420, justify="left")
        hint_label.pack(fill="x", pady=(5, 15))

    # OK button
    btn_frame = tk.Frame(main_frame, bg=c["bg"])
    btn_frame.pack(fill="x", pady=(10, 0))

    ok_btn = tk.Button(btn_frame, text="OK", font=("Segoe UI", 11),
                      bg=c["accent"], fg="#ffffff", activebackground=c["accent_hover"],
                      activeforeground="#ffffff", relief="flat", padx=30, pady=8,
                      cursor="hand2", command=dialog.destroy)
    ok_btn.pack(side="right")
    dialog.wait_window()
