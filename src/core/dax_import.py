"""
DAX Studio Query Importer for Markify.
Reads .dax and .msdax files and formats them into Markdown DAX blocks.
Zero dependencies - uses only Python built-ins.
"""
from __future__ import annotations

try:
    from core.formatters.dax import format_dax
except ImportError:
    format_dax = None


def convert_dax_file(filepath: str, format_code: bool = True) -> str:
    """Read a DAX query file and wrap it in a fenced Markdown DAX code block.

    Args:
        filepath: Path to the .dax or .msdax file.
        format_code: If True, formats the DAX using format_dax.

    Returns:
        Markdown string containing the formatted DAX code block.
    """
    with open(filepath, encoding="utf-8") as f:
        content = f.read()

    if format_code and format_dax:
        formatted = format_dax(content)
        if formatted:
            content = formatted

    return f"```dax\n{content}\n```"
