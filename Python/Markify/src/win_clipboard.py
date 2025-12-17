"""
Windows clipboard HTML access using ctypes.
Zero dependencies - uses only Python standard library.
"""
from __future__ import annotations

import ctypes
from ctypes import wintypes
from typing import Optional
import re

from logging_config import get_logger

logger = get_logger("win_clipboard")

# Windows API constants
CF_HTML = None  # Will be registered
CF_TEXT = 1
CF_UNICODETEXT = 13

# Windows API functions
user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

OpenClipboard = user32.OpenClipboard
OpenClipboard.argtypes = [wintypes.HWND]
OpenClipboard.restype = wintypes.BOOL

CloseClipboard = user32.CloseClipboard
CloseClipboard.argtypes = []
CloseClipboard.restype = wintypes.BOOL

GetClipboardData = user32.GetClipboardData
GetClipboardData.argtypes = [wintypes.UINT]
GetClipboardData.restype = wintypes.HANDLE

GlobalLock = kernel32.GlobalLock
GlobalLock.argtypes = [wintypes.HANDLE]
GlobalLock.restype = ctypes.c_void_p

GlobalUnlock = kernel32.GlobalUnlock
GlobalUnlock.argtypes = [wintypes.HANDLE]
GlobalUnlock.restype = wintypes.BOOL

GlobalSize = kernel32.GlobalSize
GlobalSize.argtypes = [wintypes.HANDLE]
GlobalSize.restype = ctypes.c_size_t

RegisterClipboardFormatW = user32.RegisterClipboardFormatW
RegisterClipboardFormatW.argtypes = [wintypes.LPCWSTR]
RegisterClipboardFormatW.restype = wintypes.UINT


def _get_cf_html() -> int:
    """Get the CF_HTML clipboard format ID."""
    global CF_HTML
    if CF_HTML is None:
        CF_HTML = RegisterClipboardFormatW("HTML Format")
    return CF_HTML


def get_clipboard_html() -> Optional[str]:
    """
    Get HTML content from Windows clipboard.
    
    Returns:
        HTML string if available, None otherwise.
    """
    cf_html = _get_cf_html()
    
    if not OpenClipboard(None):
        logger.warning("Could not open clipboard")
        return None
    
    try:
        handle = GetClipboardData(cf_html)
        if not handle:
            return None
        
        ptr = GlobalLock(handle)
        if not ptr:
            return None
        
        try:
            size = GlobalSize(handle)
            # Read raw bytes
            raw_data = ctypes.string_at(ptr, size)
            
            # CF_HTML is UTF-8 encoded with a header
            try:
                text = raw_data.decode('utf-8', errors='ignore')
            except Exception:
                text = raw_data.decode('latin-1', errors='ignore')
            
            # Extract just the HTML fragment
            html = _extract_html_fragment(text)
            return html
            
        finally:
            GlobalUnlock(handle)
            
    finally:
        CloseClipboard()


def _extract_html_fragment(cf_html_data: str) -> str:
    """
    Extract the HTML fragment from CF_HTML format.
    
    CF_HTML format includes a header like:
    Version:0.9
    StartHTML:00000097
    EndHTML:00000170
    StartFragment:00000131
    EndFragment:00000144
    
    We want the content between StartFragment and EndFragment.
    """
    # Try to find fragment markers
    start_frag_match = re.search(r'StartFragment:(\d+)', cf_html_data)
    end_frag_match = re.search(r'EndFragment:(\d+)', cf_html_data)
    
    if start_frag_match and end_frag_match:
        start = int(start_frag_match.group(1))
        end = int(end_frag_match.group(1))
        
        # Get the raw bytes version to slice correctly
        raw_bytes = cf_html_data.encode('utf-8', errors='ignore')
        if start < len(raw_bytes) and end <= len(raw_bytes):
            fragment = raw_bytes[start:end].decode('utf-8', errors='ignore')
            return fragment
    
    # Fallback: try to find HTML content between markers
    start_match = re.search(r'<!--StartFragment-->', cf_html_data)
    end_match = re.search(r'<!--EndFragment-->', cf_html_data)
    
    if start_match and end_match:
        start = start_match.end()
        end = end_match.start()
        return cf_html_data[start:end]
    
    # Last resort: return everything after the header
    html_start = cf_html_data.find('<html')
    if html_start == -1:
        html_start = cf_html_data.find('<HTML')
    if html_start == -1:
        html_start = cf_html_data.find('<')
    
    if html_start != -1:
        return cf_html_data[html_start:]
    
    return cf_html_data


def get_clipboard_text() -> Optional[str]:
    """
    Get plain text from Windows clipboard.
    
    Returns:
        Text string if available, None otherwise.
    """
    if not OpenClipboard(None):
        return None
    
    try:
        # Try Unicode first
        handle = GetClipboardData(CF_UNICODETEXT)
        if handle:
            ptr = GlobalLock(handle)
            if ptr:
                try:
                    # Unicode text is null-terminated UTF-16
                    text = ctypes.wstring_at(ptr)
                    return text
                finally:
                    GlobalUnlock(handle)
        
        # Fall back to ANSI
        handle = GetClipboardData(CF_TEXT)
        if handle:
            ptr = GlobalLock(handle)
            if ptr:
                try:
                    text = ctypes.string_at(ptr).decode('latin-1', errors='ignore')
                    return text
                finally:
                    GlobalUnlock(handle)
        
        return None
        
    finally:
        CloseClipboard()
