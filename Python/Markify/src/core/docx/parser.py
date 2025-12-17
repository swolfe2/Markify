"""
DOCX paragraph and list parsing utilities for Markify.
Handles XML parsing of Word document elements.
"""
from __future__ import annotations

import re
import xml.etree.ElementTree as ET  # nosec B405
from typing import Callable, Dict, Optional


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
    hyperlink_map: Optional[Dict[str, str]] = None,
    image_handler: Optional[Callable[[str], Optional[str]]] = None
) -> str:
    """Extract text from a paragraph, optionally with Markdown formatting and hyperlinks."""
    if hyperlink_map is None:
        hyperlink_map = {}
    
    text = ""
    
    # Process all direct children of paragraph to handle both runs and hyperlinks
    for child in para:
        tag = child.tag.replace('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}', 'w:')
        
        if tag == 'w:hyperlink':
            # Extract hyperlink URL from r:id attribute
            r_id = child.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id', '')
            url = hyperlink_map.get(r_id, '')
            
            # Get the text inside the hyperlink
            link_text = ""
            for run in child.findall('.//w:r', NS):
                link_text += _extract_run_text(run, image_handler=image_handler)
            
            # Format as Markdown link if we have both text and URL
            if link_text.strip() and url:
                text += f"[{link_text.strip()}]({url})"
            elif link_text.strip():
                text += link_text  # No URL found, just use text
                
        elif tag == 'w:r':
            run_text = _extract_run_text(child, include_formatting, image_handler=image_handler)
            text += run_text
    
    return text


def _extract_run_text(
    run: ET.Element,
    include_formatting: bool = False,
    image_handler: Optional[Callable[[str], Optional[str]]] = None
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


def get_list_type(para: ET.Element) -> Optional[str]:
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
    """Detect heading level from Word's built-in heading styles."""
    pPr = para.find('w:pPr', NS)
    if pPr is not None:
        pStyle = pPr.find('w:pStyle', NS)
        if pStyle is not None:
            style_val = pStyle.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val', '')
            # Map Word styles to Markdown heading levels
            if style_val == 'Title':
                return 1
            elif style_val == 'Heading1':
                return 1
            elif style_val == 'Heading2':
                return 2
            elif style_val == 'Heading3':
                return 3
            elif style_val == 'Heading4':
                return 4
            elif style_val == 'Heading5':
                return 5
            elif style_val == 'Heading6':
                return 6
    return 0  # Not a styled heading
