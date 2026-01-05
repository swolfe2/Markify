"""
Template system utilities for Markify.
Allows user-defined templates with variable substitution.
Zero dependencies - uses only Python built-ins.
"""
from __future__ import annotations

import os
import re
from datetime import datetime
from typing import Any

# Default template that wraps converted content
DEFAULT_TEMPLATE = """{{content}}"""

# Template with front matter (alternative default)
FRONTMATTER_TEMPLATE = """---
title: "{{title}}"
date: {{date}}
source: "{{filename}}"
---

{{content}}
"""


def get_available_variables() -> dict[str, str]:
    """
    Get a dictionary of available template variables and their descriptions.

    Returns:
        Dict mapping variable names to descriptions
    """
    return {
        "{{filename}}": "Original filename without extension",
        "{{filename_ext}}": "Original filename with extension",
        "{{title}}": "Document title (from first heading or filename)",
        "{{date}}": "Current date in ISO format (YYYY-MM-DD)",
        "{{datetime}}": "Current datetime in ISO format",
        "{{time}}": "Current time (HH:MM:SS)",
        "{{year}}": "Current year",
        "{{month}}": "Current month (01-12)",
        "{{day}}": "Current day (01-31)",
        "{{author}}": "Author name (from preferences or empty)",
        "{{content}}": "The converted markdown content",
    }


def build_context(
    filename: str | None = None,
    title: str | None = None,
    content: str = "",
    author: str | None = None,
    custom_vars: dict[str, Any] | None = None
) -> dict[str, str]:
    """
    Build a template context dictionary with all available variables.

    Args:
        filename: Original filename (with or without path)
        title: Document title (auto-derived from filename if not provided)
        content: The markdown content
        author: Author name
        custom_vars: Additional custom variables

    Returns:
        Dictionary with all template variables populated
    """
    now = datetime.now()

    # Extract filename parts
    if filename:
        basename = os.path.basename(filename)
        name_no_ext = os.path.splitext(basename)[0]
    else:
        basename = ""
        name_no_ext = ""

    # Auto-derive title from filename if not provided
    if title is None:
        title = name_no_ext.replace("_", " ").replace("-", " ").title()

    context = {
        "{{filename}}": name_no_ext,
        "{{filename_ext}}": basename,
        "{{title}}": title,
        "{{date}}": now.strftime("%Y-%m-%d"),
        "{{datetime}}": now.strftime("%Y-%m-%dT%H:%M:%S"),
        "{{time}}": now.strftime("%H:%M:%S"),
        "{{year}}": now.strftime("%Y"),
        "{{month}}": now.strftime("%m"),
        "{{day}}": now.strftime("%d"),
        "{{author}}": author or "",
        "{{content}}": content,
    }

    # Add custom variables
    if custom_vars:
        for key, value in custom_vars.items():
            # Ensure key has {{ }} wrapper
            if not key.startswith("{{"):
                key = "{{" + key + "}}"
            context[key] = str(value)

    return context


def apply_template(
    template: str,
    context: dict[str, str]
) -> str:
    """
    Apply a template by substituting variables with context values.

    Args:
        template: Template string with {{variable}} placeholders
        context: Dictionary mapping {{variable}} to values

    Returns:
        Processed string with variables substituted
    """
    result = template

    for var, value in context.items():
        result = result.replace(var, value)

    return result


def process_with_template(
    content: str,
    template: str | None = None,
    filename: str | None = None,
    title: str | None = None,
    author: str | None = None,
    custom_vars: dict[str, Any] | None = None
) -> str:
    """
    Process content through a template with automatic context building.

    This is the main entry point for template processing.

    Args:
        content: The markdown content to wrap
        template: Template string (uses DEFAULT_TEMPLATE if not provided)
        filename: Original filename for context
        title: Document title (auto-derived if not provided)
        author: Author name
        custom_vars: Additional custom variables

    Returns:
        Processed content with template applied
    """
    if template is None:
        template = DEFAULT_TEMPLATE

    context = build_context(
        filename=filename,
        title=title,
        content=content,
        author=author,
        custom_vars=custom_vars
    )

    return apply_template(template, context)


def load_template(path: str) -> str | None:
    """
    Load a template from a file.

    Args:
        path: Path to the template file

    Returns:
        Template string, or None if file doesn't exist
    """
    if not os.path.exists(path):
        return None

    try:
        with open(path, encoding='utf-8') as f:
            return f.read()
    except Exception:
        return None


def save_template(path: str, template: str) -> bool:
    """
    Save a template to a file.

    Args:
        path: Path where to save the template
        template: Template content

    Returns:
        True if successful, False otherwise
    """
    try:
        # Create directory if needed
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(template)
        return True
    except Exception:
        return False


def get_default_template() -> str:
    """Get the default template."""
    return DEFAULT_TEMPLATE


def get_frontmatter_template() -> str:
    """Get the template with front matter."""
    return FRONTMATTER_TEMPLATE


def extract_variables(template: str) -> list:
    """
    Extract all variable names from a template.

    Args:
        template: Template string

    Returns:
        List of variable names (without {{ }})
    """
    pattern = r'\{\{(\w+)\}\}'
    matches = re.findall(pattern, template)
    return list(set(matches))
