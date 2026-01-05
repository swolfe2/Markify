"""
Round-Trip Fidelity Tests for CI/CD

Tests conversion fidelity for:
- Word → Markdown → Word
- Markdown → Word → Markdown

Run with: pytest tests/test_round_trip.py -v
"""
import os
import re
import sys
import tempfile
import zipfile

import pytest

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from core.md_to_docx import create_docx
from markify_core import get_docx_content

# ============================================================================
# Comparison Utilities
# ============================================================================

def extract_document_xml(docx_path: str) -> str:
    """Extract document.xml content from a DOCX file."""
    with zipfile.ZipFile(docx_path, 'r') as zf:
        return zf.read('word/document.xml').decode('utf-8')


def count_xml_elements(xml_content: str) -> dict:
    """Count key XML elements in document.xml."""
    return {
        'paragraphs': xml_content.count('<w:p>') + xml_content.count('<w:p '),
        'text_runs': xml_content.count('<w:t>') + xml_content.count('<w:t '),
        'tables': xml_content.count('<w:tbl>') + xml_content.count('<w:tbl '),
        'table_rows': xml_content.count('<w:tr>') + xml_content.count('<w:tr '),
        'table_cells': xml_content.count('<w:tc>') + xml_content.count('<w:tc '),
    }


def count_md_elements(md_content: str) -> dict:
    """Count key Markdown elements."""
    lines = md_content.split('\n')

    # Count headers
    h1_count = sum(1 for line in lines if line.startswith('# ') and not line.startswith('## '))
    h2_count = sum(1 for line in lines if line.startswith('## ') and not line.startswith('### '))
    h3_count = sum(1 for line in lines if line.startswith('### '))

    # Count table rows (lines with |)
    table_rows = sum(1 for line in lines if '|' in line and not line.strip().startswith('|---'))

    # Count code blocks
    code_blocks = md_content.count('```')

    # Count links
    links = len(re.findall(r'\[.*?\]\(.*?\)', md_content))

    return {
        'h1': h1_count,
        'h2': h2_count,
        'h3': h3_count,
        'table_rows': table_rows,
        'code_blocks': code_blocks // 2,  # Opening and closing
        'links': links,
        'total_lines': len([line for line in lines if line.strip()]),
    }


def normalize_text(text: str) -> str:
    """Normalize text for comparison (remove extra whitespace)."""
    return ' '.join(text.split())


# ============================================================================
# Test Fixtures
# ============================================================================

@pytest.fixture
def sample_docx_path():
    """Path to sample DOCX for testing."""
    return os.path.join(
        os.path.dirname(__file__), '..', 'samples', 'Markify_Demo.docx'
    )


@pytest.fixture
def sample_md_path():
    """Path to sample Markdown for testing."""
    return os.path.join(
        os.path.dirname(__file__), '..', 'samples', 'Markify_Demo.md'
    )


