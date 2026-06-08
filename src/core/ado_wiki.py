"""
Azure DevOps Wiki Syntax converter for Markify.
Converts Markdown to Azure DevOps (ADO) wiki format.
Zero dependencies - uses only Python built-ins.
"""
from __future__ import annotations

import os
import re


def convert_toc(md_content: str) -> str:
    """Replace Markdown Table of Contents list blocks with ADO's native [[_TOC_]] macro."""
    lines = md_content.split("\n")
    result_lines = []
    i = 0
    in_toc = False
    while i < len(lines):
        line = lines[i]
        if line.strip() == "## Table of Contents":
            in_toc = True
            result_lines.append("[[_TOC_]]")
            i += 1
            continue

        if in_toc:
            stripped = line.strip()
            # TOC list elements match patterns like: "- [Text](#anchor)" or "  - [Text](#anchor)"
            if not stripped or stripped.startswith("-") or stripped.startswith("*") or re.match(r"^\d+\.", stripped):
                if "(" in line and ")" in line and "#" in line:
                    i += 1
                    continue
            in_toc = False

        result_lines.append(line)
        i += 1
    return "\n".join(result_lines)


def convert_mermaid_blocks(md_content: str) -> str:
    """Convert standard backtick-fenced Mermaid blocks to ADO ::: mermaid ::: blocks."""
    lines = md_content.split("\n")
    result_lines = []
    in_mermaid = False
    for line in lines:
        if line.strip() == "```mermaid":
            in_mermaid = True
            result_lines.append("::: mermaid")
        elif in_mermaid and line.strip() == "```":
            in_mermaid = False
            result_lines.append(":::")
        else:
            result_lines.append(line)
    return "\n".join(result_lines)


def convert_attachment_links(md_content: str) -> str:
    """Convert relative image and file link directories to the ADO /attachments/ schema."""
    def image_repl(match: re.Match) -> str:
        alt = match.group(1)
        path = match.group(2)
        # Skip absolute links
        if path.startswith(("http:", "https:")):
            return match.group(0)
        filename = os.path.basename(path)
        return f"![{alt}](/attachments/{filename})"

    def link_repl(match: re.Match) -> str:
        text = match.group(1)
        path = match.group(2)
        # Only convert relative file paths (ignore external, mailto, and anchors)
        if not path.startswith(("http:", "https:", "mailto:", "#")):
            filename = os.path.basename(path)
            return f"[{text}](/attachments/{filename})"
        return match.group(0)

    # Convert image links
    content = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", image_repl, md_content)
    # Convert file links
    content = re.sub(r"(?<!\!)\[([^\]]+)\]\(([^)]+)\)", link_repl, content)
    return content


def full_convert(md_content: str) -> str:
    """Apply all Azure DevOps wiki format conversions."""
    content = convert_toc(md_content)
    content = convert_mermaid_blocks(content)
    content = convert_attachment_links(content)
    return content
