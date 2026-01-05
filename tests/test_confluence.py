"""
Unit tests for the Confluence Wiki Syntax converter.
"""
import os
import sys
import unittest

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from core.confluence import (
    _convert_inline,
    _convert_line,
    convert_table,
    full_convert,
    markdown_to_confluence,
)


class TestHeadings(unittest.TestCase):
    """Tests for heading conversion."""

    def test_h1(self):
        """Test H1 conversion."""
        result = markdown_to_confluence("# Heading 1")
        self.assertEqual(result, "h1. Heading 1")

    def test_h2(self):
        """Test H2 conversion."""
        result = markdown_to_confluence("## Heading 2")
        self.assertEqual(result, "h2. Heading 2")

    def test_h3(self):
        """Test H3 conversion."""
        result = markdown_to_confluence("### Heading 3")
        self.assertEqual(result, "h3. Heading 3")


class TestLists(unittest.TestCase):
    """Tests for list conversion."""

    def test_unordered_list(self):
        """Test unordered list conversion."""
        md = "- Item 1\n- Item 2"
        result = markdown_to_confluence(md)
        self.assertIn("* Item 1", result)
        self.assertIn("* Item 2", result)

    def test_ordered_list(self):
        """Test ordered list conversion."""
        md = "1. First\n2. Second"
        result = markdown_to_confluence(md)
        self.assertIn("# First", result)
        self.assertIn("# Second", result)

    def test_nested_list(self):
        """Test nested list indentation."""
        md = "- Level 1\n  - Level 2"
        result = markdown_to_confluence(md)
        self.assertIn("* Level 1", result)
        self.assertIn("** Level 2", result)


class TestCodeBlocks(unittest.TestCase):
    """Tests for code block conversion."""

    def test_code_block_with_language(self):
        """Test fenced code block with language."""
        md = "```python\nprint('hello')\n```"
        result = markdown_to_confluence(md)
        self.assertIn("{code:language=python}", result)
        self.assertIn("print('hello')", result)
        self.assertIn("{code}", result)

    def test_code_block_no_language(self):
        """Test fenced code block without language."""
        md = "```\nsome code\n```"
        result = markdown_to_confluence(md)
        self.assertIn("{code}", result)
        self.assertIn("some code", result)


class TestInlineFormatting(unittest.TestCase):
    """Tests for inline formatting conversion."""

    def test_bold(self):
        """Test bold conversion."""
        result = _convert_inline("**bold text**")
        self.assertEqual(result, "*bold text*")

    def test_inline_code(self):
        """Test inline code conversion."""
        result = _convert_inline("Use `code` here")
        self.assertEqual(result, "Use {{code}} here")

    def test_links(self):
        """Test link conversion."""
        result = _convert_inline("[Google](https://google.com)")
        self.assertEqual(result, "[Google|https://google.com]")

    def test_images(self):
        """Test image conversion."""
        result = _convert_inline("![Alt text](image.png)")
        self.assertEqual(result, "!image.png!")

    def test_strikethrough(self):
        """Test strikethrough conversion."""
        result = _convert_inline("~~deleted~~")
        self.assertEqual(result, "-deleted-")


class TestTables(unittest.TestCase):
    """Tests for table conversion."""

    def test_simple_table(self):
        """Test simple table conversion."""
        md = "| Header 1 | Header 2 |\n|----------|----------|\n| Cell 1 | Cell 2 |"
        result = convert_table(md)
        self.assertIn("||Header 1||Header 2||", result)
        self.assertIn("|Cell 1|Cell 2|", result)


class TestBlockquotes(unittest.TestCase):
    """Tests for blockquote conversion."""

    def test_blockquote(self):
        """Test blockquote conversion."""
        result = _convert_line("> This is a quote")
        self.assertIn("{quote}", result)
        self.assertIn("This is a quote", result)


class TestHorizontalRule(unittest.TestCase):
    """Tests for horizontal rule conversion."""

    def test_hr(self):
        """Test horizontal rule conversion."""
        result = _convert_line("---")
        self.assertEqual(result, "----")


class TestFullConvert(unittest.TestCase):
    """Tests for full_convert() function."""

    def test_mixed_content(self):
        """Test conversion of mixed content."""
        md = """# Title

Some **bold** text.

- List item

```python
code()
```
"""
        result = full_convert(md)
        self.assertIn("h1. Title", result)
        self.assertIn("*bold*", result)
        self.assertIn("* List item", result)
        self.assertIn("{code:language=python}", result)


if __name__ == '__main__':
    unittest.main()
