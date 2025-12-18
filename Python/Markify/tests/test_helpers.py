"""
Unit tests for the core conversion logic in markify_core.py
"""
import unittest
import sys
import os

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from markify_core import (
    detect_header_level,
    is_code_content,
    is_dax_content,
    is_python_content,
    detect_code_language
)


class TestIsCodeContent(unittest.TestCase):
    """Tests for the is_code_content() function."""

    def test_let_keyword(self):
        self.assertTrue(is_code_content("let"))
        self.assertTrue(is_code_content("let "))
        self.assertTrue(is_code_content("  let"))

    def test_in_keyword(self):
        self.assertTrue(is_code_content("in"))
        self.assertTrue(is_code_content("in Source"))

    def test_numbered_let(self):
        self.assertTrue(is_code_content("1 let"))
        self.assertTrue(is_code_content("12 let"))
        self.assertTrue(is_code_content("1  let"))

    def test_source_result(self):
        self.assertTrue(is_code_content("Source"))

    def test_web_contents(self):
        self.assertTrue(is_code_content("Web.Contents(url)"))
        self.assertTrue(is_code_content('result = Web.Contents("https://api.example.com")'))

    def test_json_document(self):
        self.assertTrue(is_code_content("Json.Document(response)"))

    def test_assignments(self):
        self.assertTrue(is_code_content("Source = Table.FromRecords"))
        self.assertTrue(is_code_content("ApiKey = "))

    def test_closing_patterns(self):
        self.assertTrue(is_code_content("]),"))
        self.assertTrue(is_code_content("))"))
        self.assertTrue(is_code_content(")),"))

    def test_regular_text_not_code(self):
        self.assertFalse(is_code_content("This is a regular paragraph."))
        self.assertFalse(is_code_content("Hello World"))
        self.assertFalse(is_code_content("The letter should be sent."))


class TestIsDaxContent(unittest.TestCase):
    """Tests for the is_dax_content() function."""

    def test_evaluate_keyword(self):
        self.assertTrue(is_dax_content("EVALUATE"))
        self.assertTrue(is_dax_content("EVALUATE Sales"))
        self.assertTrue(is_dax_content("evaluate customers"))

    def test_calculate_functions(self):
        self.assertTrue(is_dax_content("CALCULATE(SUM(Sales[Amount]))"))
        self.assertTrue(is_dax_content("CALCULATETABLE(Products, Products[Category] = \"Bikes\")"))

    def test_measure_definition(self):
        self.assertTrue(is_dax_content("Revenue := SUMX(Sales, Sales[Qty] * Sales[Price])"))
        self.assertTrue(is_dax_content("Total Sales := SUM(Sales[Amount])"))

    def test_table_column_reference(self):
        self.assertTrue(is_dax_content("Sales[Amount]"))
        self.assertTrue(is_dax_content("'Date Table'[Year]"))

    def test_dax_aggregations(self):
        self.assertTrue(is_dax_content("SUMX(Sales, Sales[Qty])"))
        self.assertTrue(is_dax_content("AVERAGEX(Products, Products[Price])"))
        self.assertTrue(is_dax_content("COUNTROWS(Customers)"))

    def test_filter_functions(self):
        self.assertTrue(is_dax_content("FILTER(Products, Products[Price] > 100)"))
        self.assertTrue(is_dax_content("ALL(Products)"))

    def test_not_dax(self):
        self.assertFalse(is_dax_content("This is regular text."))
        self.assertFalse(is_dax_content("let x = 5"))


class TestIsPythonContent(unittest.TestCase):
    """Tests for the is_python_content() function."""

    def test_def_keyword(self):
        self.assertTrue(is_python_content("def calculate_total():"))
        self.assertTrue(is_python_content("def main():"))

    def test_class_keyword(self):
        self.assertTrue(is_python_content("class MyClass:"))
        self.assertTrue(is_python_content("class Calculator(BaseClass):"))

    def test_import_statements(self):
        self.assertTrue(is_python_content("import pandas as pd"))
        self.assertTrue(is_python_content("from datetime import datetime"))

    def test_decorators(self):
        self.assertTrue(is_python_content("@property"))
        self.assertTrue(is_python_content("@staticmethod"))

    def test_main_block(self):
        self.assertTrue(is_python_content('if __name__ == "__main__":'))

    def test_builtins(self):
        self.assertTrue(is_python_content('print("Hello")'))
        self.assertTrue(is_python_content("len(my_list)"))
        self.assertTrue(is_python_content("range(10)"))

    def test_not_python(self):
        self.assertFalse(is_python_content("This is regular text."))
        self.assertFalse(is_python_content("EVALUATE Sales"))


