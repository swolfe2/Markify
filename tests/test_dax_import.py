"""
Tests for the DAX Studio query importer (Feature #6).
"""
from __future__ import annotations

import tempfile
import unittest
from unittest.mock import patch

from core.dax_import import convert_dax_file


class TestDaxStudioImporter(unittest.TestCase):
    def test_convert_dax_file_basic(self):
        """Test reading a DAX query and wrapping in code blocks."""
        dax_query = "EVALUATE\nVALUES(Customer[Country])"

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".dax", delete=False, encoding="utf-8") as tmp:
            tmp.write(dax_query)
            tmp_path = tmp.name

        try:
            # Test without formatting
            result = convert_dax_file(tmp_path, format_code=False)
            expected = f"```dax\n{dax_query}\n```"
            self.assertEqual(result, expected)
        finally:
            import os
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    @patch("core.dax_import.format_dax")
    def test_convert_dax_file_formatting(self, mock_format_dax):
        """Test formatting is applied when format_code is True."""
        raw_query = "evaluate values(Customer[Country])"
        formatted_query = "EVALUATE\n  VALUES ( Customer[Country] )"
        mock_format_dax.return_value = formatted_query

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".dax", delete=False, encoding="utf-8") as tmp:
            tmp.write(raw_query)
            tmp_path = tmp.name

        try:
            # Test with formatting enabled
            result = convert_dax_file(tmp_path, format_code=True)
            expected = f"```dax\n{formatted_query}\n```"
            self.assertEqual(result, expected)
            mock_format_dax.assert_called_once_with(raw_query)
        finally:
            import os
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
