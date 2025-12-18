"""
Table of Contents generator for Markify.
Scans Markdown headers and generates a linked TOC.
"""
from __future__ import annotations

import re
from typing import List, Tuple


def extract_headers(markdown: str) -> List[Tuple[int, str, str]]:
    """
    Extract headers from Markdown content.
    
    Returns:
        List of tuples: (level, text, anchor)
        - level: 1-6 for H1-H6
        - text: Header text
        - anchor: URL-safe anchor for linking
    """
    headers = []
    lines = markdown.split('\n')
    in_code_block = False
    
    for line in lines:
        # Track code blocks to ignore headers inside them
        if line.strip().startswith('```'):
            in_code_block = not in_code_block
            continue
        
        if in_code_block:
            continue
        
        # Match Markdown headers (# Header)
        match = re.match(r'^(#{1,6})\s+(.+?)(?:\s*#+)?$', line)
        if match:
            level = len(match.group(1))
            text = match.group(2).strip()
            anchor = _create_anchor(text)
            headers.append((level, text, anchor))
    
    return headers


def _create_anchor(text: str) -> str:
    """
    Create a URL-safe anchor from header text.
    Follows GitHub-style anchor generation.
    """
    # Remove special characters, convert to lowercase, replace spaces with hyphens
    anchor = text.lower()
    # Keep alphanumeric, spaces, and hyphens
    anchor = re.sub(r'[^\w\s-]', '', anchor)
    # Replace spaces with hyphens
    anchor = re.sub(r'\s+', '-', anchor)
    # Remove leading/trailing hyphens
    anchor = anchor.strip('-')
    return anchor


def generate_toc(markdown: str, max_depth: int = 3, min_level: int = 1) -> str:
    """
    Generate a Table of Contents from Markdown headers.
    
    Args:
        markdown: The Markdown content to scan
        max_depth: Maximum header level to include (default: 3 for H1-H3)
        min_level: Minimum header level to start from (default: 1)
    
    Returns:
        Markdown formatted TOC string
    """
    headers = extract_headers(markdown)
    
    if not headers:
        return ""
    
    # Filter by depth
    filtered = [(level, text, anchor) for level, text, anchor in headers 
                if min_level <= level <= max_depth]
    
    if not filtered:
        return ""
    
    # Build TOC
    lines = ["## Table of Contents", ""]
    
    for level, text, anchor in filtered:
        # Indent based on level (relative to min_level)
        indent = "  " * (level - min_level)
        lines.append(f"{indent}- [{text}](#{anchor})")
    
    lines.append("")  # Trailing newline
    return '\n'.join(lines)


def insert_toc(markdown: str, position: str = "top", max_depth: int = 3) -> str:
    """
    Generate and insert a TOC into Markdown content.
    
    Args:
        markdown: The Markdown content
        position: Where to insert TOC - "top" or "after_title"
        max_depth: Maximum header level to include
    
    Returns:
        Markdown with TOC inserted
    """
    toc = generate_toc(markdown, max_depth=max_depth)
    
    if not toc:
        return markdown
    
    if position == "top":
        return toc + "\n" + markdown
    
    elif position == "after_title":
        # Insert after the first H1 header
        lines = markdown.split('\n')
        insert_index = 0
        
        for i, line in enumerate(lines):
            if line.strip().startswith('# '):
                insert_index = i + 1
                # Skip any blank lines after the title
                while insert_index < len(lines) and not lines[insert_index].strip():
                    insert_index += 1
                break
        
        if insert_index > 0:
            before = '\n'.join(lines[:insert_index])
            after = '\n'.join(lines[insert_index:])
            return before + '\n\n' + toc + '\n' + after
        else:
            return toc + '\n' + markdown
    
    return markdown