class TestDetectCodeLanguage(unittest.TestCase):
    """Tests for the detect_code_language() function."""

    def test_powerquery_detection(self):
        self.assertEqual(detect_code_language("let Source = Table.FromRecords"), "powerquery")
        self.assertEqual(detect_code_language("Web.Contents(url)"), "powerquery")

    def test_dax_detection(self):
        self.assertEqual(detect_code_language("EVALUATE CALCULATETABLE(Sales)"), "dax")
        self.assertEqual(detect_code_language("Revenue := SUM(Sales[Amount])"), "dax")

    def test_python_detection(self):
        self.assertEqual(detect_code_language("def main():"), "python")
        self.assertEqual(detect_code_language("import pandas as pd"), "python")

    def test_no_code_detected(self):
        self.assertIsNone(detect_code_language("This is regular text."))
        self.assertIsNone(detect_code_language("Hello World"))


class TestDetectHeaderLevel(unittest.TestCase):
    """Tests for the detect_header_level() function."""

    def test_emoji_header_level_1(self):
        self.assertEqual(detect_header_level("🔐 Security Configuration"), 1)
        self.assertEqual(detect_header_level("✅ Completed Tasks"), 1)
        self.assertEqual(detect_header_level("🔄 Data Refresh"), 1)

    def test_emoji_header_level_2(self):
        self.assertEqual(detect_header_level("✅ 1. First Step"), 2)
        self.assertEqual(detect_header_level("🔐 2. Second Step"), 2)

    def test_numbered_header_level_3(self):
        self.assertEqual(detect_header_level("1. Create & Store API Keys"), 3)
        self.assertEqual(detect_header_level("2. Configure Settings"), 3)

    def test_regular_text_no_header(self):
        self.assertEqual(detect_header_level("This is not a header"), 0)
        self.assertEqual(detect_header_level("just some text"), 0)


class TestIntegration(unittest.TestCase):
    """Integration tests that would use fixture files."""
    
    def test_placeholder(self):
        # Placeholder for fixture-based tests
        # These would use sample .docx files in tests/fixtures/
        self.assertTrue(True)


class TestConfig(unittest.TestCase):
    """Tests for the config module - pattern loading and management."""
    
    def test_default_patterns_exist(self):
        """Test that default patterns are available."""
        from config import DEFAULT_PATTERNS
        self.assertIn("dax_keywords", DEFAULT_PATTERNS)
        self.assertIn("dax_functions", DEFAULT_PATTERNS)
        self.assertIn("python_keywords", DEFAULT_PATTERNS)
        self.assertIn("python_builtins", DEFAULT_PATTERNS)
    
    def test_default_dax_keywords(self):
        """Test that default DAX keywords contain expected values."""
        from config import DEFAULT_PATTERNS
        keywords = DEFAULT_PATTERNS["dax_keywords"]
        self.assertIn("CALCULATE", keywords)
        self.assertIn("SUMX", keywords)
        self.assertIn("EVALUATE", keywords)
    
    def test_get_patterns_returns_dict(self):
        """Test that get_patterns returns a dictionary."""
        from config import get_patterns
        patterns = get_patterns()
        self.assertIsInstance(patterns, dict)
    
    def test_get_config_path(self):
        """Test that config path is valid."""
        from config import get_config_path
        path = get_config_path()
        self.assertTrue(path.endswith("detection_patterns.json"))
        self.assertIn("Markify", path)


