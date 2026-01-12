import os
import sys
import unittest
import xml.etree.ElementTree as ET

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from unittest.mock import MagicMock, patch

from markify_core import get_docx_content


class TestListReproduction(unittest.TestCase):
    @patch('markify_core.zipfile.ZipFile')
    @patch('markify_core.os.path.exists')
    @patch('builtins.open', create=True)
    def test_mixed_list_counter_reset(self, mock_open, mock_exists, mock_zip_cls):
        """Test that bullets do not reset numbered list counters."""
        mock_exists.return_value = True

        xml_content = (
            b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            b'<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
            b'<w:body>'
            # 1. First
            b'<w:p>'
                b'<w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>'
                b'<w:r><w:t>First</w:t></w:r>'
            b'</w:p>'
            # 2. Second
            b'<w:p>'
                b'<w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>'
                b'<w:r><w:t>Second</w:t></w:r>'
            b'</w:p>'
            # - Bullet (Currently this resets the numbered counter)
            b'<w:p>'
                b'<w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr>'
                b'<w:r><w:t>Bullet</w:t></w:r>'
            b'</w:p>'
            # 3. Third (Should be 3., but currently it's 1.)
            b'<w:p>'
                b'<w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>'
                b'<w:r><w:t>Third</w:t></w:r>'
            b'</w:p>'
            b'</w:body>'
            b'</w:document>'
        )

        # Mock zip/file logic
        mock_file = MagicMock()
        mock_file.read.return_value = b'PK'
        mock_file.__enter__ = lambda s: mock_file
        mock_file.__exit__ = MagicMock(return_value=False)
        mock_open.return_value = mock_file

        mock_zip = mock_zip_cls.return_value
        mock_zip.__enter__.return_value = mock_zip
        mock_zip.read.side_effect = lambda name: xml_content if name == 'word/document.xml' else b''

        # We need to mock get_list_type too because it uses complex logic
        # Actually, let's let it run and see what happens.
        # But we need to make sure get_list_type returns 'number' for id 1 and 'bullet' for id 2.
        # Harder with standard get_list_type. Let's patch it.

        with patch('markify_core.get_list_type') as mock_list_type:
            def side_effect(para):
                text = "".join(t.text for t in para.findall('.//w:t', {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}))
                if 'Bullet' in text:
                    return 'bullet'
                return 'number'
            mock_list_type.side_effect = side_effect

            result = get_docx_content("fake.docx")
            result_text = "\n".join(result)

            print("\nResult of mixed list test:")
            print(result_text)

            self.assertIn("1. First", result_text)
            self.assertIn("2. Second", result_text)
            self.assertIn("- Bullet", result_text)
            # THIS IS THE KEY ASSERTION:
            self.assertIn("3. Third", result_text, "Numbered list should continue after a bullet")

    @patch('core.docx.parser.ET.fromstring')
    def test_list_bullet_style_detection(self, mock_from_string):
        """Test that 'List Bullet' is detected as a bullet, not a number."""
        from core.docx.parser import get_list_type

        # Mock a paragraph with "List Bullet" style
        xml = '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:pPr><w:pStyle w:val="ListBullet"/></w:pPr></w:p>'
        para = ET.fromstring(xml)

        ltype = get_list_type(para)
        self.assertEqual(ltype, 'bullet', "ListBullet style should be detected as bullet, not number")

if __name__ == '__main__':
    unittest.main()
