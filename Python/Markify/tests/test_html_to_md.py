"""
Tests for HTML to Markdown converter.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from core.html_to_md import clean_text_for_markdown, html_to_markdown


class TestHtmlToMarkdown:
    """Tests for html_to_markdown function."""

    def test_simple_paragraph(self):
        """Test basic paragraph conversion."""
        html = "<p>Hello world</p>"
        result = html_to_markdown(html)
        assert "Hello world" in result

    def test_headings(self):
        """Test heading conversion."""
        html = "<h1>Title</h1><h2>Subtitle</h2>"
        result = html_to_markdown(html)
        assert "# Title" in result
        assert "## Subtitle" in result

    def test_bold_italic(self):
        """Test bold and italic formatting."""
        html = "<p>This is <strong>bold</strong> and <em>italic</em></p>"
        result = html_to_markdown(html)
        assert "**bold**" in result
        assert "*italic*" in result

    def test_links(self):
        """Test hyperlink conversion."""
        html = '<p>Visit <a href="https://example.com">Example</a></p>'
        result = html_to_markdown(html)
        assert "[Example](https://example.com)" in result

    def test_unordered_list(self):
        """Test unordered list conversion."""
        html = "<ul><li>Item 1</li><li>Item 2</li></ul>"
        result = html_to_markdown(html)
        assert "- Item 1" in result
        assert "- Item 2" in result

    def test_ordered_list(self):
        """Test ordered list conversion."""
        html = "<ol><li>First</li><li>Second</li></ol>"
        result = html_to_markdown(html)
        assert "1. First" in result
        assert "2. Second" in result

    def test_code_block(self):
        """Test code block conversion."""
        html = "<pre><code>let x = 1</code></pre>"
        result = html_to_markdown(html)
        assert "```" in result
        assert "let x = 1" in result

    def test_inline_code(self):
        """Test inline code conversion."""
        html = "<p>Use <code>print()</code> function</p>"
        result = html_to_markdown(html)
        assert "`print()`" in result

    def test_table_basic(self):
        """Test basic table conversion."""
        html = """
        <table>
            <tr><th>Name</th><th>Age</th></tr>
            <tr><td>Alice</td><td>30</td></tr>
        </table>
        """
        result = html_to_markdown(html)
        assert "| Name | Age |" in result
        assert "| --- | --- |" in result
        assert "| Alice | 30 |" in result

    def test_table_row_splitting(self):
        """Test that concatenated table rows get properly split."""
        # Simulating the kind of output that needs fixing
        html = """<table><tr><th>ID</th><th>Name</th></tr><tr><td>001</td><td>Bob</td></tr></table>"""
        result = html_to_markdown(html)
        lines = [line for line in result.split('\n') if line.strip()]
        # Should have separate lines for header, separator, and data
        assert len(lines) >= 3

    def test_excessive_newlines_cleanup(self):
        """Test that excessive newlines are cleaned up."""
        html = "<p>Para 1</p><p></p><p></p><p>Para 2</p>"
        result = html_to_markdown(html)
        # Should not have more than 2 consecutive newlines
        assert "\n\n\n" not in result

    def test_br_handling(self):
        """Test that br tags don't cause excessive line breaks."""
        html = "<p>Line 1<br>Line 2</p>"
        result = html_to_markdown(html)
        # Should be on same logical paragraph
        lines = [line for line in result.split('\n') if line.strip()]
        assert len(lines) <= 2


class TestCleanTextForMarkdown:
    """Tests for clean_text_for_markdown function."""

    def test_basic_cleanup(self):
        """Test basic text cleanup."""
        text = "Hello\r\nWorld"
        result = clean_text_for_markdown(text)
        assert "\r" not in result
        assert "Hello" in result
        assert "World" in result

    def test_preserves_content(self):
        """Test that content is preserved."""
        text = "# Header\n\nParagraph content."
        result = clean_text_for_markdown(text)
        assert "# Header" in result
        assert "Paragraph content" in result
