"""
Markdown to DOCX conversion utilities for Markify.
Generates valid Word documents from Markdown without external dependencies.
Uses Python's built-in zipfile and xml modules.
"""
from __future__ import annotations

import os
import re
import zipfile
from typing import List, Tuple, Optional
from xml.sax.saxutils import escape as xml_escape


# DOCX is a ZIP archive with specific structure
# We need: [Content_Types].xml, _rels/.rels, word/document.xml, word/_rels/document.xml.rels

# ============================================================================
# XML Templates (minimal valid DOCX structure)
# ============================================================================

CONTENT_TYPES_XML = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
    <Default Extension="xml" ContentType="application/xml"/>
    <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>'''

RELS_XML = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>'''

DOCUMENT_RELS_XML = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>'''

STYLES_XML = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
        <w:name w:val="Normal"/>
        <w:rPr><w:sz w:val="24"/></w:rPr>
    </w:style>
    <w:style w:type="paragraph" w:styleId="Heading1">
        <w:name w:val="heading 1"/>
        <w:basedOn w:val="Normal"/>
        <w:pPr><w:spacing w:before="240" w:after="60"/></w:pPr>
        <w:rPr><w:b/><w:sz w:val="48"/></w:rPr>
    </w:style>
    <w:style w:type="paragraph" w:styleId="Heading2">
        <w:name w:val="heading 2"/>
        <w:basedOn w:val="Normal"/>
        <w:pPr><w:spacing w:before="200" w:after="60"/></w:pPr>
        <w:rPr><w:b/><w:sz w:val="36"/></w:rPr>
    </w:style>
    <w:style w:type="paragraph" w:styleId="Heading3">
        <w:name w:val="heading 3"/>
        <w:basedOn w:val="Normal"/>
        <w:pPr><w:spacing w:before="160" w:after="40"/></w:pPr>
        <w:rPr><w:b/><w:sz w:val="28"/></w:rPr>
    </w:style>
    <w:style w:type="paragraph" w:styleId="Code">
        <w:name w:val="Code"/>
        <w:basedOn w:val="Normal"/>
        <w:pPr><w:shd w:val="clear" w:fill="F5F5F5"/></w:pPr>
        <w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/><w:sz w:val="20"/></w:rPr>
    </w:style>
    <w:style w:type="paragraph" w:styleId="ListBullet">
        <w:name w:val="List Bullet"/>
        <w:basedOn w:val="Normal"/>
        <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
    </w:style>
</w:styles>'''

DOCUMENT_XML_HEADER = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<w:body>
'''

DOCUMENT_XML_FOOTER = '''<w:sectPr>
    <w:pgSz w:w="12240" w:h="15840"/>
    <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
