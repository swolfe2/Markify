"""
Mock-based integration tests for docx conversion.
Simulates DOCX structure (XML content) without needing physical files.
"""
import unittest
from unittest.mock import patch
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from markify_core import get_docx_content

class TestDocxConversion(unittest.TestCase):
    
    def setUp(self):
        # Patch os.path.exists to always return True for our fake paths
        self.patcher = patch('markify_core.os.path.exists')
        self.mock_exists = self.patcher.start()
        self.mock_exists.return_value = True
        
    def tearDown(self):
        self.patcher.stop()

    @patch('markify_core.zipfile.ZipFile')
    @patch('builtins.open', create=True)
    def test_simple_paragraph(self, mock_open, mock_zip_cls):
        # Mock the XML content of a simple DOCX
        # A docx is a zip containing word/document.xml
        
        # 1. Define the XML content for a generic "Hello World" paragraph
        xml_content = (
            b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            b'<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
            b'<w:body>'
            b'<w:p><w:r><w:t>Hello World</w:t></w:r></w:p>'
            b'</w:body>'
            b'</w:document>'
        )
        
        # 2. Mock file reading (for the new shared read logic)
        from unittest.mock import MagicMock
        mock_file = MagicMock()
        mock_file.read.return_value = b'PK'  # Minimal zip header for BytesIO
        mock_file.__enter__ = lambda s: mock_file
        mock_file.__exit__ = MagicMock(return_value=False)
        mock_open.return_value = mock_file
        
        # 3. Configure the mock zipfile to return this XML
        mock_zip = mock_zip_cls.return_value
        mock_zip.__enter__.return_value = mock_zip
        # When read('word/document.xml') is called, return our fake XML
        mock_zip.read.side_effect = lambda name: xml_content if name == 'word/document.xml' else b''
        
        # 4. Run the conversion
        result = get_docx_content("fake_path.docx")
        
        # 5. Assertions
        self.assertIn("Hello World", result)
        
    @patch('markify_core.zipfile.ZipFile')
    @patch('builtins.open', create=True)
    def test_header_and_code(self, mock_open, mock_zip_cls):
        # Mock specific content: A header (using emoji detection) and a code block
        
        xml_content = (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
            '<w:body>'
            # Header 1: "✅ My Title" (The tool uses emojis for headers)
            '<w:p><w:r><w:t>✅ My Title</w:t></w:r></w:p>'
            # Code: "let x = 1"
            '<w:p><w:r><w:t>let x = 1</w:t></w:r></w:p>'
            '</w:body>'
            '</w:document>'
        ).encode('utf-8')
        
        # Mock file reading
        from unittest.mock import MagicMock
        mock_file = MagicMock()
        mock_file.read.return_value = b'PK'
        mock_file.__enter__ = lambda s: mock_file
        mock_file.__exit__ = MagicMock(return_value=False)
        mock_open.return_value = mock_file
        
        mock_zip = mock_zip_cls.return_value
        mock_zip.__enter__.return_value = mock_zip
        mock_zip.read.side_effect = lambda name: xml_content if name == 'word/document.xml' else b''
        
        result = get_docx_content("fake_path.docx")
        
        # Should convert "✅ My Title" to "# ✅ My Title" (The tool keeps the emoji)
        self.assertIn("# ✅ My Title", result)
        
        # Should detect "let x = 1" as code block
        # Join result to checking substring across lines
        result_text = "\n".join(result)
        self.assertIn("```powerquery", result_text)
        self.assertIn("let x = 1", result_text)
        self.assertIn("```", result_text)

    @patch('markify_core.zipfile.ZipFile')
    @patch('builtins.open', create=True)
    def test_bold_text_extraction(self, mock_open, mock_zip_cls):
        # Verify bold text extraction with Markdown formatting
        
        xml_content = (
            b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            b'<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
            b'<w:body>'
            b'<w:p>'
            b'<w:r><w:t>This is </w:t></w:r>'
            b'<w:r><w:rPr><w:b/></w:rPr><w:t>important</w:t></w:r>'
            b'</w:p>'
            b'</w:body>'
            b'</w:document>'
        )
        
        # Mock file reading
        from unittest.mock import MagicMock
        mock_file = MagicMock()
        mock_file.read.return_value = b'PK'
        mock_file.__enter__ = lambda s: mock_file
        mock_file.__exit__ = MagicMock(return_value=False)
        mock_open.return_value = mock_file
        
        mock_zip = mock_zip_cls.return_value
        mock_zip.__enter__.return_value = mock_zip
        mock_zip.read.side_effect = lambda name: xml_content if name == 'word/document.xml' else b''
        
        result = get_docx_content("fake_path.docx")
        
        # Bold text should now be wrapped in **...**
        result_text = " ".join(result)
        self.assertIn("**important**", result_text)

if __name__ == '__main__':
    unittest.main()
