"""
Confluence Wiki Syntax converter for Markify.
Converts Markdown to Confluence/Jira wiki markup.
Zero dependencies - uses only Python built-ins.
"""
from __future__ import annotations

import re


def markdown_to_confluence(md_content: str) -> str:
    """
    Convert Markdown content to Confluence Wiki Syntax.

    Args:
        md_content: Markdown formatted text

    Returns:
        Confluence wiki markup formatted text
    """
    lines = md_content.split('\n')
    result_lines = []
    in_code_block = False
    code_language = None
    code_lines = []

    i = 0
    while i < len(lines):
        line = lines[i]

        # Handle code blocks
        if line.strip().startswith('```'):
            if not in_code_block:
                # Starting code block
                in_code_block = True
                code_language = line.strip()[3:].strip() or None
                code_lines = []
            else:
                # Ending code block
                in_code_block = False
                if code_language:
                    result_lines.append(f'{{code:language={code_language}}}')
                else:
                    result_lines.append('{code}')
                result_lines.extend(code_lines)
                result_lines.append('{code}')
            i += 1
            continue

        if in_code_block:
            code_lines.append(line)
            i += 1
            continue

        # Convert the line
        converted = _convert_line(line)
        result_lines.append(converted)
        i += 1

    return '\n'.join(result_lines)


def _convert_line(line: str) -> str:
    """Convert a single line of markdown to Confluence syntax."""

    # Skip empty lines
    if not line.strip():
        return line

    # Headings: # -> h1., ## -> h2., etc.
    heading_match = re.match(r'^(#{1,6})\s+(.+)$', line)
    if heading_match:
        level = len(heading_match.group(1))
        text = heading_match.group(2)
        text = _convert_inline(text)
        return f'h{level}. {text}'

    # Unordered lists: - or * -> *
    list_match = re.match(r'^(\s*)([-*+])\s+(.+)$', line)
    if list_match:
        indent = len(list_match.group(1)) // 2
        text = list_match.group(3)
        text = _convert_inline(text)
        prefix = '*' * (indent + 1)
        return f'{prefix} {text}'

    # Ordered lists: 1. -> #
    ordered_match = re.match(r'^(\s*)(\d+)\.\s+(.+)$', line)
    if ordered_match:
        indent = len(ordered_match.group(1)) // 2
        text = ordered_match.group(3)
        text = _convert_inline(text)
        prefix = '#' * (indent + 1)
        return f'{prefix} {text}'

    # Blockquotes: > -> {quote}
    if line.strip().startswith('>'):
        text = line.strip()[1:].strip()
        text = _convert_inline(text)
        return f'{{quote}}{text}{{quote}}'

    # Horizontal rules
    if re.match(r'^[-*_]{3,}\s*$', line.strip()):
        return '----'

    # Regular paragraph
    return _convert_inline(line)


def _convert_inline(text: str) -> str:
    """Convert inline markdown formatting to Confluence syntax."""
    result = text

    # Use placeholder to protect bold conversions
    BOLD_PLACEHOLDER = '\x00BOLD\x00'

    # Images first: ![alt](url) -> !url!
    result = re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', r'!\2!', result)

    # Links: [text](url) -> [text|url]
    result = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'[\1|\2]', result)

    # Bold: **text** or __text__ -> *text* (with placeholder protection)
    def bold_replace(m):
        return BOLD_PLACEHOLDER + m.group(1) + BOLD_PLACEHOLDER
    result = re.sub(r'\*\*(.+?)\*\*', bold_replace, result)
    result = re.sub(r'__(.+?)__', bold_replace, result)

    # Italic: single *text* -> _text_ (but not our placeholders)
    result = re.sub(r'(?<!\*)\*([^*\x00]+?)\*(?!\*)', r'_\1_', result)

    # Restore bold placeholders to actual *
    result = result.replace(BOLD_PLACEHOLDER, '*')

    # Strikethrough: ~~text~~ -> -text-
    result = re.sub(r'~~(.+?)~~', r'-\1-', result)

    # Inline code: `code` -> {{code}}
    result = re.sub(r'`([^`]+)`', r'{{\1}}', result)

    return result


def convert_table(md_table: str) -> str:
    """
    Convert a Markdown table to Confluence table syntax.

    Args:
        md_table: Markdown table string

    Returns:
        Confluence table markup
    """
    lines = [line.strip() for line in md_table.strip().split('\n') if line.strip()]
    if len(lines) < 2:
        return md_table

    result_lines = []

    for idx, line in enumerate(lines):
        # Skip separator line (|---|---|)
        if re.match(r'^\|?[\s:|\-]+\|?$', line):
            continue

        # Parse cells
        cells = [c.strip() for c in line.split('|')]
        cells = [c for c in cells if c]  # Remove empty cells from edges

        if idx == 0:
            # Header row: || cell || cell ||
            result_lines.append('||' + '||'.join(cells) + '||')
        else:
            # Data row: | cell | cell |
            result_lines.append('|' + '|'.join(cells) + '|')

    return '\n'.join(result_lines)


def extract_and_convert_tables(content: str) -> str:
    """
    Find markdown tables in content and convert them to Confluence format.

    Args:
        content: Full markdown content

    Returns:
        Content with tables converted
    """
    # Simple table pattern (lines starting with |)
    lines = content.split('\n')
    result_lines = []
    table_lines = []
    in_table = False

    for line in lines:
        is_table_line = line.strip().startswith('|') or (
            in_table and re.match(r'^\s*[\s:|\-]+\s*$', line)
        )

        if is_table_line:
            in_table = True
            table_lines.append(line)
        else:
            if table_lines:
                # Convert accumulated table
                table_md = '\n'.join(table_lines)
                result_lines.append(convert_table(table_md))
                table_lines = []
                in_table = False
            result_lines.append(line)

    # Handle table at end of content
    if table_lines:
        table_md = '\n'.join(table_lines)
        result_lines.append(convert_table(table_md))

    return '\n'.join(result_lines)


def full_convert(md_content: str) -> str:
    """
    Full conversion from Markdown to Confluence, including tables.

    Args:
        md_content: Markdown content

    Returns:
        Confluence wiki markup
    """
    # First convert tables
    content = extract_and_convert_tables(md_content)
    # Then convert the rest
    return markdown_to_confluence(content)
