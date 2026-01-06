"""
DOCX paragraph and list parsing utilities for Markify.
Handles XML parsing of Word document elements.
"""
from __future__ import annotations

import re
import xml.etree.ElementTree as ET  # nosec B405
from collections.abc import Callable

# XML Namespaces for Word documents
NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
    'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
    'pic': 'http://schemas.openxmlformats.org/drawingml/2006/picture',
    'wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'
}

# Emoji patterns that indicate headers
HEADER_EMOJIS = ['🔐', '✅', '🔄', '🔑', '🧭', '📐', '📚']


# =============================================================================
# Paragraph and Run Text Extraction
# =============================================================================

def get_paragraph_text(
    para: ET.Element,
    include_formatting: bool = False,
    hyperlink_map: dict[str, str] | None = None,
    image_handler: Callable[[str], str | None] | None = None
) -> str:
    """Extract text from a paragraph, optionally with Markdown formatting and hyperlinks."""
    if hyperlink_map is None:
        hyperlink_map = {}

    text = ""

    # Process all direct children of paragraph to handle both runs and hyperlinks
    for child in para:
        tag = child.tag.replace('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}', 'w:')

        if tag == 'w:hyperlink':
            # Check for internal anchor (cross-reference) first
            anchor = child.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}anchor', '')

            # Extract hyperlink URL from r:id attribute (for external links)
            r_id = child.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id', '')
            url = hyperlink_map.get(r_id, '')

            # Get the text inside the hyperlink
            link_text = ""
            for run in child.findall('.//w:r', NS):
                link_text += _extract_run_text(run, image_handler=image_handler)

            # Format as Markdown link
            if link_text.strip():
                # Clean and validate anchor (skip if it's too long or has line breaks, likely garbage metadata)
                is_valid_anchor = anchor and len(anchor) < 100 and '\n' not in anchor and '#(lf)' not in anchor
                
                if url and is_valid_anchor:
                    # External link with anchor: [text](url#anchor)
                    text += f"[{link_text.strip()}]({url}#{anchor})"
                elif url:
                    # Pure external link
                    text += f"[{link_text.strip()}]({url})"
                elif is_valid_anchor:
                    # Pure internal anchor (cross-reference)
                    text += f"[{link_text.strip()}](#{anchor})"
                else:
                    # No valid URL or anchor - just use the text
                    text += link_text.strip()

        elif tag == 'w:r':
            run_text = _extract_run_text(child, include_formatting, image_handler=image_handler)
            text += run_text

    return text


def _extract_run_text(
    run: ET.Element,
    include_formatting: bool = False,
    image_handler: Callable[[str], str | None] | None = None
) -> str:
    """Extract text from a single run element with optional formatting."""
    is_bold = False
    is_italic = False
    rPr = run.find('w:rPr', NS)
    if rPr is not None:
        is_bold = rPr.find('w:b', NS) is not None
        is_italic = rPr.find('w:i', NS) is not None

    run_text = ""
    for child in run:
        tag = child.tag.replace('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}', 'w:')
        if tag == 'w:t':
            if child.text:
                run_text += child.text
        elif tag == 'w:tab':
            run_text += "\t"
        elif tag == 'w:br':
            run_text += "\n"
        elif tag == 'w:cr':
            run_text += "\n"
        elif tag == 'w:drawing' and image_handler:
            # Extract image relationship ID
            for blip in child.findall('.//a:blip', NS):
                embed_id = blip.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed')
                if embed_id:
                    img_md = image_handler(embed_id)
                    if img_md:
                        run_text += f"\n{img_md}\n"

    # Apply formatting if requested and there's text
    if include_formatting and run_text.strip():
        if is_bold:
            run_text = f"**{run_text}**"
        if is_italic:
            run_text = f"*{run_text}*"

    return run_text


# =============================================================================
# Code Style Detection
# =============================================================================

