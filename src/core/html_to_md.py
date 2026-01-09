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
        self.span_stack: list[list[str]] = []  # Track styles per span (e.g. ['bold', 'italic'])
        self.skip_content = False  # Skip content inside gray line-number spans

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]):
        tag = tag.lower()
        self.tag_stack.append(tag)
        attrs_dict = dict(attrs)

        if tag in ('h1', 'h2', 'h3', 'h4', 'h5', 'h6') or (tag == 'p' and attrs_dict.get('role') == 'heading'):
            level = 1
            if tag in ('h1', 'h2', 'h3', 'h4', 'h5', 'h6'):
                level = int(tag[1])
            elif attrs_dict.get('aria-level'):
                try:
                    level = int(attrs_dict.get('aria-level', '1'))
                except ValueError:
                    level = 1
            
            # Ensure we start on a new line
            if self.output and not self.output[-1].endswith('\n'):
                self.output.append('\n')
            self.output.append('#' * level + ' ')

        elif tag == 'p':
            # Skip if we're inside a table cell or list item - spacing is handled separately
            in_list = any(t == 'li' for t in self.tag_stack)
            if not self.in_cell and not in_list and self.output:
                last = self.output[-1]
                if not last.endswith('\n\n') and not last.endswith('\n'):
                    self.output.append('\n')

        elif tag == 'br':
            # br should create a line break in Markdown
            if self.in_cell:
                self.cell_buffer.append('  \n')
            else:
                self.output.append('  \n')

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

        elif tag == 'span':
            span_styles = []
            style = attrs_dict.get('style', '').lower()
            
            # Detect gray line-number spans from Word Online code blocks
            # Pattern: color: rgb(112, 112, 112) with non-monospace font
            is_gray_line_number = (
                'color: rgb(112, 112, 112)' in style and 
                'consolas' not in style and
                'courier' not in style and
                'monospace' not in style
            )
            if is_gray_line_number:
                span_styles.append('skip')
                self.skip_content = True
            
            if 'font-weight: bold' in style or 'font-weight:bold' in style:
                span_styles.append('bold')
                if self.in_cell:
                    self.cell_buffer.append('**')
                else:
                    self.output.append('**')
            if 'font-style: italic' in style or 'font-style:italic' in style:
                span_styles.append('italic')
                if self.in_cell:
                    self.cell_buffer.append('*')
                else:
                    self.output.append('*')
            self.span_stack.append(span_styles)

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
            self.list_stack.append(('ul', 0, attrs_dict))
            if self.output and not self.output[-1].endswith('\n'):
                self.output.append('\n')

        elif tag == 'ol':
            # Word Online split lists into separate <ol> tags, using 'start' to preserve order
            start_attr = attrs_dict.get('start', '1')
            try:
                start_val = int(start_attr)
            except ValueError:
                start_val = 1
            self.list_stack.append(('ol', start_val - 1, attrs_dict))
            if self.output and not self.output[-1].endswith('\n'):
                self.output.append('\n')

        elif tag == 'li':
            # Determine indentation level
            indent_level = len(self.list_stack) - 1
            
            # Word Online uses data-aria-level/aria-level for flat lists
            # Check current li attributes first, then parent list attributes
            aria_level = attrs_dict.get('data-aria-level') or attrs_dict.get('aria-level')
            if not aria_level and self.list_stack:
                parent_attrs = self.list_stack[-1][2]
                aria_level = parent_attrs.get('data-aria-level') or parent_attrs.get('aria-level')

            if aria_level:
                try:
                    # data-aria-level starts at 1
                    indent_level = int(aria_level) - 1
                except ValueError:
                    pass

            # Fallback: Check style for margin-left/padding-left (common in Word Online flattened lists)
            if indent_level == 0:
                style = attrs_dict.get('style', '').lower()
                # Parse margin-left: Xpx/pt/em;
                match = re.search(r'(?:margin|padding)-left:\s*([0-9.]+)(px|pt|em)', style)
                if match:
                    try:
                        val = float(match.group(1))
                        unit = match.group(2)
                        
                        # Convert to px equivalent
                        px = val
                        if unit == 'pt':
                            px = val * 1.33
                        elif unit == 'em':
                            px = val * 16
                            
                        # Estimate level: Word often uses ~36px or ~48px per level
                        # Level 1 usually has some margin too (e.g. 48px), so we might need a threshold
                        # Let's assume > 15px implies indentation
                        if px >= 15: 
                            # Divide by ~20 to get level (e.g. 20px = 1 level, 40px = 2 levels)
                            # This is more sensitive to smaller indents
                            indent_level = int(px / 20)
                    except ValueError:
                        pass

            indent = '    ' * indent_level
            if self.list_stack:
                list_type, counter, _ = self.list_stack[-1]
                if list_type == 'ul':
                    self.output.append(f'{indent}- ')
                else:
                    counter += 1
                    self.list_stack[-1] = (list_type, counter, _)
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
            # End paragraph with double newline for block separation
            # Skip if we're inside a table cell - spacing is handled separately
            if not self.in_cell:
                # If we're inside a list, just a single newline is usually better
                in_list = any(t == 'li' for t in self.tag_stack)
                newline = '\n' if in_list else '\n\n'
                if self.output and not self.output[-1].endswith(newline):
                    # If it ends with just one \n, add the second one
                    if self.output[-1].endswith('\n'):
                        self.output.append('\n')
                    else:
                        self.output.append(newline)

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

        elif tag == 'span':
            if self.span_stack:
                span_styles = self.span_stack.pop()
                # Close in reverse order
                for style in reversed(span_styles):
                    if style == 'bold':
                        if self.in_cell:
                            self.cell_buffer.append('**')
                        else:
                            self.output.append('**')
                    elif style == 'italic':
                        if self.in_cell:
                            self.cell_buffer.append('*')
                        else:
                            self.output.append('*')
                    elif style == 'skip':
                        self.skip_content = False

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
        # Skip content inside gray line-number spans (Word Online code blocks)
        if self.skip_content:
            return
        
        if self.current_link is not None:
            self.link_text.append(data)
            return

        # Check if we're inside a table cell (handles nested tags like <p> inside <td>)
        if self.in_cell:
            self.cell_buffer.append(data)
            return

        # Clean up whitespace unless in pre/code
        if not self.in_pre and not self.in_code:
            # Preserve intentional single newlines but collapse multi-space/multi-newline
            data = re.sub(r'[ \t\r\f\v]+', ' ', data)
            # If data is just a newline, keep it as is or collapse if redundant
            # For now, let's just do the basic collapse but avoid killing all newlines
            data = data.replace('\r\n', '\n').replace('\r', '\n')
            data = re.sub(r'\n{2,}', '\n\n', data)

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
