"""
Unit tests for the Diff View utilities.
"""
import os
import sys
import unittest

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from ui.dialogs.diff_viewer import get_diff_lines, get_unified_diff


class TestGetDiffLines(unittest.TestCase):
    """Tests for get_diff_lines()."""

    def test_identical_texts(self):
        """Test that identical texts show no changes."""
        text = "Line 1\nLine 2\nLine 3"
        result = get_diff_lines(text, text)

        for status, left, right in result:
            self.assertEqual(status, 'same')
            self.assertEqual(left, right)

    def test_addition(self):
        """Test detecting additions."""
        text1 = "Line 1\nLine 2"
        text2 = "Line 1\nLine 2\nLine 3"
        result = get_diff_lines(text1, text2)

        # Should have at least one 'add' entry
        statuses = [r[0] for r in result]
        self.assertIn('add', statuses)

    def test_deletion(self):
        """Test detecting deletions."""
        text1 = "Line 1\nLine 2\nLine 3"
        text2 = "Line 1\nLine 2"
        result = get_diff_lines(text1, text2)

        # Should have at least one 'del' entry
        statuses = [r[0] for r in result]
        self.assertIn('del', statuses)

    def test_empty_texts(self):
        """Test comparing empty texts."""
        result = get_diff_lines("", "")
        self.assertEqual(len(result), 0)

    def test_modification(self):
        """Test detecting modifications."""
        text1 = "Line 1\nLine 2\nLine 3"
        text2 = "Line 1\nModified\nLine 3"
        result = get_diff_lines(text1, text2)

        # Should have changes (del + add for modified line)
        statuses = [r[0] for r in result]
        self.assertTrue(any(s != 'same' for s in statuses))


class TestGetUnifiedDiff(unittest.TestCase):
    """Tests for get_unified_diff()."""

    def test_no_diff_for_identical(self):
        """Test that identical texts produce empty diff."""
        text = "Line 1\nLine 2"
        result = get_unified_diff(text, text)
        # Unified diff should be empty for identical files
        self.assertEqual(result, "")

    def test_shows_additions(self):
        """Test that additions are shown with + prefix."""
        text1 = "Line 1"
        text2 = "Line 1\nLine 2"
        result = get_unified_diff(text1, text2)
        self.assertIn("+", result)

    def test_shows_deletions(self):
        """Test that deletions are shown with - prefix."""
        text1 = "Line 1\nLine 2"
        text2 = "Line 1"
        result = get_unified_diff(text1, text2)
        self.assertIn("-", result)

    def test_includes_file_labels(self):
        """Test that file labels are included."""
        text1 = "Original"
        text2 = "Modified"
        result = get_unified_diff(text1, text2, "before.md", "after.md")
        self.assertIn("before.md", result)
        self.assertIn("after.md", result)


class TestDiffViewerDialog(unittest.TestCase):
    """Tests that would require mocking Tk - just verify imports work."""

    def test_import(self):
        """Test that module imports successfully."""
        from ui.dialogs.diff_viewer import show_diff_viewer
        self.assertTrue(callable(show_diff_viewer))


if __name__ == '__main__':
    unittest.main()