def is_code_style(para: ET.Element) -> bool:
    """Check if paragraph has Code style (used for MD→DOCX code blocks)."""
    pPr = para.find('w:pPr', NS)
    if pPr is not None:
        pStyle = pPr.find('w:pStyle', NS)
        if pStyle is not None:
            style_val = pStyle.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val', '')
            # Check for Code style applied by md_to_docx.py
            if style_val == 'Code':
                return True
    return False


# =============================================================================
# List Detection
# =============================================================================

def is_list_item(para: ET.Element) -> bool:
    """Check if paragraph is a list item (bullet or numbered)."""
    pPr = para.find('w:pPr', NS)
    if pPr is not None:
        # Check for explicit numbering property
        if pPr.find('w:numPr', NS) is not None:
            return True
        # Check for list-style paragraphs (e.g., "ListBullet", "ListNumber")
        pStyle = pPr.find('w:pStyle', NS)
        if pStyle is not None:
            style_val = pStyle.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val', '')
            if 'List' in style_val:
                return True
    return False


def get_list_type(para: ET.Element) -> str | None:
    """Return 'bullet', 'number', or None based on paragraph list style."""
    pPr = para.find('w:pPr', NS)
    if pPr is not None:
        pStyle = pPr.find('w:pStyle', NS)
        if pStyle is not None:
            style_val = pStyle.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val', '')
            if 'ListNumber' in style_val:
                return 'number'
            if 'ListBullet' in style_val or 'List' in style_val:
                return 'bullet'
        # Check numPr for explicit numbering (could be bullet or number based on numId)
        numPr = pPr.find('w:numPr', NS)
        if numPr is not None:
            return 'bullet'  # Default to bullet if unsure
    return None


def get_list_indent_level(para: ET.Element) -> int:
    """Return the indent level (0-based) for a list item, or 0 if not nested."""
    pPr = para.find('w:pPr', NS)
    if pPr is not None:
        # First, check for explicit ilvl in numPr
        numPr = pPr.find('w:numPr', NS)
        if numPr is not None:
            ilvl = numPr.find('w:ilvl', NS)
            if ilvl is not None:
                level = ilvl.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val', '0')
                return int(level)

        # Fallback: check style name for level number (e.g., "List Bullet 2" -> level 1)
        pStyle = pPr.find('w:pStyle', NS)
        if pStyle is not None:
            style_val = pStyle.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val', '')
            # Check for patterns like "ListBullet2", "List Bullet 2", "ListNumber3"
            match = re.search(r'(\d+)$', style_val)
            if match:
                # Convert to 0-based: "List Bullet 2" -> level 1
                return int(match.group(1)) - 1
    return 0


# =============================================================================
# Header Detection
# =============================================================================

def detect_header_level(text: str) -> int:
    """Detect header level based on emoji patterns and content."""
    text_stripped = text.strip()

    # Check for main header emoji patterns
    for emoji in HEADER_EMOJIS:
        if text_stripped.startswith(emoji):
            # Check for sub-numbering like "✅ 1." or "✅ 2."
            rest = text_stripped[len(emoji):].strip()
            if re.match(r'^\d+\.', rest):
                return 2  # Sub-section
            return 1  # Main section

    # Check for numbered headers like "1. Create & Store..."
    if re.match(r'^\d+\.\s+[A-Z]', text_stripped):
        return 3

    return 0  # Not a header


def get_heading_style_level(para: ET.Element) -> int:
    """Detect heading level from Word styles using configurable mappings."""
    # Import here to avoid circular imports
    from config import get_heading_level_for_style

    style_name = get_paragraph_style(para)
    if style_name:
        return get_heading_level_for_style(style_name)
    return 0  # Not a styled heading


def get_paragraph_style(para: ET.Element) -> str:
    """Get the style name of a paragraph, or empty string if none."""
    pPr = para.find('w:pPr', NS)
    if pPr is not None:
        pStyle = pPr.find('w:pStyle', NS)
        if pStyle is not None:
            return pStyle.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val', '')
    return ''


def is_blockquote_style_para(para: ET.Element) -> bool:
    """Check if paragraph has a blockquote style."""
    from config import is_blockquote_style
    style_name = get_paragraph_style(para)
    return is_blockquote_style(style_name) if style_name else False