class TestHTMLToMarkdown(unittest.TestCase):
    """Tests for the HTML to Markdown converter."""
    
    def test_basic_paragraph(self):
        """Test basic paragraph conversion."""
        from core.html_to_md import html_to_markdown
        html = "<p>Hello World</p>"
        result = html_to_markdown(html)
        self.assertIn("Hello World", result)
    
    def test_headers(self):
        """Test header conversion."""
        from core.html_to_md import html_to_markdown
        html = "<h1>Title</h1><h2>Subtitle</h2>"
        result = html_to_markdown(html)
        self.assertIn("# Title", result)
        self.assertIn("## Subtitle", result)
    
    def test_bold_italic(self):
        """Test bold and italic conversion."""
        from core.html_to_md import html_to_markdown
        html = "<strong>bold</strong> and <em>italic</em>"
        result = html_to_markdown(html)
        self.assertIn("**bold**", result)
        self.assertIn("*italic*", result)
    
    def test_links(self):
        """Test link conversion."""
        from core.html_to_md import html_to_markdown
        html = '<a href="https://example.com">Click here</a>'
        result = html_to_markdown(html)
        self.assertIn("[Click here](https://example.com)", result)
    
    def test_unordered_list(self):
        """Test unordered list conversion."""
        from core.html_to_md import html_to_markdown
        html = "<ul><li>Item 1</li><li>Item 2</li></ul>"
        result = html_to_markdown(html)
        self.assertIn("- Item 1", result)
        self.assertIn("- Item 2", result)
class TestIsSqlContent(unittest.TestCase):
    """Tests for the is_sql_content() function."""
    
    def setUp(self):
        """Import the function for testing."""
        from core.detectors import is_sql_content
        self.is_sql_content = is_sql_content
    
    def test_select_statements(self):
        """Test basic SELECT statement detection."""
        self.assertTrue(self.is_sql_content("SELECT * FROM Users"))
        self.assertTrue(self.is_sql_content("SELECT name, email FROM customers WHERE active = 1"))
        self.assertTrue(self.is_sql_content("select id from orders"))  # lowercase
    
    def test_insert_statements(self):
        """Test INSERT statement detection."""
        self.assertTrue(self.is_sql_content("INSERT INTO Users (name) VALUES ('John')"))
        self.assertTrue(self.is_sql_content("INSERT INTO orders SELECT * FROM temp"))
    
    def test_update_delete_statements(self):
        """Test UPDATE and DELETE detection."""
        self.assertTrue(self.is_sql_content("UPDATE Users SET name = 'Jane' WHERE id = 1"))
        self.assertTrue(self.is_sql_content("DELETE FROM Users WHERE id = 1"))
    
    def test_join_operations(self):
        """Test JOIN detection."""
        self.assertTrue(self.is_sql_content("SELECT * FROM Users u JOIN Orders o ON u.id = o.user_id"))
        self.assertTrue(self.is_sql_content("SELECT * FROM orders LEFT OUTER JOIN products ON orders.product_id = products.id"))
        self.assertTrue(self.is_sql_content("SELECT * FROM products p INNER JOIN categories c ON p.category_id = c.id"))
    
    def test_ddl_statements(self):
        """Test CREATE, ALTER, DROP detection."""
        self.assertTrue(self.is_sql_content("CREATE TABLE Users (id INT PRIMARY KEY)"))
        self.assertTrue(self.is_sql_content("ALTER TABLE Users ADD email VARCHAR(255)"))
        self.assertTrue(self.is_sql_content("DROP TABLE IF EXISTS temp_users"))
    
    def test_not_sql_regular_text(self):
        """Test that regular text is not detected as SQL."""
        self.assertFalse(self.is_sql_content("This is regular text."))
        self.assertFalse(self.is_sql_content("Hello World"))
    
    def test_not_sql_dax_code(self):
        """Test that DAX code is NOT detected as SQL."""
        # DAX with EVALUATE should be excluded
        self.assertFalse(self.is_sql_content("EVALUATE CALCULATETABLE(Sales)"))
        # DAX measure definitions
        self.assertFalse(self.is_sql_content("Revenue := SUM(Sales[Amount])"))
        # DAX Table[Column] notation
        self.assertFalse(self.is_sql_content("SUM(Sales[Amount])"))
        # DEFINE MEASURE pattern
        self.assertFalse(self.is_sql_content("DEFINE MEASURE Sales[Total] = SUM(Sales[Amount])"))


