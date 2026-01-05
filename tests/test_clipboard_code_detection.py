"""
Tests for Clipboard Mode code block detection.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

# We need to test the _detect_and_wrap_code_blocks method
# Since it's a method of ClipboardModeDialog, we'll extract a standalone version for testing


def clean_code_buffer(buffer):
    """Remove all empty lines from code buffer."""
    return [line for line in buffer if line.strip()]


class TestCleanCodeBuffer:
    """Tests for code buffer cleaning."""

    def test_removes_empty_lines(self):
        """Test that empty lines are removed."""
        buffer = ["let", "", "  Source = 1", "", "in", "", "  Source"]
        result = clean_code_buffer(buffer)
        assert result == ["let", "  Source = 1", "in", "  Source"]

    def test_preserves_indented_lines(self):
        """Test that indented lines are preserved."""
        buffer = ["def foo():", "    return 1"]
        result = clean_code_buffer(buffer)
        assert result == ["def foo():", "    return 1"]

    def test_empty_buffer(self):
        """Test empty buffer handling."""
        result = clean_code_buffer([])
        assert result == []

    def test_all_empty_lines(self):
        """Test buffer with only empty lines."""
        buffer = ["", "   ", "\t", ""]
        result = clean_code_buffer(buffer)
        assert result == []


class TestCodeDetectionIntegration:
    """Integration tests for code detection."""

    def test_detects_powerquery(self):
        """Test Power Query detection."""
        from core.detectors import detect_code_language

        text = "let Source = 1 in Source"
        lang = detect_code_language(text)
        assert lang == 'powerquery'

    def test_detects_dax(self):
        """Test DAX detection."""
        from core.detectors import detect_code_language

        text = "Revenue := SUMX(Sales, Sales[Qty] * Sales[Price])"
        lang = detect_code_language(text)
        assert lang == 'dax'

    def test_detects_python_import(self):
        """Test Python import detection."""
        from core.detectors import detect_code_language

        text = "import pandas as pd"
        lang = detect_code_language(text)
        assert lang == 'python'

    def test_detects_python_def(self):
        """Test Python function detection."""
        from core.detectors import detect_code_language

        text = "def load_data(path):"
        lang = detect_code_language(text)
        assert lang == 'python'

    def test_no_detection_for_plain_text(self):
        """Test that plain text returns None."""
        from core.detectors import detect_code_language

        text = "This is just regular text."
        lang = detect_code_language(text)
        assert lang is None
