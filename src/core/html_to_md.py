"""
HTML to Markdown converter for Clipboard Mode.
Uses only Python standard library (html.parser).
"""
from __future__ import annotations

import re
from html.parser import HTMLParser


class HTMLToMarkdownConverter(HTMLParser):
    """Convert HTML to Markdown using stdlib HTMLParser."""

    def __init__(self):
        super().__init__()
        self.output: list[str] = []
        self.tag_stack: list[str] = []
        self.list_stack: list[tuple[str, int]] = []  # (type, counter)
        self.in_pre = False
        self.in_code = False
        self.current_link: str | None = None
        self.link_text: list[str] = []
        self.cell_buffer: list[str] = []
        self.row_cells: list[str] = []
        self.table_rows: list[list[str]] = []
        self.in_table = False
        self.in_cell = False  # Track when inside a td/th cell

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]):
        tag = tag.lower()
        self.tag_stack.append(tag)
        attrs_dict = dict(attrs)

        if tag in ('h1', 'h2', 'h3', 'h4', 'h5', 'h6'):
            level = int(tag[1])
            # Ensure we start on a new line
            if self.output and not self.output[-1].endswith('\n'):
                self.output.append('\n')
            self.output.append('#' * level + ' ')

        elif tag == 'p':
            # Only add newline if not at start and previous isn't already newlines
            # Skip if we're inside a table cell - cell content is handled separately
            if not self.in_cell and self.output:
                last = self.output[-1]
                if not last.endswith('\n\n') and not last.endswith('\n'):
                    self.output.append('\n')

        elif tag == 'br':
            # br inside a paragraph just continues the line in markdown
            # only add newline if there's content before it
            if self.output and self.output[-1].strip():
                self.output.append(' ')

        elif tag in ('strong', 'b'):
            if self.in_cell:
                self.cell_buffer.append('**')
            else:
                self.output.append('**')

        elif tag in ('em', 'i'):
            if self.in_cell:
                self.cell_buffer.append('*')
            else:
                self.output.append('*')

        elif tag == 'code':
            self.in_code = True
            if not self.in_pre:
                if self.in_cell:
                    self.cell_buffer.append('`')
                else:
                    self.output.append('`')

        elif tag == 'pre':
            self.in_pre = True
            self.output.append('\n```\n')

        elif tag == 'a':
            self.current_link = attrs_dict.get('href', '')
            self.link_text = []

        elif tag == 'ul':
            self.list_stack.append(('ul', 0))
            if self.output and not self.output[-1].endswith('\n'):
                self.output.append('\n')

        elif tag == 'ol':
            self.list_stack.append(('ol', 0))
            if self.output and not self.output[-1].endswith('\n'):
                self.output.append('\n')

        elif tag == 'li':
            indent = '  ' * (len(self.list_stack) - 1)
            if self.list_stack:
                list_type, counter = self.list_stack[-1]
                if list_type == 'ul':
                    self.output.append(f'{indent}- ')
                else:
                    counter += 1
                    self.list_stack[-1] = (list_type, counter)
                    self.output.append(f'{indent}{counter}. ')

        elif tag == 'table':
            self.in_table = True
            self.table_rows = []

        elif tag == 'tr':
            self.row_cells = []

        elif tag in ('td', 'th'):
            self.cell_buffer = []
            self.in_cell = True

        elif tag == 'hr':
            self.output.append('\n---\n')

        elif tag == 'blockquote':
            self.output.append('\n> ')

    def handle_endtag(self, tag: str):
        tag = tag.lower()

        if self.tag_stack and self.tag_stack[-1] == tag:
            self.tag_stack.pop()

        if tag in ('h1', 'h2', 'h3', 'h4', 'h5', 'h6'):
            self.output.append('\n')

        elif tag == 'p':
            # End paragraph with newline for separation
            # Skip if we're inside a table cell - cell content is handled separately
            if not self.in_cell and self.output and not self.output[-1].endswith('\n'):
                self.output.append('\n')

        elif tag in ('strong', 'b'):
            if self.in_cell:
                self.cell_buffer.append('**')
            else:
                self.output.append('**')

        elif tag in ('em', 'i'):
            if self.in_cell:
                self.cell_buffer.append('*')
            else:
                self.output.append('*')

        elif tag == 'code':
            self.in_code = False
            if not self.in_pre:
                if self.in_cell:
                    self.cell_buffer.append('`')
                else:
                    self.output.append('`')

        elif tag == 'pre':
            self.in_pre = False
            self.output.append('\n```\n')

        elif tag == 'a':
            text = ''.join(self.link_text).strip()
            if self.current_link:
                self.output.append(f'[{text}]({self.current_link})')
            else:
                self.output.append(text)
            self.current_link = None
            self.link_text = []

        elif tag in ('ul', 'ol'):
            if self.list_stack:
                self.list_stack.pop()
            self.output.append('\n')

        elif tag == 'li':
            if self.output and not self.output[-1].endswith('\n'):
                self.output.append('\n')

        elif tag in ('td', 'th'):
            cell_text = ''.join(self.cell_buffer).strip()
            cell_text = cell_text.replace('|', '\\|')  # Escape pipes
            self.row_cells.append(cell_text)
            self.in_cell = False

        elif tag == 'tr':
            if self.row_cells:
                self.table_rows.append(self.row_cells)

        elif tag == 'table':
            self._render_table()
            self.in_table = False

        elif tag == 'blockquote':
            self.output.append('\n')

    def handle_data(self, data: str):
        if self.current_link is not None:
            self.link_text.append(data)
            return

        # Check if we're inside a table cell (handles nested tags like <p> inside <td>)
        if self.in_cell:
            self.cell_buffer.append(data)
            return

        # Clean up whitespace unless in pre/code
        if not self.in_pre and not self.in_code:
            data = re.sub(r'\s+', ' ', data)

        self.output.append(data)

    def _render_table(self):
        """Render accumulated table rows as Markdown."""
        if not self.table_rows:
            return

        self.output.append('\n')

        # Header row
        if self.table_rows:
            header = self.table_rows[0]
            self.output.append('| ' + ' | '.join(header) + ' |\n')
            self.output.append('| ' + ' | '.join(['---'] * len(header)) + ' |\n')

        # Data rows
        for row in self.table_rows[1:]:
            # Pad row if needed
            while len(row) < len(self.table_rows[0]):
                row.append('')
            self.output.append('| ' + ' | '.join(row) + ' |\n')

        self.output.append('\n')

    def get_markdown(self) -> str:
        """Get the converted Markdown output."""
        result = ''.join(self.output)

        # Fix tables that got concatenated on single line
        # Pattern: | ... | | --- | ... | | data |  -> split into proper rows
        result = re.sub(r'\| \| ---', '|\n| ---', result)
        result = re.sub(r'\| \| (\d)', r'|\n| \1', result)  # Data rows starting with numbers
        result = re.sub(r'\| \| ([A-Za-z])', r'|\n| \1', result)  # Data rows starting with letters

        # Clean up excessive newlines (3+ -> 2)
        result = re.sub(r'\n{3,}', '\n\n', result)

        # Remove single blank lines between what should be continuous content
        # But keep double newlines between sections
        lines = result.split('\n')
        cleaned = []
        prev_empty = False
        for line in lines:
            is_empty = not line.strip()
            if is_empty and prev_empty:
                continue  # Skip consecutive empty lines
            cleaned.append(line)
            prev_empty = is_empty

        return '\n'.join(cleaned).strip()


def html_to_markdown(html: str) -> str:
    """
    Convert HTML string to Markdown.

    Args:
        html: HTML content to convert

    Returns:
        Markdown formatted string
    """
    converter = HTMLToMarkdownConverter()
    converter.feed(html)
    return converter.get_markdown()


def clean_text_for_markdown(text: str) -> str:
    """
    Clean plain text for Markdown output.
    Preserves line breaks and basic structure.
    """
    # Normalize line endings
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    return text.strip()
