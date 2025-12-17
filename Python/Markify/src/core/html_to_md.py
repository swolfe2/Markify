"""
HTML to Markdown converter for Clipboard Mode.
Uses only Python standard library (html.parser).
"""
from __future__ import annotations

from html.parser import HTMLParser
from typing import List, Tuple, Optional
import re


class HTMLToMarkdownConverter(HTMLParser):
    """Convert HTML to Markdown using stdlib HTMLParser."""
    
    def __init__(self):
        super().__init__()
        self.output: List[str] = []
        self.tag_stack: List[str] = []
        self.list_stack: List[Tuple[str, int]] = []  # (type, counter)
        self.in_pre = False
        self.in_code = False
        self.current_link: Optional[str] = None
        self.link_text: List[str] = []
        self.cell_buffer: List[str] = []
        self.row_cells: List[str] = []
        self.table_rows: List[List[str]] = []
        self.in_table = False
    
    def handle_starttag(self, tag: str, attrs: List[Tuple[str, Optional[str]]]):
        tag = tag.lower()
        self.tag_stack.append(tag)
        attrs_dict = dict(attrs)
        
        if tag in ('h1', 'h2', 'h3', 'h4', 'h5', 'h6'):
            level = int(tag[1])
            self.output.append('\n' + '#' * level + ' ')
        
        elif tag == 'p':
            if self.output and not self.output[-1].endswith('\n\n'):
                self.output.append('\n\n')
        
        elif tag == 'br':
            self.output.append('\n')
        
        elif tag in ('strong', 'b'):
            self.output.append('**')
        
        elif tag in ('em', 'i'):
            self.output.append('*')
        
        elif tag == 'code':
            self.in_code = True
            if not self.in_pre:
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
        
        elif tag == 'hr':
            self.output.append('\n---\n')
        
        elif tag == 'blockquote':
            self.output.append('\n> ')
    
    def handle_endtag(self, tag: str):
        tag = tag.lower()
        
        if self.tag_stack and self.tag_stack[-1] == tag:
            self.tag_stack.pop()
        
        if tag in ('h1', 'h2', 'h3', 'h4', 'h5', 'h6'):
            self.output.append('\n\n')
        
        elif tag == 'p':
            self.output.append('\n')
        
        elif tag in ('strong', 'b'):
            self.output.append('**')
        
        elif tag in ('em', 'i'):
            self.output.append('*')
        
        elif tag == 'code':
            self.in_code = False
            if not self.in_pre:
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
        
        if self.in_table and self.tag_stack and self.tag_stack[-1] in ('td', 'th'):
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
        # Clean up excessive newlines
        result = re.sub(r'\n{3,}', '\n\n', result)
        return result.strip()


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
