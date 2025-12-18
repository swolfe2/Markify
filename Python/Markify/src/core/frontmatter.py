"""
Front matter generation utilities for Markify.
Generates YAML front matter for static site generators (Hugo, Jekyll, etc.).
Zero dependencies - uses only Python built-ins.
"""
from __future__ import annotations

import os
import re
from datetime import datetime
from typing import Any, Dict, List, Optional


def generate_front_matter(
    title: Optional[str] = None,
    date: Optional[datetime] = None,
    filename: Optional[str] = None,
    author: Optional[str] = None,
    tags: Optional[List[str]] = None,
    categories: Optional[List[str]] = None,
    draft: bool = False,
    custom_fields: Optional[Dict[str, Any]] = None
) -> str:
    """
    Generate YAML front matter for static site generators.
    
    Args:
        title: Document title (auto-detected from first heading if not provided)
        date: Publication date (defaults to current date)
        filename: Original filename (used for slug generation)
        author: Author name
        tags: List of tags
        categories: List of categories
        draft: Whether the document is a draft
        custom_fields: Additional custom fields as key-value pairs
    
    Returns:
        YAML front matter string with opening and closing ---
    """
    lines: List[str] = ['---']
    
    # Title
    if title:
        # Escape quotes in title
        escaped_title = title.replace('"', '\\"')
        lines.append(f'title: "{escaped_title}"')
    
    # Date
    if date is None:
        date = datetime.now()
    lines.append(f'date: {date.strftime("%Y-%m-%dT%H:%M:%S")}')
    
    # Author
    if author:
        lines.append(f'author: "{author}"')
    
    # Draft status
    if draft:
        lines.append('draft: true')
    
    # Tags
    if tags:
        lines.append('tags:')
        for tag in tags:
            lines.append(f'  - "{tag}"')
    
    # Categories
    if categories:
        lines.append('categories:')
        for category in categories:
            lines.append(f'  - "{category}"')
    
    # Slug (from filename)
    if filename:
        slug = generate_slug(filename)
        lines.append(f'slug: "{slug}"')
    
    # Custom fields
    if custom_fields:
        for key, value in custom_fields.items():
            formatted_value = _format_yaml_value(value)
            lines.append(f'{key}: {formatted_value}')
    
    lines.append('---')
    return '\n'.join(lines)


def generate_slug(filename: str) -> str:
    """
    Generate a URL-friendly slug from a filename.
    
    Args:
        filename: Original filename (with or without extension)
    
    Returns:
        Lowercase, hyphenated slug suitable for URLs
    """
    # Remove extension
    name = os.path.splitext(os.path.basename(filename))[0]
    
    # Convert to lowercase
    slug = name.lower()
    
    # Replace spaces and underscores with hyphens
    slug = re.sub(r'[\s_]+', '-', slug)
    
    # Remove non-alphanumeric characters except hyphens
    slug = re.sub(r'[^a-z0-9-]', '', slug)
    
    # Remove consecutive hyphens
    slug = re.sub(r'-+', '-', slug)
    
    # Remove leading/trailing hyphens
    slug = slug.strip('-')
    
    return slug


def extract_title_from_markdown(markdown_content: str) -> Optional[str]:
    """
    Extract the first heading from markdown content to use as title.
    
    Args:
        markdown_content: The markdown text
    
    Returns:
        The heading text, or None if no heading found
    """
    # Match # heading style
    match = re.search(r'^#\s+(.+?)$', markdown_content, re.MULTILINE)
    if match:
        return match.group(1).strip()
    
    # Match first non-empty line as fallback
    for line in markdown_content.split('\n'):
        stripped = line.strip()
        if stripped and not stripped.startswith('```'):
            return stripped
    
    return None


def add_front_matter_to_markdown(
    markdown_content: str,
    title: Optional[str] = None,
    date: Optional[datetime] = None,
    filename: Optional[str] = None,
    auto_title: bool = True,
    **kwargs
) -> str:
    """
    Add YAML front matter to the beginning of markdown content.
    
    Args:
        markdown_content: The markdown text
        title: Document title (auto-detected if not provided and auto_title=True)
        date: Publication date (defaults to current date)
        filename: Original filename for slug generation
        auto_title: If True, extract title from first heading
        **kwargs: Additional fields passed to generate_front_matter()
    
    Returns:
        Markdown content with front matter prepended
    """
    # Skip if content already has front matter
    if markdown_content.strip().startswith('---'):
        return markdown_content
    
    # Auto-detect title from first heading
    if title is None and auto_title:
        title = extract_title_from_markdown(markdown_content)
    
    front_matter = generate_front_matter(
        title=title,
        date=date,
        filename=filename,
        **kwargs
    )
    
    return f'{front_matter}\n\n{markdown_content}'


def _format_yaml_value(value: Any) -> str:
    """
    Format a Python value for YAML output.
    
    Args:
        value: The value to format
    
    Returns:
        YAML-formatted string representation
    """
    if value is None:
        return 'null'
    elif isinstance(value, bool):
        return 'true' if value else 'false'
    elif isinstance(value, (int, float)):
        return str(value)
    elif isinstance(value, str):
        # Escape quotes and wrap in quotes if needed
        if '\n' in value or '"' in value or ':' in value:
            escaped = value.replace('"', '\\"')
            return f'"{escaped}"'
        return f'"{value}"'
    elif isinstance(value, list):
        # Format as YAML list
        if not value:
            return '[]'
        items = ', '.join(f'"{v}"' if isinstance(v, str) else str(v) for v in value)
        return f'[{items}]'
    else:
        return f'"{value}"'