class TestDetectCodeLanguageWithSQL(unittest.TestCase):
    """Tests for SQL detection in detect_code_language()."""
    
    def test_sql_detection(self):
        """Test that SQL code is correctly detected."""
        self.assertEqual(detect_code_language("SELECT * FROM Users WHERE active = 1"), "sql")
        self.assertEqual(detect_code_language("INSERT INTO orders VALUES (1, 'test')"), "sql")
        self.assertEqual(detect_code_language("CREATE TABLE products (id INT)"), "sql")
    
    def test_sql_vs_dax_disambiguation(self):
        """Test that SQL and DAX are correctly distinguished."""
        # DAX should be detected as DAX, not SQL
        self.assertEqual(detect_code_language("EVALUATE CALCULATETABLE(Sales)"), "dax")
        self.assertEqual(detect_code_language("Revenue := SUM(Sales[Amount])"), "dax")
        # SQL should be detected as SQL
        self.assertEqual(detect_code_language("SELECT SUM(amount) FROM sales"), "sql")


class TestMermaidUtilities(unittest.TestCase):
    """Tests for the Mermaid diagram utilities."""
    
    def setUp(self):
        """Import mermaid functions for testing."""
        from core.mermaid import (
            encode_mermaid_for_url,
            generate_mermaid_link,
            add_mermaid_links_to_markdown,
            find_mermaid_blocks
        )
        self.encode_mermaid_for_url = encode_mermaid_for_url
        self.generate_mermaid_link = generate_mermaid_link
        self.add_mermaid_links_to_markdown = add_mermaid_links_to_markdown
        self.find_mermaid_blocks = find_mermaid_blocks
    
    def test_encode_mermaid_for_url(self):
        """Test that encoding produces a valid pako-compatible string."""
        diagram = "graph TD\n    A --> B"
        encoded = self.encode_mermaid_for_url(diagram)
        # Should be a non-empty string with base64-like characters
        self.assertIsInstance(encoded, str)
        self.assertTrue(len(encoded) > 0)
        # Should not contain padding characters
        self.assertNotIn('=', encoded)
    
    def test_generate_mermaid_link(self):
        """Test that link generation produces valid mermaid.live URLs."""
        diagram = "graph TD\n    A --> B"
        link = self.generate_mermaid_link(diagram)
        self.assertTrue(link.startswith("https://mermaid.live/edit#pako:"))
    
    def test_add_mermaid_links_simple(self):
        """Test adding links to a simple markdown with one mermaid block."""
        md = """# Test

```mermaid
graph TD
    A --> B
```

Done."""
        result = self.add_mermaid_links_to_markdown(md)
        # Should contain the original code block
        self.assertIn("```mermaid", result)
        # Should contain the View Diagram link
        self.assertIn("[📊 View Diagram on mermaid.live]", result)
        self.assertIn("https://mermaid.live/edit#pako:", result)
    
    def test_add_mermaid_links_multiple(self):
        """Test adding links to markdown with multiple mermaid blocks."""
        md = """# Doc

```mermaid
graph TD
    A --> B
```

Text.

```mermaid
sequenceDiagram
    Alice->>Bob: Hi
```

End."""
        result = self.add_mermaid_links_to_markdown(md)
        # Should have two links
        self.assertEqual(result.count("[📊 View Diagram on mermaid.live]"), 2)
    
    def test_add_mermaid_links_no_mermaid(self):
        """Test that markdown without mermaid blocks is unchanged."""
        md = """# Regular Doc

Some text.

```python
def foo():
    pass
```
"""
        result = self.add_mermaid_links_to_markdown(md)
        self.assertEqual(result, md)
    
    def test_find_mermaid_blocks(self):
        """Test finding mermaid blocks in markdown."""
        md = """# Test

```mermaid
graph LR
    X --> Y
```
"""
        blocks = self.find_mermaid_blocks(md)
        self.assertEqual(len(blocks), 1)
        self.assertIn("graph LR", blocks[0][0])
        self.assertTrue(blocks[0][1].startswith("https://mermaid.live/"))


if __name__ == '__main__':
    unittest.main()
