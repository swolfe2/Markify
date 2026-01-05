"""
Tests for the Quick Wins features:
- TOC Generator
- Obsidian Export
- Footnotes
"""
import os
import sys

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from core.footnotes import convert_footnotes_to_markdown, parse_footnotes_xml
from core.obsidian_export import (
    add_obsidian_properties,
    convert_blockquotes_to_callouts,
    convert_links_to_wikilinks,
)
from core.toc_generator import _create_anchor, extract_headers, generate_toc, insert_toc


class TestTOCGenerator:
    """Tests for Table of Contents generation."""

    def test_extract_headers_basic(self):
        """Test header extraction from Markdown."""
        md = """# Title

## Section 1

### Subsection 1.1

## Section 2
"""
        headers = extract_headers(md)
        assert len(headers) == 4
        assert headers[0] == (1, "Title", "title")
        assert headers[1] == (2, "Section 1", "section-1")
        assert headers[2] == (3, "Subsection 1.1", "subsection-11")
        assert headers[3] == (2, "Section 2", "section-2")

    def test_extract_headers_ignores_code_blocks(self):
        """Headers inside code blocks should be ignored."""
        md = """# Real Header

```python
# This is a comment not a header
def foo():
    pass
```

## Another Header
"""
        headers = extract_headers(md)
        assert len(headers) == 2
        assert headers[0][1] == "Real Header"
        assert headers[1][1] == "Another Header"

    def test_create_anchor(self):
        """Test anchor generation."""
        assert _create_anchor("Hello World") == "hello-world"
        assert _create_anchor("Section 1.2") == "section-12"
        assert _create_anchor("What's New?") == "whats-new"
        assert _create_anchor("  Spaces  ") == "spaces"

    def test_generate_toc(self):
        """Test full TOC generation."""
        md = """# My Document

## Introduction

## Main Content

### Details

## Conclusion
"""
        toc = generate_toc(md)
        assert "## Table of Contents" in toc
        assert "- [My Document](#my-document)" in toc
        assert "- [Introduction](#introduction)" in toc
        assert "  - [Details](#details)" in toc

    def test_generate_toc_max_depth(self):
        """Test max_depth parameter."""
        md = """# Title
## Section
### Subsection
#### Deep
"""
        toc = generate_toc(md, max_depth=2)
        assert "Title" in toc
        assert "Section" in toc
        assert "Subsection" not in toc

    def test_insert_toc_top(self):
        """Test inserting TOC at top."""
        md = "# Title\n\nContent here"
        result = insert_toc(md, position="top")
        assert result.startswith("## Table of Contents")

    def test_insert_toc_after_title(self):
        """Test inserting TOC after first H1."""
        md = "# My Title\n\n## Section 1\n\n## Section 2"
        result = insert_toc(md, position="after_title")
        lines = result.split('\n')
        # Title should come first
        assert lines[0] == "# My Title"
        # TOC should follow
        assert "## Table of Contents" in result


class TestObsidianExport:
    """Tests for Obsidian export functionality."""

    def test_convert_links_to_wikilinks_internal(self):
        """Test internal link conversion."""
        md = "See [my note](my-note.md) for details."
        result = convert_links_to_wikilinks(md)
        assert "[[my-note|my note]]" in result

    def test_convert_links_preserves_external(self):
        """External links should be preserved."""
        md = "Visit [Google](https://google.com) for search."
        result = convert_links_to_wikilinks(md, internal_only=True)
        assert "[Google](https://google.com)" in result

    def test_convert_links_same_name(self):
        """Links where text matches page use simple wikilink."""
        md = "See [notes](notes.md) for more."
        result = convert_links_to_wikilinks(md)
        assert "[[notes]]" in result

    def test_convert_blockquotes_to_callouts(self):
        """Test callout conversion."""
        md = "> Note: This is important information."
        result = convert_blockquotes_to_callouts(md)
        assert "> [!note]" in result
        assert "This is important information" in result

    def test_convert_blockquotes_warning(self):
        """Test warning callout."""
        md = "> Warning: Be careful here."
        result = convert_blockquotes_to_callouts(md)
        assert "> [!warning]" in result

    def test_convert_blockquotes_preserves_regular(self):
        """Regular blockquotes should be preserved."""
        md = "> This is just a quote."
        result = convert_blockquotes_to_callouts(md)
        assert result == md

    def test_add_obsidian_properties_new(self):
        """Test adding properties to content without front matter."""
        md = "# Title\n\nContent"
        result = add_obsidian_properties(md, tags=["tag1", "tag2"])
        assert result.startswith("---\n")
        assert "tags: [tag1, tag2]" in result

    def test_add_obsidian_properties_existing(self):
        """Test adding to existing front matter."""
        md = "---\ntitle: My Doc\n---\n\nContent"
        result = add_obsidian_properties(md, tags=["new"])
        assert "title: My Doc" in result
        assert "tags: [new]" in result


class TestFootnotes:
    """Tests for footnote conversion."""

    def test_parse_footnotes_xml(self):
        """Test parsing footnotes XML."""
        # Minimal footnotes.xml structure
        xml = b'''<?xml version="1.0" encoding="UTF-8"?>
<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    <w:footnote w:id="0"/>
    <w:footnote w:id="1">
        <w:p><w:r><w:t>First footnote text</w:t></w:r></w:p>
    </w:footnote>
    <w:footnote w:id="2">
        <w:p><w:r><w:t>Second footnote</w:t></w:r></w:p>
    </w:footnote>
</w:footnotes>'''
        footnotes = parse_footnotes_xml(xml)
        assert len(footnotes) == 2
        assert footnotes[1] == "First footnote text"
        assert footnotes[2] == "Second footnote"

    def test_convert_footnotes_to_markdown(self):
        """Test footnote conversion to Markdown syntax."""
        md = "This is text[1] with a footnote."
        footnotes = {1: "The footnote explanation."}
        result = convert_footnotes_to_markdown(md, footnotes)
        assert "[^1]" in result
        assert "[^1]: The footnote explanation." in result

    def test_convert_footnotes_empty(self):
        """Empty footnotes should return unchanged content."""
        md = "No footnotes here."
        result = convert_footnotes_to_markdown(md, {})
        assert result == md