</w:sectPr>
</w:body>
</w:document>'''


# ============================================================================
# Markdown Parser
# ============================================================================

class Block:
    """Base class for parsed markdown blocks."""
    pass


class Heading(Block):
    def __init__(self, level: int, text: str):
        self.level = level
        self.text = text


class Paragraph(Block):
    def __init__(self, text: str):
        self.text = text


class CodeBlock(Block):
    def __init__(self, code: str, language: Optional[str] = None):
        self.code = code
        self.language = language


class ListItem(Block):
    def __init__(self, text: str, indent: int = 0):
        self.text = text
        self.indent = indent


class Table(Block):
    """Markdown table with rows of cells."""
    def __init__(self, rows: List[List[str]]):
        self.rows = rows  # List of rows, each row is list of cell strings


def parse_markdown(content: str) -> List[Block]:
    """
    Parse markdown content into a list of blocks.
    
    Args:
        content: Markdown text
    
    Returns:
        List of Block objects (Heading, Paragraph, CodeBlock, ListItem)
    """
    blocks: List[Block] = []
    lines = content.split('\n')
    i = 0
    
    # Skip front matter if present
    if lines and lines[0].strip() == '---':
        i = 1
        while i < len(lines) and lines[i].strip() != '---':
            i += 1
        i += 1  # Skip closing ---
    
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # Empty line
        if not stripped:
            i += 1
            continue
        
        # Heading
        heading_match = re.match(r'^(#{1,6})\s+(.+)$', stripped)
        if heading_match:
            level = len(heading_match.group(1))
            text = heading_match.group(2).strip()
            blocks.append(Heading(level, text))
            i += 1
            continue
        
        # Code block
        if stripped.startswith('```'):
            language = stripped[3:].strip() or None
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith('```'):
                code_lines.append(lines[i])
                i += 1
            i += 1  # Skip closing ```
            blocks.append(CodeBlock('\n'.join(code_lines), language))
            continue
        
        # List item (bullet)
        list_match = re.match(r'^(\s*)([-*+])\s+(.+)$', line)
        if list_match:
            indent = len(list_match.group(1)) // 2
            text = list_match.group(3).strip()
            blocks.append(ListItem(text, indent))
            i += 1
            continue
        
        # Table (lines with | characters)
        if '|' in stripped and stripped.startswith('|'):
            table_rows = []
            while i < len(lines):
                tline = lines[i].strip()
                if not tline or not '|' in tline:
                    break
                # Skip separator row (|---|---|)
                if re.match(r'^\|[\s\-:|]+\|$', tline):
                    i += 1
                    continue
                # Parse cells
                cells = [c.strip() for c in tline.split('|')]
                # Remove empty first/last from leading/trailing |
                if cells and not cells[0]:
                    cells = cells[1:]
                if cells and not cells[-1]:
                    cells = cells[:-1]
                if cells:
                    table_rows.append(cells)
                i += 1
            if table_rows:
                blocks.append(Table(table_rows))
            continue
        
        # Regular paragraph - collect consecutive lines
        para_lines = [stripped]
        i += 1
        while i < len(lines):
            next_line = lines[i].strip()
            if not next_line:
                break
            if next_line.startswith('#') or next_line.startswith('```'):
                break
            if re.match(r'^[-*+]\s+', next_line):
                break
            para_lines.append(next_line)
            i += 1
        
        # Join paragraph lines, preserving Markdown hard breaks
        # Hard break: trailing double-space or backslash
        processed_lines = []
        for line in para_lines:
            if line.endswith('  '):
                # Trailing double-space = hard break, keep newline
                processed_lines.append(line.rstrip() + '\n')
            elif line.endswith('\\'):
                # Trailing backslash = hard break, keep newline
                processed_lines.append(line[:-1] + '\n')
            else:
                processed_lines.append(line)
        
        # Join with space, but hard breaks already have \n embedded
        final_text = ' '.join(processed_lines)
        blocks.append(Paragraph(final_text))
    
    return blocks


# ============================================================================
# Word XML Generation
# ============================================================================

def _process_inline_formatting(text: str) -> str:
    """
    Convert inline markdown formatting to Word XML runs.
    
    Handles: **bold**, *italic*, `code`, [links](url), line breaks
    """
    result = []
    i = 0
    
    while i < len(text):
        # Line break (Markdown hard break or embedded newline)
        if text[i] == '\n':
            result.append('<w:r><w:br/></w:r>')
            i += 1
            continue
        
        # Handle Markdown hard line break (two trailing spaces before newline)
        # This is already handled above when we see \n, but we need to strip trailing spaces
        if i + 2 < len(text) and text[i:i+2] == '  ' and (i + 2 >= len(text) or text[i+2] == '\n'):
            # Skip the trailing spaces, the \n will be converted to <w:br/>
            i += 2
            continue
            
        # Bold (**text**)
        bold_match = re.match(r'\*\*(.+?)\*\*', text[i:])
        if bold_match:
            content = xml_escape(bold_match.group(1))
            result.append(f'<w:r><w:rPr><w:b/></w:rPr><w:t>{content}</w:t></w:r>')
            i += len(bold_match.group(0))
            continue
        
        # Italic (*text*)
        italic_match = re.match(r'\*(.+?)\*', text[i:])
        if italic_match:
            content = xml_escape(italic_match.group(1))
            result.append(f'<w:r><w:rPr><w:i/></w:rPr><w:t>{content}</w:t></w:r>')
            i += len(italic_match.group(0))
            continue
        
        # Inline code (`code`)
        code_match = re.match(r'`([^`]+)`', text[i:])
        if code_match:
            content = xml_escape(code_match.group(1))
            result.append(f'<w:r><w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/><w:shd w:val="clear" w:fill="F5F5F5"/></w:rPr><w:t>{content}</w:t></w:r>')
            i += len(code_match.group(0))
            continue
        
        # Link [text](url) - just show as underlined text
        link_match = re.match(r'\[([^\]]+)\]\([^)]+\)', text[i:])
        if link_match:
            content = xml_escape(link_match.group(1))
            result.append(f'<w:r><w:rPr><w:u w:val="single"/><w:color w:val="0563C1"/></w:rPr><w:t>{content}</w:t></w:r>')
            i += len(link_match.group(0))
            continue
        
        # Regular text - collect until next special char
        plain_end = i
        while plain_end < len(text):
            if text[plain_end] in '*`[':
                break
            plain_end += 1
        
        if plain_end > i:
            content = xml_escape(text[i:plain_end])
            # Preserve spaces
            result.append(f'<w:r><w:t xml:space="preserve">{content}</w:t></w:r>')
            i = plain_end
        else:
            # Single special char that didn't match a pattern
            content = xml_escape(text[i])
            result.append(f'<w:r><w:t>{content}</w:t></w:r>')
            i += 1
    
    return ''.join(result)


def _heading_to_xml(heading: Heading) -> str:
    """Convert a Heading block to Word XML."""
    style_id = f"Heading{min(heading.level, 3)}"  # Only styles 1-3 defined
    runs = _process_inline_formatting(heading.text)
    return f'<w:p><w:pPr><w:pStyle w:val="{style_id}"/></w:pPr>{runs}</w:p>'


def _paragraph_to_xml(para: Paragraph) -> str:
    """Convert a Paragraph block to Word XML."""
    runs = _process_inline_formatting(para.text)
    return f'<w:p>{runs}</w:p>'


def _code_block_to_xml(code_block: CodeBlock) -> str:
    """Convert a CodeBlock to Word XML (one paragraph per line)."""
    paragraphs = []
    for line in code_block.code.split('\n'):
        escaped = xml_escape(line) if line else ''
        paragraphs.append(
            f'<w:p><w:pPr><w:pStyle w:val="Code"/></w:pPr>'
            f'<w:r><w:t xml:space="preserve">{escaped}</w:t></w:r></w:p>'
        )
    return ''.join(paragraphs)


def _list_item_to_xml(item: ListItem) -> str:
    """Convert a ListItem block to Word XML."""
    runs = _process_inline_formatting(item.text)
    # Add bullet character manually
    bullet = '• '
    indent = item.indent * 360  # Additional indent per level
    return (
        f'<w:p><w:pPr><w:pStyle w:val="ListBullet"/>'
        f'<w:ind w:left="{720 + indent}" w:hanging="360"/></w:pPr>'
        f'<w:r><w:t>{bullet}</w:t></w:r>{runs}</w:p>'
    )


def _table_to_xml(table: Table) -> str:
    """Convert a Table block to Word XML with proper table structure."""
    xml_parts = []
    
    # Table start with borders
    xml_parts.append('<w:tbl>')
    xml_parts.append('<w:tblPr>')
    xml_parts.append('<w:tblW w:w="5000" w:type="pct"/>')
    xml_parts.append('<w:tblBorders>')
    for border in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']:
        xml_parts.append(f'<w:{border} w:val="single" w:sz="4" w:space="0" w:color="auto"/>')
    xml_parts.append('</w:tblBorders>')
    xml_parts.append('</w:tblPr>')
    
    # Table grid
    if table.rows:
        num_cols = len(table.rows[0])
        xml_parts.append('<w:tblGrid>')
        for _ in range(num_cols):
            xml_parts.append('<w:gridCol/>')
        xml_parts.append('</w:tblGrid>')
    
    # Table rows
    for row_idx, row in enumerate(table.rows):
        xml_parts.append('<w:tr>')
        for cell in row:
            xml_parts.append('<w:tc>')
            # Header row gets shading
            if row_idx == 0:
                xml_parts.append('<w:tcPr><w:shd w:val="clear" w:fill="D9E2F3"/></w:tcPr>')
            # Cell paragraph
            escaped = xml_escape(cell)
            if row_idx == 0:
                xml_parts.append(f'<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>{escaped}</w:t></w:r></w:p>')
            else:
                xml_parts.append(f'<w:p><w:r><w:t>{escaped}</w:t></w:r></w:p>')
            xml_parts.append('</w:tc>')
        xml_parts.append('</w:tr>')
    
    xml_parts.append('</w:tbl>')
    return ''.join(xml_parts)


def generate_document_xml(blocks: List[Block]) -> str:
    """
    Generate Word document.xml content from parsed blocks.
    
    Args:
        blocks: List of Block objects from parse_markdown()
    
    Returns:
        Complete document.xml content
    """
    body_parts = []
    
    for block in blocks:
        if isinstance(block, Heading):
            body_parts.append(_heading_to_xml(block))
        elif isinstance(block, Paragraph):
            body_parts.append(_paragraph_to_xml(block))
        elif isinstance(block, CodeBlock):
            body_parts.append(_code_block_to_xml(block))
        elif isinstance(block, ListItem):
            body_parts.append(_list_item_to_xml(block))
        elif isinstance(block, Table):
            body_parts.append(_table_to_xml(block))
    
    return DOCUMENT_XML_HEADER + '\n'.join(body_parts) + DOCUMENT_XML_FOOTER


# ============================================================================
# DOCX File Creation
# ============================================================================

def create_docx(markdown_content: str, output_path: str) -> bool:
    """
    Create a DOCX file from markdown content.
    
    Args:
        markdown_content: The markdown text to convert
        output_path: Path where the DOCX file will be saved
    
    Returns:
        True if successful, False otherwise
    """
    try:
        # Parse markdown
        blocks = parse_markdown(markdown_content)
        
        # Generate document XML
        document_xml = generate_document_xml(blocks)
        
        # Create DOCX (ZIP file)
        with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as docx:
            docx.writestr('[Content_Types].xml', CONTENT_TYPES_XML)
            docx.writestr('_rels/.rels', RELS_XML)
            docx.writestr('word/_rels/document.xml.rels', DOCUMENT_RELS_XML)
            docx.writestr('word/styles.xml', STYLES_XML)
            docx.writestr('word/document.xml', document_xml)
        
        return True
    except Exception:
        return False


def convert_md_file(md_path: str, output_path: Optional[str] = None) -> Tuple[bool, str]:
    """
    Convert a markdown file to DOCX.
    
    Args:
        md_path: Path to the input .md file
        output_path: Optional output path. If not provided, uses same
                    location with .docx extension.
    
    Returns:
        Tuple of (success, output_path or error message)
    """
    if not os.path.exists(md_path):
        return False, f"File not found: {md_path}"
    
    try:
        with open(md_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        return False, f"Error reading file: {e}"
    
    if output_path is None:
        base = os.path.splitext(md_path)[0]
        output_path = f"{base}.docx"
    
    if create_docx(content, output_path):
        return True, output_path
    else:
        return False, "Error creating DOCX file"
