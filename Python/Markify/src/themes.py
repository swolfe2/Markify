"""
Theme definitions for Markify.
Industry-standard color palettes for dark/light modes.
"""
from __future__ import annotations

from typing import Dict, List


# Theme color definitions
# Each theme must define: bg, fg, accent, accent_hover, secondary_bg, error, success, warning
THEMES: Dict[str, Dict[str, str]] = {
    "VS Code Dark": {
        "bg": "#1e1e1e",
        "fg": "#d4d4d4",
        "accent": "#007acc",
        "accent_fg": "#ffffff",
        "accent_hover": "#0098ff",
        "secondary_bg": "#2d2d30",
        "error": "#f44336",
        "success": "#4caf50",
        "warning": "#ff9800",
        "border": "#3e3e42",
        "muted": "#808080",
    },
    "VS Code Light": {
        "bg": "#ffffff",
        "fg": "#1e1e1e",
        "accent": "#007acc",
        "accent_fg": "#ffffff",
        "accent_hover": "#0098ff",
        "secondary_bg": "#f3f3f3",
        "error": "#d32f2f",
        "success": "#388e3c",
        "warning": "#f57c00",
        "border": "#e0e0e0",
        "muted": "#6e6e6e",
    },
    "Dracula": {
        "bg": "#282a36",
        "fg": "#f8f8f2",
        "accent": "#bd93f9",
        "accent_fg": "#282a36",
        "accent_hover": "#ff79c6",
        "secondary_bg": "#44475a",
        "error": "#ff5555",
        "success": "#50fa7b",
        "warning": "#ffb86c",
        "border": "#6272a4",
        "muted": "#6272a4",
    },
    "Nord": {
        "bg": "#2e3440",
        "fg": "#eceff4",
        "accent": "#88c0d0",
        "accent_fg": "#2e3440",
        "accent_hover": "#8fbcbb",
        "secondary_bg": "#3b4252",
        "error": "#bf616a",
        "success": "#a3be8c",
        "warning": "#ebcb8b",
        "border": "#4c566a",
        "muted": "#d8dee9",
    },
    "Solarized Dark": {
        "bg": "#002b36",
        "fg": "#839496",
        "accent": "#268bd2",
        "accent_fg": "#002b36",  # Dark text on blue
        "accent_hover": "#2aa198",
        "secondary_bg": "#073642",
        "error": "#dc322f",
        "success": "#859900",
        "warning": "#b58900",
        "border": "#586e75",
        "muted": "#586e75",
    },
    "Solarized Light": {
        "bg": "#fdf6e3",
        "fg": "#657b83",
        "accent": "#268bd2",
        "accent_fg": "#073642", # Dark text on blue
        "accent_hover": "#2aa198",
        "secondary_bg": "#eee8d5",
        "error": "#dc322f",
        "success": "#859900",
        "warning": "#b58900",
        "border": "#93a1a1",
        "muted": "#586e75", # Darker grey for visibility (was #93a1a1 which is too light)
    },
    "High Contrast": {
        "bg": "#000000",
        "fg": "#ffffff",
        "accent": "#00ff00",
        "accent_fg": "#000000",
        "accent_hover": "#ffff00",
        "secondary_bg": "#1a1a1a",
        "error": "#ff0000",
        "success": "#00ff00",
        "warning": "#ffff00",
        "border": "#ffffff",
        "muted": "#cccccc",
    },
}

# Default theme
DEFAULT_THEME = "VS Code Dark"


def get_theme(name: str) -> Dict[str, str]:
    """
    Get a theme by name.
    
    Args:
        name: Theme name
    
    Returns:
        Theme color dictionary, or default theme if not found
    """
    return THEMES.get(name, THEMES[DEFAULT_THEME])


def get_theme_names() -> List[str]:
    """
    Get list of available theme names.
    
    Returns:
        List of theme names in display order
    """
    # Return in a specific order: dark themes first, then light
    order = [
        "VS Code Dark",
        "VS Code Light",
        "Dracula",
        "Nord",
        "Solarized Dark",
        "Solarized Light",
        "High Contrast",
    ]
    return [name for name in order if name in THEMES]


def get_default_theme() -> str:
    """Get the default theme name."""
    return DEFAULT_THEME
