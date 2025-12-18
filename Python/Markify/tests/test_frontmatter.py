"""
Unit tests for the front matter generation utilities.
"""
import unittest
import sys
import os
from datetime import datetime

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from core.frontmatter import (
    generate_front_matter,
    generate_slug,
    extract_title_from_markdown,
    add_front_matter_to_markdown,
)


class TestGenerateSlug(unittest.TestCase):
    """Tests for the generate_slug() function."""
    
    def test_simple_filename(self):
        """Test slug generation from simple filename."""
        self.assertEqual(generate_slug("My Document.docx"), "my-document")
    
    def test_underscores_to_hyphens(self):
        """Test that underscores are converted to hyphens."""
        self.assertEqual(generate_slug("my_file_name.md"), "my-file-name")
    
    def test_special_characters_removed(self):
        """Test that special characters are removed."""
        self.assertEqual(generate_slug("Report (2024).docx"), "report-2024")
    
    def test_consecutive_hyphens_collapsed(self):
        """Test that consecutive hyphens are collapsed."""
        self.assertEqual(generate_slug("foo---bar.txt"), "foo-bar")
    
    def test_leading_trailing_hyphens_removed(self):
        """Test that leading/trailing hyphens are removed."""
        self.assertEqual(generate_slug("--test--.md"), "test")


class TestExtractTitle(unittest.TestCase):
    """Tests for extract_title_from_markdown()."""
    
    def test_extract_h1_heading(self):
        """Test extracting H1 heading as title."""
        content = "# My Document Title\n\nSome content here."
        self.assertEqual(extract_title_from_markdown(content), "My Document Title")
    
    def test_extract_h2_heading(self):
        """Test that H1 is preferred over H2."""
        content = "Some intro\n## Section Title\n\nContent"
        # Fallback to first non-empty line
        self.assertEqual(extract_title_from_markdown(content), "Some intro")
    
    def test_no_heading_fallback(self):
        """Test fallback to first non-empty line."""
        content = "First line of document\nSecond line"
        self.assertEqual(extract_title_from_markdown(content), "First line of document")
    
    def test_empty_content(self):
        """Test empty content returns None."""
        self.assertIsNone(extract_title_from_markdown(""))


class TestGenerateFrontMatter(unittest.TestCase):
    """Tests for the generate_front_matter() function."""
    
    def test_basic_front_matter(self):
        """Test basic front matter generation."""
        result = generate_front_matter(title="Test Doc")
        self.assertTrue(result.startswith("---"))
        self.assertTrue(result.endswith("---"))
        self.assertIn('title: "Test Doc"', result)
    
    def test_includes_date(self):
        """Test that date is always included."""
        result = generate_front_matter(title="Test")
        self.assertIn("date:", result)
    
    def test_custom_date(self):
        """Test custom date formatting."""
        test_date = datetime(2024, 12, 25, 10, 30, 0)
        result = generate_front_matter(title="Test", date=test_date)
        self.assertIn("2024-12-25T10:30:00", result)
    
    def test_author_included(self):
        """Test author field."""
        result = generate_front_matter(title="Test", author="John Doe")
        self.assertIn('author: "John Doe"', result)
    
    def test_tags_list(self):
        """Test tags as YAML list."""
        result = generate_front_matter(title="Test", tags=["python", "testing"])
        self.assertIn("tags:", result)
        self.assertIn('- "python"', result)
        self.assertIn('- "testing"', result)
    
    def test_slug_from_filename(self):
        """Test slug generation from filename."""
        result = generate_front_matter(title="Test", filename="My Document.docx")
        self.assertIn('slug: "my-document"', result)
    
    def test_draft_flag(self):
        """Test draft flag."""
        result = generate_front_matter(title="Test", draft=True)
        self.assertIn("draft: true", result)


class TestAddFrontMatter(unittest.TestCase):
    """Tests for add_front_matter_to_markdown()."""
    
    def test_adds_front_matter(self):
        """Test that front matter is added to content."""
        content = "# My Title\n\nSome content here."
        result = add_front_matter_to_markdown(content, filename="test.docx")
        
        self.assertTrue(result.startswith("---"))
        self.assertIn('title: "My Title"', result)
        self.assertIn(content, result)
    
    def test_auto_extracts_title(self):
        """Test auto-extraction of title from first heading."""
        content = "# Extracted Title\n\nRest of doc"
        result = add_front_matter_to_markdown(content)
        self.assertIn('title: "Extracted Title"', result)
    
    def test_skips_existing_front_matter(self):
        """Test that existing front matter is not duplicated."""
        content = "---\ntitle: Existing\n---\n\n# Content"
        result = add_front_matter_to_markdown(content)
        self.assertEqual(result, content)  # Unchanged
    
    def test_custom_title_overrides(self):
        """Test that explicit title overrides auto-detection."""
        content = "# Auto Title\n\nContent"
        result = add_front_matter_to_markdown(content, title="Custom Title")
        self.assertIn('title: "Custom Title"', result)
        self.assertNotIn('title: "Auto Title"', result)


if __name__ == '__main__':
    unittest.main()
