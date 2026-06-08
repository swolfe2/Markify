"""
Tests for syntax highlighting features (Feature #2).
"""
from __future__ import annotations

import unittest
from unittest.mock import MagicMock
import tkinter as tk

from themes import SYNTAX_THEMES, get_syntax_theme, get_syntax_theme_names
from ui.syntax_highlighter import apply_syntax_highlighting, highlight_line_content

class MockTextWidget:
    """Mock Tkinter Text widget to record tag applications for testing."""
    def __init__(self):
        self.tags = []
        self.configs = {}
        self.raises = []

    def tag_add(self, name, start, end):
        self.tags.append((name, start, end))

    def tag_configure(self, name, **kwargs):
        self.configs[name] = kwargs

    def tag_remove(self, name, start, end):
        # Filter out tag matches
        self.tags = [t for t in self.tags if t[0] != name]

    def tag_raise(self, name, above=None):
        self.raises.append((name, above))

    def get(self, start, end):
        return ""


class TestSyntaxHighlighting(unittest.TestCase):
    def test_themes_exist(self):
        """Verify the predefined syntax themes are accessible."""
        theme_names = get_syntax_theme_names()
        self.assertIn("One Dark", theme_names)
        self.assertIn("Monokai", theme_names)
        self.assertIn("Dracula", theme_names)
        self.assertIn("GitHub Light", theme_names)

        theme = get_syntax_theme("One Dark")
        self.assertEqual(theme["bg"], "#282c34")
        self.assertTrue(theme["is_dark"])

        light_theme = get_syntax_theme("GitHub Light")
        self.assertFalse(light_theme["is_dark"])

    def test_apply_highlighting_markdown_headers(self):
        """Test markdown header detection in apply_syntax_highlighting."""
        widget = MockTextWidget()
        content = "# Main Header\nSome regular text\n## Sub Heading"
        
        apply_syntax_highlighting(widget, content, "One Dark")
        
        # We expect markdown_header tag to be added
        header_tags = [t for t in widget.tags if t[0] == "markdown_header"]
        self.assertEqual(len(header_tags), 2)
        self.assertEqual(header_tags[0][1], "1.0")
        self.assertEqual(header_tags[1][1], "3.0")

    def test_apply_highlighting_code_blocks(self):
        """Test code fence block identification."""
        widget = MockTextWidget()
        content = "```python\nx = 42\n```"
        
        apply_syntax_highlighting(widget, content, "One Dark")
        
        # code fence lines and content lines get syntax_bg tag
        bg_tags = [t for t in widget.tags if t[0] == "syntax_bg"]
        self.assertEqual(len(bg_tags), 3) # lines 1, 2, 3
        
        # Python keyword detect on line 2
        content_kw = "```python\nimport sys\n```"
        widget = MockTextWidget()
        apply_syntax_highlighting(widget, content_kw, "One Dark")
        
        kw_tags = [t for t in widget.tags if t[0] == "syntax_keyword"]
        self.assertEqual(len(kw_tags), 1)
        self.assertEqual(kw_tags[0][1], "2.0")

    def test_languages_highlight_rules(self):
        """Test specific language highlighting token rules."""
        # 1. Python
        widget = MockTextWidget()
        patterns = {
            "python_keywords": ["def", "import"],
            "python_builtins": ["print"]
        }
        highlight_line_content(widget, 1, "def test(): # comment", "python", patterns, True)
        
        comments = [t for t in widget.tags if t[0] == "syntax_comment"]
        keywords = [t for t in widget.tags if t[0] == "syntax_keyword"]
        self.assertEqual(len(comments), 1)
        self.assertEqual(comments[0][1], "1.12") # '#' is at column 12
        self.assertEqual(len(keywords), 1)
        self.assertEqual(keywords[0][1], "1.0")  # 'def' is at column 0

        # 2. SQL
        widget = MockTextWidget()
        patterns = {
            "sql_keywords": ["SELECT", "FROM"],
            "sql_functions": ["COUNT"]
        }
        highlight_line_content(widget, 2, "select count(*) -- sql comment", "sql", patterns, True)
        comments = [t for t in widget.tags if t[0] == "syntax_comment"]
        keywords = [t for t in widget.tags if t[0] == "syntax_keyword"]
        builtins = [t for t in widget.tags if t[0] == "syntax_builtin"]
        
        self.assertEqual(len(comments), 1)
        self.assertEqual(comments[0][1], "2.16")
        self.assertEqual(len(keywords), 1)
        self.assertEqual(keywords[0][1], "2.0")
        self.assertEqual(len(builtins), 1)
        self.assertEqual(builtins[0][1], "2.7")

        # 3. DAX
        widget = MockTextWidget()
        patterns = {
            "dax_keywords": ["EVALUATE", "VAR"],
            "dax_functions": ["SUM"]
        }
        highlight_line_content(widget, 3, "EVALUATE // dax comment", "dax", patterns, True)
        comments = [t for t in widget.tags if t[0] == "syntax_comment"]
        keywords = [t for t in widget.tags if t[0] == "syntax_keyword"]
        self.assertEqual(len(comments), 1)
        self.assertEqual(keywords[0][1], "3.0")

        # 4. Power Query
        widget = MockTextWidget()
        patterns = {
            "powerquery_exact_matches": ["let", "in"],
            "powerquery_functions": ["Web.Contents"]
        }
        highlight_line_content(widget, 4, "let Source = Web.Contents()", "pq", patterns, True)
        keywords = [t for t in widget.tags if t[0] == "syntax_keyword"]
        builtins = [t for t in widget.tags if t[0] == "syntax_builtin"]
        self.assertEqual(len(keywords), 1)
        self.assertEqual(keywords[0][1], "4.0")
        self.assertEqual(len(builtins), 1)
        self.assertEqual(builtins[0][1], "4.13")
