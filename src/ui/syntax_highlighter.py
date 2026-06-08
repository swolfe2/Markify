"""
Syntax highlighting utility for Markify code blocks and markdown headers.
Zero dependencies - uses regex tokenization and Tkinter tags.
"""
from __future__ import annotations

import re
import tkinter as tk

from config import get_patterns
from themes import SYNTAX_THEMES


def apply_syntax_highlighting(text_widget: tk.Text, content: str, theme_name: str):
    """
    Apply syntax highlighting to the text_widget for headers and code blocks
    based on the selected syntax theme.
    """
    # Defensive checks for stubs/mocks
    has_tag_remove = hasattr(text_widget, "tag_remove")
    has_tag_configure = hasattr(text_widget, "tag_configure")
    has_tag_add = hasattr(text_widget, "tag_add")
    has_tag_raise = hasattr(text_widget, "tag_raise")

    # Clear existing syntax tags first
    syntax_tags = [
        "syntax_bg",
        "syntax_keyword",
        "syntax_string",
        "syntax_comment",
        "syntax_number",
        "syntax_builtin",
        "markdown_header",
    ]
    if has_tag_remove:
        for tag in syntax_tags:
            text_widget.tag_remove(tag, "1.0", tk.END)

    # Fetch theme details
    theme = SYNTAX_THEMES.get(theme_name, SYNTAX_THEMES["One Dark"])

    # Configure tags
    if has_tag_configure:
        text_widget.tag_configure("syntax_bg", background=theme["bg"], foreground=theme["fg"])
        text_widget.tag_configure("syntax_keyword", foreground=theme["keyword"])
        text_widget.tag_configure("syntax_string", foreground=theme["string"])
        text_widget.tag_configure("syntax_comment", foreground=theme["comment"])
        text_widget.tag_configure("syntax_number", foreground=theme["number"])
        text_widget.tag_configure("syntax_builtin", foreground=theme["builtin"])
        text_widget.tag_configure(
            "markdown_header",
            foreground=theme["keyword"],
            font=("Consolas", 10, "bold"),
        )

    # Establish tag priorities
    # syntax_bg goes below everything else (like add/del tags) if they exist.
    # We raise token tags above add/del and syntax_bg.
    if has_tag_raise:
        for token_tag in ["syntax_keyword", "syntax_string", "syntax_comment", "syntax_number", "syntax_builtin", "markdown_header"]:
            try:
                text_widget.tag_raise(token_tag)
            except Exception:  # nosec B110
                pass

    # Retrieve keyword and function patterns from config
    patterns = get_patterns()

    lines = content.split("\n")
    in_code_block = False
    block_lang = ""

    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("```"):
            if not in_code_block:
                in_code_block = True
                block_lang = stripped[3:].strip().lower()
                if has_tag_add:
                    text_widget.tag_add("syntax_bg", f"{idx}.0", f"{idx}.end")
            else:
                in_code_block = False
                if has_tag_add:
                    text_widget.tag_add("syntax_bg", f"{idx}.0", f"{idx}.end")
            continue

        if in_code_block:
            if has_tag_add:
                text_widget.tag_add("syntax_bg", f"{idx}.0", f"{idx}.end")
            highlight_line_content(text_widget, idx, line, block_lang, patterns, has_tag_add)
        else:
            if stripped.startswith("#"):
                if has_tag_add:
                    text_widget.tag_add("markdown_header", f"{idx}.0", f"{idx}.end")


def highlight_line_content(
    text_widget: tk.Text,
    line_idx: int,
    line_text: str,
    lang: str,
    patterns: dict[str, list[str]],
    has_tag_add: bool,
):
    """
    Highlights a single line of code depending on the language rules.
    """
    if not has_tag_add:
        return

    # Determine syntax rules based on the language fence tag
    comment_pattern = r"#.*"
    keywords = set()
    builtins = set()
    case_insensitive = False

    if lang in ("python", "py"):
        comment_pattern = r"#.*"
        keywords = {kw.strip() for kw in patterns.get("python_keywords", [])}
        builtins = {b.strip("()") for b in patterns.get("python_builtins", [])}
    elif lang in ("sql",):
        comment_pattern = r"--.*"
        keywords = {kw.strip().upper() for kw in patterns.get("sql_keywords", [])}
        builtins = {b.strip("()").upper() for b in patterns.get("sql_functions", [])}
        case_insensitive = True
    elif lang in ("dax",):
        comment_pattern = r"(?://|--).*"
        keywords = {kw.strip().upper() for kw in patterns.get("dax_keywords", [])}
        builtins = {b.strip("()").upper() for b in patterns.get("dax_functions", [])}
        case_insensitive = True
    elif lang in ("pq", "powerquery", "m"):
        comment_pattern = r"//.*"
        keywords = {kw.strip() for kw in patterns.get("powerquery_exact_matches", [])}
        builtins = {b.strip() for b in patterns.get("powerquery_functions", [])}
    else:
        # Generic fallback
        comment_pattern = r"(?:#|//|--).*"
        for k in ["python_keywords", "sql_keywords", "dax_keywords", "powerquery_exact_matches"]:
            keywords.update(kw.strip() for kw in patterns.get(k, []))
        for b in ["python_builtins", "sql_functions", "dax_functions", "powerquery_functions"]:
            builtins.update(bi.strip("()") for bi in patterns.get(b, []))

    # Master scanner regex
    parts = [
        r"(?P<comment>" + comment_pattern + r")",
        r"(?P<string>\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^\'\\])*')",
        r"(?P<number>\b\d+(?:\.\d+)?\b)",
        r"(?P<word>[a-zA-Z_][a-zA-Z0-9_\.]*)",
    ]
    scanner = re.compile("|".join(parts))

    for match in scanner.finditer(line_text):
        kind = match.lastgroup
        val = match.group(0)
        start_col = match.start()
        end_col = match.end()

        start_idx = f"{line_idx}.{start_col}"
        end_idx = f"{line_idx}.{end_col}"

        if kind == "comment":
            text_widget.tag_add("syntax_comment", start_idx, end_idx)
        elif kind == "string":
            text_widget.tag_add("syntax_string", start_idx, end_idx)
        elif kind == "number":
            text_widget.tag_add("syntax_number", start_idx, end_idx)
        elif kind == "word":
            check_val = val.upper() if case_insensitive else val
            if check_val in keywords:
                text_widget.tag_add("syntax_keyword", start_idx, end_idx)
            elif check_val in builtins:
                text_widget.tag_add("syntax_builtin", start_idx, end_idx)
