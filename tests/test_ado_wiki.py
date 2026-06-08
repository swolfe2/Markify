"""
Tests for the Azure DevOps Wiki format converter (Feature #5).
"""
from __future__ import annotations

import unittest

from core.ado_wiki import (
    convert_toc,
    convert_mermaid_blocks,
    convert_attachment_links,
    full_convert,
)


class TestAdoWikiConverter(unittest.TestCase):
    def test_convert_toc(self):
        """Test conversion of Markdown TOC lists to [[_TOC_]]."""
        # Basic TOC block conversion
        md = (
            "# Main Title\n"
            "\n"
            "## Table of Contents\n"
            "- [Introduction](#introduction)\n"
            "- [Installation](#installation)\n"
            "  - [Requirements](#requirements)\n"
            "\n"
            "## Introduction\n"
            "Content here..."
        )
        expected = (
            "# Main Title\n"
            "\n"
            "[[_TOC_]]\n"
            "\n"
            "## Introduction\n"
            "Content here..."
        )
        self.assertEqual(convert_toc(md), expected)

        # Content without TOC should remain untouched
        no_toc = "# Title\nSome content...\n- Item 1\n- Item 2"
        self.assertEqual(convert_toc(no_toc), no_toc)

    def test_convert_mermaid_blocks(self):
        """Test conversion of standard backtick Mermaid blocks to ::: mermaid."""
        md = (
            "Here is a diagram:\n"
            "```mermaid\n"
            "graph TD\n"
            "    A --> B\n"
            "```\n"
            "End of diagram."
        )
        expected = (
            "Here is a diagram:\n"
            "::: mermaid\n"
            "graph TD\n"
            "    A --> B\n"
            ":::\n"
            "End of diagram."
        )
        self.assertEqual(convert_mermaid_blocks(md), expected)

        # Standard non-mermaid code blocks should NOT be converted
        python_code = "```python\nprint('Hello')\n```"
        self.assertEqual(convert_mermaid_blocks(python_code), python_code)

    def test_convert_attachment_links(self):
        """Test conversion of relative paths to /attachments/ schema."""
        # Convert relative image paths
        md_images = "![Local Image](media/photo.png) and ![Another](images/pic.jpg)"
        expected_images = "![Local Image](/attachments/photo.png) and ![Another](/attachments/pic.jpg)"
        self.assertEqual(convert_attachment_links(md_images), expected_images)

        # Convert relative file links
        md_links = "Read the [guide](docs/guide.pdf) or [specification](spec.docx)."
        expected_links = "Read the [guide](/attachments/guide.pdf) or [specification](/attachments/spec.docx)."
        self.assertEqual(convert_attachment_links(md_links), expected_links)

        # Ignore absolute links, mailto links, and internal anchor links
        md_ignored = (
            "Go to [Google](https://google.com) or [contact us](mailto:support@app.com) "
            "or read [intro](#introduction) or view ![Remote Image](http://site.com/logo.png)."
        )
        self.assertEqual(convert_attachment_links(md_ignored), md_ignored)

    def test_full_convert(self):
        """Test the full integrated converter pipeline."""
        md = (
            "# Title\n"
            "\n"
            "## Table of Contents\n"
            "- [Intro](#intro)\n"
            "\n"
            "## Intro\n"
            "![Diagram](media/diag.png)\n"
            "\n"
            "```mermaid\n"
            "A -> B\n"
            "```"
        )
        expected = (
            "# Title\n"
            "\n"
            "[[_TOC_]]\n"
            "\n"
            "## Intro\n"
            "![Diagram](/attachments/diag.png)\n"
            "\n"
            "::: mermaid\n"
            "A -> B\n"
            ":::"
        )
        self.assertEqual(full_convert(md), expected)
