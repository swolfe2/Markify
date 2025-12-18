"""
Unit tests for the template system.
"""
import unittest
import sys
import os
import tempfile

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from core.templates import (
    build_context,
    apply_template,
    process_with_template,
    load_template,
    save_template,
    get_default_template,
    get_frontmatter_template,
    extract_variables,
    get_available_variables,
)


class TestBuildContext(unittest.TestCase):
    """Tests for build_context()."""
    
    def test_includes_all_standard_variables(self):
        """Test that context includes all expected variables."""
        context = build_context(filename="test.docx", content="Hello")
        
        self.assertIn("{{filename}}", context)
        self.assertIn("{{title}}", context)
        self.assertIn("{{date}}", context)
        self.assertIn("{{content}}", context)
    
    def test_filename_extraction(self):
        """Test filename is extracted correctly."""
        context = build_context(filename="/path/to/my_document.docx")
        
        self.assertEqual(context["{{filename}}"], "my_document")
        self.assertEqual(context["{{filename_ext}}"], "my_document.docx")
    
    def test_title_auto_derived(self):
        """Test that title is auto-derived from filename."""
        context = build_context(filename="my-document.docx")
        self.assertEqual(context["{{title}}"], "My Document")
    
    def test_title_override(self):
        """Test that explicit title takes precedence."""
        context = build_context(filename="test.docx", title="Custom Title")
        self.assertEqual(context["{{title}}"], "Custom Title")
    
    def test_custom_variables(self):
        """Test adding custom variables."""
        context = build_context(custom_vars={"project": "Markify"})
        self.assertEqual(context["{{project}}"], "Markify")
    
    def test_date_format(self):
        """Test date is in ISO format."""
        import re
        context = build_context()
        # YYYY-MM-DD format
        self.assertRegex(context["{{date}}"], r'^\d{4}-\d{2}-\d{2}$')


class TestApplyTemplate(unittest.TestCase):
    """Tests for apply_template()."""
    
    def test_simple_substitution(self):
        """Test basic variable substitution."""
        template = "Hello {{name}}!"
        context = {"{{name}}": "World"}
        result = apply_template(template, context)
        self.assertEqual(result, "Hello World!")
    
    def test_multiple_variables(self):
        """Test multiple variables in template."""
        template = "{{a}} + {{b}} = {{c}}"
        context = {"{{a}}": "1", "{{b}}": "2", "{{c}}": "3"}
        result = apply_template(template, context)
        self.assertEqual(result, "1 + 2 = 3")
    
    def test_repeated_variable(self):
        """Test same variable used multiple times."""
        template = "{{x}} and {{x}}"
        context = {"{{x}}": "test"}
        result = apply_template(template, context)
        self.assertEqual(result, "test and test")


class TestProcessWithTemplate(unittest.TestCase):
    """Tests for process_with_template()."""
    
    def test_default_template(self):
        """Test that default template just returns content."""
        result = process_with_template("Hello World")
        self.assertEqual(result, "Hello World")
    
    def test_custom_template(self):
        """Test with custom template."""
        template = "# {{title}}\n\n{{content}}"
        result = process_with_template(
            content="Body text",
            template=template,
            filename="test.docx"
        )
        self.assertIn("# Test", result)
        self.assertIn("Body text", result)
    
    def test_frontmatter_template(self):
        """Test using front matter template."""
        template = get_frontmatter_template()
        result = process_with_template(
            content="Content here",
            template=template,
            filename="my_doc.docx"
        )
        self.assertIn("---", result)
        self.assertIn("title:", result)
        self.assertIn("Content here", result)


class TestLoadSaveTemplate(unittest.TestCase):
    """Tests for template file operations."""
    
    def test_save_and_load(self):
        """Test saving and loading a template."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', 
                                         delete=False) as f:
            path = f.name
        
        try:
            template = "Test {{variable}}"
            self.assertTrue(save_template(path, template))
            
            loaded = load_template(path)
            self.assertEqual(loaded, template)
        finally:
            if os.path.exists(path):
                os.remove(path)
    
    def test_load_nonexistent(self):
        """Test loading nonexistent file."""
        result = load_template("/nonexistent/path.txt")
        self.assertIsNone(result)


class TestExtractVariables(unittest.TestCase):
    """Tests for extract_variables()."""
    
    def test_extracts_variables(self):
        """Test extracting variable names."""
        template = "Hello {{name}}, today is {{date}}"
        vars = extract_variables(template)
        self.assertIn("name", vars)
        self.assertIn("date", vars)
    
    def test_no_duplicates(self):
        """Test no duplicate variable names."""
        template = "{{x}} and {{x}} and {{y}}"
        vars = extract_variables(template)
        self.assertEqual(len([v for v in vars if v == "x"]), 1)


class TestGetAvailableVariables(unittest.TestCase):
    """Tests for get_available_variables()."""
    
    def test_returns_dict(self):
        """Test that it returns a dictionary."""
        vars = get_available_variables()
        self.assertIsInstance(vars, dict)
    
    def test_has_descriptions(self):
        """Test that variables have descriptions."""
        vars = get_available_variables()
        self.assertIn("{{content}}", vars)
        self.assertTrue(len(vars["{{content}}"]) > 0)


if __name__ == '__main__':
    unittest.main()
