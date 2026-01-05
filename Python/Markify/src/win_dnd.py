"""
Windows Drag & Drop support using ctypes.
Zero-dependency implementation for accepting file drops.
"""
from __future__ import annotations

import ctypes
import sys
from collections.abc import Callable
from ctypes import wintypes

from logging_config import get_logger

logger = get_logger("dnd")

# Only execute on Windows
if sys.platform != 'win32':
    def hook_window(root_window, callback: Callable[[list[str]], None]) -> None:
        """No-op on non-Windows systems"""
        pass
else:
    # --- Types & Constants ---
    _user32 = ctypes.windll.user32
    _shell32 = ctypes.windll.shell32

    # Check if 64-bit to determine correct pointer size
    is_64bit = sys.maxsize > 2**32

    if is_64bit:
        LONG_PTR = ctypes.c_longlong
    else:
        LONG_PTR = ctypes.c_long

    # Define WNDPROC signature
    WNDPROC = ctypes.WINFUNCTYPE(LONG_PTR, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

    GWL_WNDPROC = -4
    WM_DROPFILES = 0x233

    # --- API Definitions ---

    # SetWindowLongPtr setup
    if hasattr(_user32, "SetWindowLongPtrW"):
        SetWindowLongPtr = _user32.SetWindowLongPtrW
        SetWindowLongPtr.argtypes = [wintypes.HWND, ctypes.c_int, WNDPROC]
        SetWindowLongPtr.restype = LONG_PTR
    else:
        SetWindowLongPtr = _user32.SetWindowLongW
        SetWindowLongPtr.argtypes = [wintypes.HWND, ctypes.c_int, WNDPROC]
        SetWindowLongPtr.restype = LONG_PTR

    CallWindowProc = _user32.CallWindowProcW
    # Note: First argument is LONG_PTR because we are passing the address of the old valid function
    # which we got as a result of SetWindowLongPtr (which is an int/long).
    CallWindowProc.argtypes = [LONG_PTR, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    CallWindowProc.restype = LONG_PTR

    DragAcceptFiles = _shell32.DragAcceptFiles
    DragAcceptFiles.argtypes = [wintypes.HWND, wintypes.BOOL]

    DragQueryFile = _shell32.DragQueryFileW
    DragQueryFile.argtypes = [wintypes.HANDLE, wintypes.UINT, wintypes.LPWSTR, wintypes.UINT]
    DragQueryFile.restype = wintypes.UINT

    DragFinish = _shell32.DragFinish
    DragFinish.argtypes = [wintypes.HANDLE]

    # --- State Management ---
    # We must keep references to C-callback functions to prevent garbage collection
    # from reclaiming them while Windows is still trying to call them (which causes crashes).
    _hook_ref = None         # The new WNDPROC
    _old_wnd_proc = None     # The original WNDPROC address

    def hook_window(root_window, callback):
        """
        Hooks the Tkinter root window to intercept WM_DROPFILES messages.

        Args:
            root_window: The Tkinter root object.
            callback: A function that accepts a list of file paths (strings).
        """
        global _hook_ref, _old_wnd_proc

        # If already hooked, don't do it again (simple safety check)
        if _hook_ref is not None:
            return

        # Get the connection to the window handle
        # update_idletasks is needed to ensure the window has been created and has an HWND
        root_window.update_idletasks()

        hwnd = wintypes.HWND(root_window.winfo_id())

        # Enable Drag & Drop for this window
        DragAcceptFiles(hwnd, True)

        def wnd_proc(hwnd, msg, wParam, lParam):
            if msg == WM_DROPFILES:
                hDrop = wintypes.HANDLE(wParam)

                # 0xFFFFFFFF tells DragQueryFile to return the file count
                count = DragQueryFile(hDrop, 0xFFFFFFFF, None, 0)

                files = []
                for i in range(count):
                    # Get the length of the filename (excluding null terminator)
                    length = DragQueryFile(hDrop, i, None, 0)

                    # Create buffer (+1 for null terminator)
                    buf = ctypes.create_unicode_buffer(length + 1)

                    # Read the filename
                    DragQueryFile(hDrop, i, buf, length + 1)
                    files.append(buf.value)

                # Release memory allocated by Windows
                DragFinish(hDrop)

                # Invoke user callback
                try:
                    callback(files)
                except Exception as e:
                    logger.error(f"Error in Drag&Drop callback: {e}")

                return 0 # Message handled

            # Pass all other messages to the original Window Procedure
            return CallWindowProc(_old_wnd_proc, hwnd, msg, wParam, lParam)

        # Create the C-compatible callback
        _hook_ref = WNDPROC(wnd_proc)

        # Replace the Window Procedure
        _old_wnd_proc = SetWindowLongPtr(hwnd, GWL_WNDPROC, _hook_ref)
