"""
Tests for the Markdown Linter (Feature #3).
"""
from __future__ import annotations

import os
import tempfile
import unittest

from core.linter import lint_markdown


class TestMarkdownLinter(unittest.TestCase):
    def test_heading_hierarchy_md001(self):
        """Test heading hierarchy skipped levels rule."""
        # Valid heading structure
        valid_md = "# Heading 1\n## Heading 2\n### Heading 3\n# Heading 1 again"
        issues = lint_markdown(valid_md)
        self.assertEqual(len([i for i in issues if i.rule_id == "MD001"]), 0)

        # Invalid: skipped level H1 -> H3
        invalid_md_1 = "# Heading 1\n### Heading 3"
        issues = lint_markdown(invalid_md_1)
        headings_issues = [i for i in issues if i.rule_id == "MD001"]
        self.assertEqual(len(headings_issues), 1)
        self.assertEqual(headings_issues[0].line_number, 2)
        self.assertIn("H1 to H3", headings_issues[0].message)

        # Invalid: skipped level H2 -> H4
        invalid_md_2 = "# Heading 1\n## Heading 2\n#### Heading 4"
        issues = lint_markdown(invalid_md_2)
        headings_issues = [i for i in issues if i.rule_id == "MD001"]
        self.assertEqual(len(headings_issues), 1)
        self.assertEqual(headings_issues[0].line_number, 3)

    def test_image_alt_text_md045(self):
        """Test image alt text rules."""
        # Valid image with alt text
        valid_md = "![Alt text here](images/pic.png)"
        issues = lint_markdown(valid_md)
        alt_issues = [i for i in issues if i.rule_id == "MD045"]
        self.assertEqual(len(alt_issues), 0)

        # Invalid: missing alt text
        invalid_md = "![](images/pic.png)"
        issues = lint_markdown(invalid_md)
        alt_issues = [i for i in issues if i.rule_id == "MD045"]
        self.assertEqual(len(alt_issues), 1)
        self.assertEqual(alt_issues[0].line_number, 1)

        # Invalid: whitespace alt text
        invalid_md_spaces = "![   ](images/pic.png)"
        issues = lint_markdown(invalid_md_spaces)
        alt_issues = [i for i in issues if i.rule_id == "MD045"]
        self.assertEqual(len(alt_issues), 1)

        # Links should not trigger this rule
        link_md = "[](docs/readme.md)"
        issues = lint_markdown(link_md)
        alt_issues = [i for i in issues if i.rule_id == "MD045"]
        self.assertEqual(len(alt_issues), 0)

    def test_broken_relative_links_md051(self):
        """Test broken relative files existence verification."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create a target file to verify path exists
            target_file = os.path.join(tmpdir, "target.md")
            with open(target_file, "w") as f:
                f.write("exists")

            # Valid: File exists
            valid_md = "[link](target.md)"
            issues = lint_markdown(valid_md, base_dir=tmpdir)
            link_issues = [i for i in issues if i.rule_id == "MD051"]
            self.assertEqual(len(link_issues), 0)

            # Invalid: File does not exist
            invalid_md = "[broken link](nonexistent.md)"
            issues = lint_markdown(invalid_md, base_dir=tmpdir)
            link_issues = [i for i in issues if i.rule_id == "MD051"]
            self.assertEqual(len(link_issues), 1)
            self.assertEqual(link_issues[0].line_number, 1)
            self.assertIn("nonexistent.md", link_issues[0].message)

            # Skip remote references
            remote_md = "[remote](https://google.com)"
            issues = lint_markdown(remote_md, base_dir=tmpdir)
            link_issues = [i for i in issues if i.rule_id == "MD051"]
            self.assertEqual(len(link_issues), 0)

            # Skip anchor links
            anchor_md = "[anchor](#introduction)"
            issues = lint_markdown(anchor_md, base_dir=tmpdir)
            link_issues = [i for i in issues if i.rule_id == "MD051"]
            self.assertEqual(len(link_issues), 0)

    def test_malformed_tables_md052(self):
        """Test table columns uniformity checks."""
        # Valid table
        valid_table = (
            "| Col 1 | Col 2 |\n"
            "|---|---|\n"
            "| Val 1 | Val 2 |"
        )
        issues = lint_markdown(valid_table)
        table_issues = [i for i in issues if i.rule_id == "MD052"]
        self.assertEqual(len(table_issues), 0)

        # Invalid: missing a column separator on third line
        invalid_table = (
            "| Col 1 | Col 2 |\n"
            "|---|---|\n"
            "| Val 1 |"
        )
        issues = lint_markdown(invalid_table)
        table_issues = [i for i in issues if i.rule_id == "MD052"]
        self.assertEqual(len(table_issues), 1)
        self.assertEqual(table_issues[0].line_number, 3)

    def test_consecutive_blank_lines_md053(self):
        """Test consecutive blank lines rule."""
        # Valid: 2 blank lines
        valid_md = "Line 1\n\n\nLine 2" # 2 blank lines (lines 2 and 3)
        issues = lint_markdown(valid_md)
        blank_issues = [i for i in issues if i.rule_id == "MD053"]
        self.assertEqual(len(blank_issues), 0)

        # Invalid: 3 blank lines
        invalid_md = "Line 1\n\n\n\nLine 2" # 3 blank lines (lines 2, 3, 4)
        issues = lint_markdown(invalid_md)
        blank_issues = [i for i in issues if i.rule_id == "MD053"]
        self.assertEqual(len(blank_issues), 1)
        self.assertEqual(blank_issues[0].line_number, 4)
