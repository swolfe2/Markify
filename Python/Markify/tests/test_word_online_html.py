import os
import sys
import unittest

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from core.html_to_md import html_to_markdown


class TestWordOnlineHTML(unittest.TestCase):
    def test_aria_headings(self):
        """Test that <p role='heading'> is converted to Markdown headers."""
        html = '<p role="heading" aria-level="1">Title</p>'
        md = html_to_markdown(html)
        self.assertEqual(md.strip(), "# Title")

        html = '<p role="heading" aria-level="2">Sub Title</p>'
        md = html_to_markdown(html)
        self.assertEqual(md.strip(), "## Sub Title")

    def test_styled_spans(self):
        """Test that bold/italic in style attributes are captured."""
        html = '<span style="font-weight: bold">Bold Text</span>'
        md = html_to_markdown(html)
        self.assertEqual(md.strip(), "**Bold Text**")

        html = '<span style="font-style: italic">Italic Text</span>'
        md = html_to_markdown(html)
        self.assertEqual(md.strip(), "*Italic Text*")

    def test_flattened_lists(self):
        """Test that flattened lists with data-aria-level are indented."""
        # Word Online often puts each item in its own <ul> and uses data-aria-level
        html = """
        <ul data-aria-level="1"><li>Level 1 Item</li></ul>
        <ul data-aria-level="2"><li>Level 2 Item</li></ul>
        """
        md = html_to_markdown(html)
        self.assertIn("- Level 1 Item", md)
        self.assertIn("  - Level 2 Item", md)

    def test_line_merging(self):
        """Test that multiple paragraphs aren't merged into a single line."""
        html = "<p>Line 1</p><p>Line 2</p>"
        md = html_to_markdown(html)
        # Markdown source should have at least one newline
        self.assertEqual(md.strip(), "Line 1\n\nLine 2")

    def test_br_tag(self):
        """Test that <br> creates a newline, not a space."""
        html = "<p>Line 1<br>Line 2</p>"
        md = html_to_markdown(html)
        # Use two spaces + newline for a Markdown line break
        self.assertEqual(md.strip(), "Line 1  \nLine 2")

    def test_list_numbering_start(self):
        """Test that <ol start=\"N\"> is respected."""
        html = '<ol start=\"5\"><li>Item 5</li></ol><ol start=\"6\"><li>Item 6</li></ol>'
        md = html_to_markdown(html)
        self.assertIn("5. Item 5", md)
        self.assertIn("6. Item 6", md)

    # NOTE: Monospace span detection was removed because Word Online wraps
    # EACH WORD in a separate <span> with the font style, causing every word
    # to get its own backticks. A paragraph-level approach would be needed.

if __name__ == '__main__':
    unittest.main()
