"""
Obsidian export module for Markify.
Converts standard Markdown to Obsidian-flavored features:
- Wikilinks [[page]] format
- Callout blocks > [!note]
- Properties/metadata in Obsidian format
"""
from __future__ import annotations

import re


def convert_to_obsidian(markdown: str) -> str:
    """
    Convert standard Markdown to Obsidian format.

    Transformations:
    - Markdown links to wikilinks (optional, see Settings)
    - Blockquotes with markers to callouts
    - Keep front matter compatible

    Args:
        markdown: Standard Markdown content

    Returns:
        Obsidian-flavored Markdown
    """
    result = markdown

    # Convert callout-style blockquotes to Obsidian callouts
    result = convert_blockquotes_to_callouts(result)

    return result


def convert_links_to_wikilinks(markdown: str, internal_only: bool = True) -> str:
    """
    Convert Markdown links to Obsidian wikilinks.

    Args:
        markdown: Markdown content with [text](url) links
        internal_only: If True, only convert internal links (no http/https)

    Returns:
        Markdown with [[wikilink]] format for internal links
    """
    def replace_link(match):
        text = match.group(1)
        url = match.group(2)

        # Skip external links if internal_only
        if internal_only and (url.startswith('http://') or url.startswith('https://')):
            return match.group(0)

        # Skip image links
        if url.endswith(('.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp')):
            return match.group(0)

        # Skip anchor links
        if url.startswith('#'):
            return match.group(0)

        # Convert to wikilink
        # Remove .md extension if present
        page = url.rstrip('.md').rstrip('/')

        # If text matches the page name, use simple wikilink
        if text.lower() == page.lower() or text.lower() == page.split('/')[-1].lower():
            return f'[[{page}]]'
        else:
            return f'[[{page}|{text}]]'

    # Match Markdown links: [text](url)
    pattern = r'\[([^\]]+)\]\(([^)]+)\)'
    return re.sub(pattern, replace_link, markdown)


def convert_blockquotes_to_callouts(markdown: str) -> str:
    """
    Convert blockquotes with markers to Obsidian callouts.

    Detects patterns like:
    - "Note:" or "NOTE:" at start of blockquote -> > [!note]
    - "Warning:" -> > [!warning]
    - "Tip:" -> > [!tip]
    - "Important:" -> > [!important]

    Args:
        markdown: Markdown content

    Returns:
        Markdown with Obsidian callout syntax
    """
    lines = markdown.split('\n')
    result = []

    callout_markers = {
        'note': 'note',
        'info': 'info',
        'tip': 'tip',
        'hint': 'tip',
        'warning': 'warning',
        'caution': 'caution',
        'danger': 'danger',
        'important': 'important',
        'example': 'example',
        'quote': 'quote',
        'success': 'success',
        'question': 'question',
        'bug': 'bug',
    }

    i = 0
    while i < len(lines):
        line = lines[i]

        # Check if this is a blockquote line
        if line.strip().startswith('>'):
            # Get the content after >
            content = line.strip()[1:].strip()

            # Check for callout markers at the start
            converted = False
            for marker, callout_type in callout_markers.items():
                pattern = rf'^{marker}:\s*(.*)$'
                match = re.match(pattern, content, re.IGNORECASE)
                if match:
                    # Convert to Obsidian callout
                    remaining_text = match.group(1).strip()
                    result.append(f'> [!{callout_type}]')
                    if remaining_text:
                        result.append(f'> {remaining_text}')
                    converted = True
                    break

            if not converted:
                result.append(line)
        else:
            result.append(line)

        i += 1

    return '\n'.join(result)


def add_obsidian_properties(
    markdown: str,
    tags: list | None = None,
    aliases: list | None = None,
    cssclass: str | None = None,
    **custom_properties
) -> str:
    """
    Add Obsidian properties (YAML front matter) to Markdown.

    Args:
        markdown: Markdown content
        tags: List of tags for the note
        aliases: Alternative names for the note
        cssclass: CSS class for styling
        **custom_properties: Any additional properties

    Returns:
        Markdown with Obsidian properties
    """
    # Check if front matter already exists
    if markdown.startswith('---'):
        # Find the end of existing front matter
        end_index = markdown.find('---', 3)
        if end_index != -1:
            existing_fm = markdown[4:end_index].strip()
            rest = markdown[end_index + 3:].lstrip()

            # Add new properties to existing
            new_lines = []
            if tags:
                new_lines.append(f"tags: [{', '.join(tags)}]")
            if aliases:
                new_lines.append(f"aliases: [{', '.join(aliases)}]")
            if cssclass:
                new_lines.append(f"cssclass: {cssclass}")
            for key, value in custom_properties.items():
                new_lines.append(f"{key}: {value}")

            if new_lines:
                existing_fm += '\n' + '\n'.join(new_lines)

            return f'---\n{existing_fm}\n---\n{rest}'

    # Create new front matter
    fm_lines = []
    if tags:
        fm_lines.append(f"tags: [{', '.join(tags)}]")
    if aliases:
        fm_lines.append(f"aliases: [{', '.join(aliases)}]")
    if cssclass:
        fm_lines.append(f"cssclass: {cssclass}")
    for key, value in custom_properties.items():
        fm_lines.append(f"{key}: {value}")

    if fm_lines:
        front_matter = '---\n' + '\n'.join(fm_lines) + '\n---\n\n'
        return front_matter + markdown

    return markdown