@pytest.fixture
def temp_dir():
    """Create a temporary directory for test outputs."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield tmpdir


# ============================================================================
# Round-Trip Tests
# ============================================================================

class TestDocxToMdToDocx:
    """Test Word → Markdown → Word round-trip."""

    def test_round_trip_preserves_headers(self, sample_docx_path, temp_dir):
        """Headers should be preserved through round-trip."""
        # Step 1: DOCX → MD
        md_lines = get_docx_content(sample_docx_path)
        md_content = '\n\n'.join(md_lines)

        # Count headers in MD
        md_elements = count_md_elements(md_content)

        # Step 2: MD → DOCX
        temp_md = os.path.join(temp_dir, 'step1.md')
        temp_docx = os.path.join(temp_dir, 'step2.docx')

        with open(temp_md, 'w', encoding='utf-8') as f:
            f.write(md_content)

        create_docx(md_content, temp_docx)

        # Step 3: DOCX → MD again
        md_lines2 = get_docx_content(temp_docx)
        md_content2 = '\n\n'.join(md_lines2)
        md_elements2 = count_md_elements(md_content2)

        # Verify headers preserved
        assert md_elements['h1'] == md_elements2['h1'], \
            f"H1 count mismatch: {md_elements['h1']} vs {md_elements2['h1']}"
        assert md_elements['h2'] == md_elements2['h2'], \
            f"H2 count mismatch: {md_elements['h2']} vs {md_elements2['h2']}"

    def test_round_trip_preserves_table_data(self, sample_docx_path, temp_dir):
        """Table content should be preserved (formatting may differ)."""
        # Step 1: DOCX → MD
        md_lines = get_docx_content(sample_docx_path)
        md_content = '\n\n'.join(md_lines)

        # Check for table presence
        assert '|' in md_content, "Source should contain a table"

        # Step 2: MD → DOCX
        temp_docx = os.path.join(temp_dir, 'with_table.docx')
        create_docx(md_content, temp_docx)

        # Step 3: DOCX → MD
        md_lines2 = get_docx_content(temp_docx)
        md_content2 = '\n\n'.join(md_lines2)

        # Verify table data preserved (content, not formatting)
        assert 'Alice' in md_content2, "Table cell 'Alice' should be preserved"
        assert 'Developer' in md_content2, "Table cell 'Developer' should be preserved"

    def test_basic_text_preserved(self, sample_docx_path, temp_dir):
        """Basic paragraph text should be preserved."""
        # Full round-trip
        md_lines = get_docx_content(sample_docx_path)
        md_content = '\n\n'.join(md_lines)

        temp_docx = os.path.join(temp_dir, 'text.docx')
        create_docx(md_content, temp_docx)

        md_lines2 = get_docx_content(temp_docx)
        md_content2 = '\n\n'.join(md_lines2)

        # Key phrases should be preserved
        assert 'Markify' in md_content2
        assert 'conversion' in md_content2.lower()


class TestMdToDocxToMd:
    """Test Markdown → Word → Markdown round-trip."""

    def test_md_round_trip_headers(self, sample_md_path, temp_dir):
        """Headers should be preserved in MD → DOCX → MD."""
        with open(sample_md_path, encoding='utf-8') as f:
            original_md = f.read()

        original_elements = count_md_elements(original_md)

        # Step 1: MD → DOCX
        temp_docx = os.path.join(temp_dir, 'from_md.docx')
        create_docx(original_md, temp_docx)

        # Step 2: DOCX → MD
        md_lines = get_docx_content(temp_docx)
        roundtrip_md = '\n\n'.join(md_lines)
        roundtrip_elements = count_md_elements(roundtrip_md)

        # Verify header counts
        assert original_elements['h1'] == roundtrip_elements['h1'], \
            f"H1: {original_elements['h1']} vs {roundtrip_elements['h1']}"

    def test_md_round_trip_code_content(self, sample_md_path, temp_dir):
        """Code block content should be preserved."""
        with open(sample_md_path, encoding='utf-8') as f:
            original_md = f.read()

        # Step 1: MD → DOCX
        temp_docx = os.path.join(temp_dir, 'code.docx')
        create_docx(original_md, temp_docx)

        # Step 2: DOCX → MD
        md_lines = get_docx_content(temp_docx)
        roundtrip_md = '\n\n'.join(md_lines)

        # Code content should be preserved
        if 'Excel.Workbook' in original_md:
            assert 'Excel.Workbook' in roundtrip_md, "Power Query code should be preserved"

    def test_md_round_trip_links(self, sample_md_path, temp_dir):
        """URLs should be preserved."""
        with open(sample_md_path, encoding='utf-8') as f:
            original_md = f.read()

        # Step 1: MD → DOCX
        temp_docx = os.path.join(temp_dir, 'links.docx')
        create_docx(original_md, temp_docx)

        # Step 2: DOCX → MD
        md_lines = get_docx_content(temp_docx)
        roundtrip_md = '\n\n'.join(md_lines)

        # GitHub URL should be preserved
        if 'github.com' in original_md:
            assert 'github.com' in roundtrip_md, "GitHub URL should be preserved"


class TestXmlElementCounts:
    """Test XML element preservation in DOCX files."""

    def test_paragraph_count_preserved(self, sample_docx_path, temp_dir):
        """Paragraph count should be similar after round-trip."""
        # Get original counts
        original_xml = extract_document_xml(sample_docx_path)
        original_counts = count_xml_elements(original_xml)

        # Round-trip
        md_lines = get_docx_content(sample_docx_path)
        md_content = '\n\n'.join(md_lines)

        temp_docx = os.path.join(temp_dir, 'roundtrip.docx')
        create_docx(md_content, temp_docx)

        roundtrip_xml = extract_document_xml(temp_docx)
        roundtrip_counts = count_xml_elements(roundtrip_xml)

        # Allow some variance in paragraph count (styles may differ)
        # But should be in same order of magnitude
        ratio = roundtrip_counts['paragraphs'] / max(original_counts['paragraphs'], 1)
        assert 0.5 < ratio < 2.0, \
            f"Paragraph count ratio out of range: {ratio}"

    def test_table_structure_detected(self, sample_docx_path, temp_dir):
        """Tables should be converted and detected."""
        original_xml = extract_document_xml(sample_docx_path)
        original_counts = count_xml_elements(original_xml)

        if original_counts['tables'] > 0:
            # Round-trip
            md_lines = get_docx_content(sample_docx_path)
            md_content = '\n\n'.join(md_lines)

            temp_docx = os.path.join(temp_dir, 'table.docx')
            create_docx(md_content, temp_docx)

            roundtrip_xml = extract_document_xml(temp_docx)
            roundtrip_counts = count_xml_elements(roundtrip_xml)

            # Should still have a table
            assert roundtrip_counts['tables'] > 0, "Table should be preserved"


# ============================================================================
# CLI Support
# ============================================================================

if __name__ == '__main__':
    pytest.main([__file__, '-v'])
