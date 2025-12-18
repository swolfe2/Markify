"""
Footnote handling for Word to Markdown conversion.
Parses Word footnotes.xml and converts to Markdown footnote syntax.
"""
from __future__ import annotations

import re
import xml.etree.ElementTree as ET  # nosec B405
from typing import Dict, List, Optional, Tuple


# Word XML namespaces
NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
}


def parse_footnotes_xml(footnotes_content: bytes) -> Dict[int, str]:
    """
    Parse Word footnotes.xml and extract footnote text.
    
    Args:
        footnotes_content: Raw bytes of the footnotes.xml file
        
    Returns:
        Dictionary mapping footnote ID to footnote text
    """
    footnotes = {}
    
    try:
        tree = ET.fromstring(footnotes_content)  # nosec B314
        
        # Find all footnote elements
        for footnote in tree.findall('.//w:footnote', NS):
            fn_id = footnote.get(f'{{{NS["w"]}}}id')
            if fn_id is None:
                continue
            
            # Skip separator and continuation separator (IDs 0 and -1)
            try:
                fn_id_int = int(fn_id)
                if fn_id_int <= 0:
                    continue
            except ValueError:
                continue
            
            # Extract text from all paragraphs in the footnote
            text_parts = []
            for para in footnote.findall('.//w:p', NS):
                para_text = []
                for run in para.findall('.//w:r', NS):
                    for text in run.findall('.//w:t', NS):
                        if text.text:
                            para_text.append(text.text)
                if para_text:
                    text_parts.append(''.join(para_text))
            
            if text_parts:
                footnotes[fn_id_int] = ' '.join(text_parts)
    
    except ET.ParseError:
        pass  # Return empty dict if parsing fails
    
    return footnotes


def convert_footnotes_to_markdown(
    markdown: str,
    footnotes: Dict[int, str]
) -> str:
    """
    Convert inline footnote references and add footnote definitions.
    
    Replaces Word footnote markers with Markdown footnote syntax:
    - Inline: [^1], [^2], etc.
    - Definitions at end: [^1]: Footnote text
    
    Args:
        markdown: The Markdown content with potential footnote markers
        footnotes: Dictionary of footnote IDs to text
        
    Returns:
        Markdown with proper footnote syntax
    """
    if not footnotes:
        return markdown
    
    # Look for footnote reference patterns that might be in the output
    # Word footnotes often appear as superscript numbers
    # We'll look for patterns like [1], (1), or just standalone numbers after text
    
    result = markdown
    used_footnotes = set()
    
    # Pattern 1: [1], [2] style references
    for fn_id in footnotes.keys():
        pattern = f'\\[{fn_id}\\]'
        if re.search(pattern, result):
            result = re.sub(pattern, f'[^{fn_id}]', result)
            used_footnotes.add(fn_id)
    
    # Add footnote definitions at the end
    if used_footnotes or footnotes:
        # Use all footnotes if we couldn't detect which were used
        ids_to_add = used_footnotes if used_footnotes else set(footnotes.keys())
        
        footnote_defs = []
        for fn_id in sorted(ids_to_add):
            if fn_id in footnotes:
                footnote_defs.append(f'[^{fn_id}]: {footnotes[fn_id]}')
        
        if footnote_defs:
            # Add footnotes section
            result = result.rstrip() + '\n\n---\n\n'
            result += '\n'.join(footnote_defs)
    
    return result


def add_footnote_markers_during_parsing(paragraphs: List[str], footnotes: Dict[int, str]) -> Tuple[List[str], Dict[int, str]]:
    """
    Process paragraphs and track footnote references.
    This is called during the DOCX parsing phase.
    
    Returns:
        Tuple of (processed paragraphs, footnotes dict)
    """
    # In most cases, Word includes footnote references inline
    # We just need to make sure we return the footnotes for later processing
    return paragraphs, footnotes
