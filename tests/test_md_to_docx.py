"""
Unit tests for the MD to DOCX conversion utilities.
"""
import os
import sys
import tempfile
import unittest
import zipfile

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from core.md_to_docx import (
    CodeBlock,
    Heading,
    ListItem,
    Paragraph,
    convert_md_file,
    create_docx,
    generate_document_xml,
    parse_markdown,
)


class TestParseMarkdown(unittest.TestCase):
    """Tests for the parse_markdown() function."""

    def test_parse_heading(self):
        """Test parsing markdown headings."""
        blocks = parse_markdown("# Heading 1\n\n## Heading 2")
        self.assertEqual(len(blocks), 2)
        self.assertIsInstance(blocks[0], Heading)
        self.assertEqual(blocks[0].level, 1)
        self.assertEqual(blocks[0].text, "Heading 1")
        self.assertEqual(blocks[1].level, 2)

    def test_parse_paragraph(self):
        """Test parsing regular paragraphs."""
        blocks = parse_markdown("This is a paragraph.\n\nAnother paragraph.")
        self.assertEqual(len(blocks), 2)
        self.assertIsInstance(blocks[0], Paragraph)
        self.assertEqual(blocks[0].text, "This is a paragraph.")

    def test_parse_code_block(self):
        """Test parsing fenced code blocks."""
        content = "```python\nprint('hello')\n```"
        blocks = parse_markdown(content)
        self.assertEqual(len(blocks), 1)
        self.assertIsInstance(blocks[0], CodeBlock)
        self.assertEqual(blocks[0].language, "python")
        self.assertEqual(blocks[0].code, "print('hello')")

    def test_parse_list_items(self):
        """Test parsing bullet list items."""
        content = "- Item 1\n- Item 2\n- Item 3"
        blocks = parse_markdown(content)
        self.assertEqual(len(blocks), 3)
        for block in blocks:
            self.assertIsInstance(block, ListItem)

    def test_skip_front_matter(self):
        """Test that YAML front matter is skipped."""
        content = "---\ntitle: Test\ndate: 2024-01-01\n---\n\n# Real Content"
        blocks = parse_markdown(content)
        self.assertEqual(len(blocks), 1)
        self.assertIsInstance(blocks[0], Heading)
        self.assertEqual(blocks[0].text, "Real Content")


class TestGenerateDocumentXml(unittest.TestCase):
    """Tests for XML generation."""

    def test_generates_valid_xml(self):
        """Test that generated XML has proper structure."""
        blocks = [Heading(1, "Test"), Paragraph("Content")]
        xml = generate_document_xml(blocks)

        self.assertIn('<?xml version="1.0"', xml)
        self.assertIn('<w:document', xml)
        self.assertIn('</w:document>', xml)
        self.assertIn('<w:body>', xml)

    def test_heading_has_style(self):
        """Test that headings include style reference."""
        blocks = [Heading(2, "Title")]
        xml = generate_document_xml(blocks)
        self.assertIn('w:pStyle w:val="Heading2"', xml)

    def test_code_block_uses_code_style(self):
        """Test that code blocks use Code style."""
        blocks = [CodeBlock("x = 1")]
        xml = generate_document_xml(blocks)
        self.assertIn('w:pStyle w:val="Code"', xml)

    def test_xml_escaping(self):
        """Test that special characters are escaped."""
        blocks = [Paragraph("x < y & z > w")]
        xml = generate_document_xml(blocks)
        self.assertIn("&lt;", xml)
        self.assertIn("&amp;", xml)
        self.assertIn("&gt;", xml)


class TestCreateDocx(unittest.TestCase):
    """Tests for DOCX file creation."""

    def test_creates_valid_docx(self):
        """Test that created DOCX is a valid ZIP file."""
        with tempfile.NamedTemporaryFile(suffix='.docx', delete=False) as f:
            output_path = f.name

        try:
            content = "# Hello World\n\nThis is a test."
            result = create_docx(content, output_path)

            self.assertTrue(result)
            self.assertTrue(os.path.exists(output_path))

            # Verify it's a valid ZIP
            with zipfile.ZipFile(output_path, 'r') as zf:
                names = zf.namelist()
                self.assertIn('[Content_Types].xml', names)
                self.assertIn('word/document.xml', names)
                self.assertIn('word/styles.xml', names)
        finally:
            if os.path.exists(output_path):
                os.remove(output_path)

    def test_document_xml_content(self):
        """Test that document.xml contains expected content."""
        with tempfile.NamedTemporaryFile(suffix='.docx', delete=False) as f:
            output_path = f.name

        try:
            content = "# My Title\n\nParagraph text."
            create_docx(content, output_path)

            with zipfile.ZipFile(output_path, 'r') as zf:
                doc_xml = zf.read('word/document.xml').decode('utf-8')
                self.assertIn('My Title', doc_xml)
                self.assertIn('Paragraph text', doc_xml)
        finally:
            if os.path.exists(output_path):
                os.remove(output_path)


class TestConvertMdFile(unittest.TestCase):
    """Tests for file-based conversion."""

    def test_convert_file(self):
        """Test converting an MD file to DOCX."""
        # Create temp MD file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False, encoding='utf-8') as f:
            f.write("# Test\n\nContent here.")
            md_path = f.name

        try:
            success, result = convert_md_file(md_path)
            self.assertTrue(success)
            self.assertTrue(result.endswith('.docx'))
            self.assertTrue(os.path.exists(result))

            # Clean up docx
            if os.path.exists(result):
                os.remove(result)
        finally:
            if os.path.exists(md_path):
                os.remove(md_path)

    def test_nonexistent_file(self):
        """Test handling of nonexistent file."""
        success, result = convert_md_file("/nonexistent/file.md")
        self.assertFalse(success)
        self.assertIn("not found", result.lower())


if __name__ == '__main__':
    unittest.main()
