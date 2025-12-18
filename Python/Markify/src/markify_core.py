"""
Core DOCX to Markdown conversion logic.
"""
from __future__ import annotations

import zipfile
import xml.etree.ElementTree as ET  # nosec B405
import os
import re
import argparse
import shutil
import time
from typing import Any, Callable, Dict, List, Optional

from logging_config import get_logger

logger = get_logger("core")

# Import detection utilities from extracted module
from core.detectors import (
    is_code_content,
    is_dax_content,
    is_python_content,
    detect_code_language,
    DAX_KEYWORDS,
    DAX_FUNCTIONS
)

# Import formatters from new location
try:
    from core.formatters.dax import format_dax
except ImportError:
    format_dax = None

try:
    from core.formatters.pq import format_pq
except ImportError:
    format_pq = None

# Import Mermaid utilities for adding visualization links
try:
    from core.mermaid import add_mermaid_links_to_markdown
except ImportError:
    add_mermaid_links_to_markdown = None

# Import DOCX parsing utilities
from core.docx.parser import (
    NS as ns,
    HEADER_EMOJIS,
    get_paragraph_text,
    _extract_run_text,
    is_list_item,
    is_code_style,
    is_blockquote_style_para,
    get_paragraph_style,
    get_list_type,
    get_list_indent_level,
    detect_header_level,
    get_heading_style_level
)



def parse_table(tbl: ET.Element, format_dax_code: bool = False, format_pq_code: bool = False) -> str:
    """Parse a Word table. If it looks like a code block, return fenced code. Else return Markdown table."""
    rows = []
    full_text_lines = []
    
    for tr in tbl.findall('.//w:tr', ns):
        cells = []
        for tc in tr.findall('.//w:tc', ns):
            cell_text_parts = []
            for p in tc.findall('.//w:p', ns):
                p_text = get_paragraph_text(p)
                cell_text_parts.append(p_text)
                full_text_lines.append(p_text) # Keep raw lines for code detection
            
            # For table cell, join with <br> if multiline to keep valid MD table
            cells.append("<br>".join(cell_text_parts).strip())
        rows.append(cells)
    
    if not rows:
        return ""

    # Check if this table is actually a code block container
    # Join all lines to check patterns
    all_text = "\n".join(full_text_lines).strip()
    
    # Check for M/Power Query code signature
    is_code = False
    if re.search(r'^\s*(\d+\s+)?let\b', all_text, re.MULTILINE):
        is_code = True
    elif 'Web.Contents' in all_text and 'Headers' in all_text:
        is_code = True
    
    # Check for DAX patterns
    elif ':=' in all_text:  # DAX measure definition
        is_code = True
    elif any(kw in all_text.upper() for kw in ['SUMX(', 'CALCULATE(', 'EVALUATE', 'FILTER(', 'COUNTROWS(']):
        is_code = True
    
    # Check for Python patterns
    elif 'import ' in all_text or 'def ' in all_text or 'class ' in all_text:
        is_code = True
    elif 'print(' in all_text or 'return ' in all_text:
        is_code = True
    
    # Also check for line-numbered content (e.g., "1  text\n2  text")
    # Only detect as code if lines start with SEQUENTIAL numbers (1, 2, 3...)
    # This avoids matching tables that happen to have numeric IDs like "001"
    lines = [line.strip() for line in full_text_lines if line.strip()]
    if len(lines) >= 3:
        numbered_count = sum(1 for i, line in enumerate(lines) if re.match(rf'^{i+1}\s+', line))
        if numbered_count >= len(lines) * 0.6:  # 60% must be sequential
            is_code = True
    
    if is_code:
        # Detect the code language for syntax highlighting
        lang = ""
        for line in full_text_lines:
            detected = detect_code_language(line)
            if detected:
                lang = detected
                break
        code_content = "\n".join(full_text_lines)
        
        # Apply DAX formatting if requested and valid
        if lang == 'dax' and format_dax_code and format_dax:
             formatted = format_dax(code_content)
             if formatted:
                 code_content = formatted
        
        # Apply Power Query formatting if requested and valid
        if lang == 'powerquery' and format_pq_code and format_pq:
             formatted = format_pq(code_content)
             if formatted:
                 code_content = formatted

        # Return as code block with language tag
        return f"```{lang}\n{code_content}\n```"
    
    # Otherwise, build standard markdown table
    max_cols = max(len(row) for row in rows)
    
    lines = []
    header = rows[0] if rows else []
    while len(header) < max_cols:
        header.append("")
    lines.append("| " + " | ".join(header) + " |")
    lines.append("| " + " | ".join(["---"] * max_cols) + " |")
    for row in rows[1:]:
        while len(row) < max_cols:
            row.append("")
        lines.append("| " + " | ".join(row) + " |")
    
    return "\n".join(lines)






def get_docx_content(
    filename: str,
    format_dax_code: bool = False,
    format_pq_code: bool = False,
    extract_images: bool = False,
    progress_callback: Optional[Callable[[str], None]] = None
) -> List[str]:

    if progress_callback:
        progress_callback("Reading document...")

    if not os.path.exists(filename):
        logger.error(f"File {filename} not found.")
        return []

    import io
    import tempfile
    file_bytes = None
    temp_path = None
    rels_map = {}  # Map rId to Target (hyperlinks and images)

    
    try:
        # Try standard read first
        try:
            with open(filename, 'rb') as f:
                file_bytes = f.read()
        except PermissionError:
            # File is locked - try to copy it using subprocess (works on Windows with locked files)
            import subprocess # nosec B404
            import uuid
            temp_path = os.path.join(tempfile.gettempdir(), f"markify_{uuid.uuid4().hex}.docx")
            
            # Use PowerShell Copy-Item which can sometimes read locked files
            result = subprocess.run(  # nosec B602 B607
                ['powershell', '-Command', f'Copy-Item -Path "{filename}" -Destination "{temp_path}" -Force'],
                capture_output=True, text=True
            )
            
            if result.returncode == 0 and os.path.exists(temp_path):
                with open(temp_path, 'rb') as f:
                    file_bytes = f.read()
            else:
                raise PermissionError(f"Cannot read file (is it open in Word?): {filename}")
        
        if file_bytes is None:
            raise PermissionError(f"Cannot read file: {filename}")
        
        with zipfile.ZipFile(io.BytesIO(file_bytes)) as docx:
            xml_content = docx.read('word/document.xml')
            
            # Parse relationships file for hyperlinks
            try:
                rels_content = docx.read('word/_rels/document.xml.rels')
                rels_tree = ET.fromstring(rels_content)  # nosec B314
                rels_ns = {'r': 'http://schemas.openxmlformats.org/package/2006/relationships'}
                for rel in rels_tree.findall('.//r:Relationship', rels_ns):
                    rel_id = rel.get('Id', '')
                    rel_type = rel.get('Type', '')
                    rel_target = rel.get('Target', '')
                    # Check if this is a hyperlink or image relationship
                    if 'hyperlink' in rel_type.lower() or 'image' in rel_type.lower():
                        rels_map[rel_id] = rel_target
            except (KeyError, ET.ParseError):
                # No rels file or parse error - continue without hyperlinks/images

                pass
            
    except PermissionError:
        logger.error(f"Cannot access file - please close it in Word first: {filename}")
        return []
    except Exception as e:
        logger.error(f"Error reading docx file: {e}")
        return []
    finally:
        # Clean up temp file if created
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception:
                pass  # nosec B110

    tree = ET.fromstring(xml_content) # nosec B314
    body = tree.find('.//w:body', ns)
    if body is None:
        return []
    
    # First pass: collect all paragraphs and tables
    if progress_callback:
        progress_callback("Analyzing document structure...")
        
    # Define image handler
    def image_handler(r_id):
        if not r_id or r_id not in rels_map:
            return None
        
        target = rels_map[r_id]
        
        if extract_images:
            try:
                # Target is usually "media/image1.png" relative to document.xml
                # Full zip path is word/media/image1.png
                
                # Determine output directory
                base_name = os.path.splitext(os.path.basename(filename))[0]
                images_dir_name = f"{base_name}_images"
                images_dir = os.path.join(os.path.dirname(filename), images_dir_name)
                
                # Calculate zip member path
                # Sometimes target starts with /, sometimes relative
                zip_target = target
                if not zip_target.startswith('word/'):
                    if zip_target.startswith('/'):
                        zip_target = zip_target[1:] # Remove leading /
                        if not zip_target.startswith('word/'):
                           zip_target = 'word/' + zip_target
                    else:
                        zip_target = 'word/' + zip_target
                
                # Extract file
                if file_bytes:
                     with zipfile.ZipFile(io.BytesIO(file_bytes)) as z:
                         try:
                             img_data = z.read(zip_target)
                             
                             if not os.path.exists(images_dir):
                                 os.makedirs(images_dir)
                                 
                             img_name = os.path.basename(target)
                             img_path = os.path.join(images_dir, img_name)
                             
                             with open(img_path, 'wb') as img_f:
                                 img_f.write(img_data)
                                 
                             # Return Markdown link
                             # Use relative path suitable for Markdown file in the same directory
                             return f"![Image]({images_dir_name}/{img_name})"
                             
                         except KeyError:
                             # File not found in zip
                             return f"[Missing Image: {target}]"
            except Exception as e:
                logger.warning(f"Image extraction failed: {e}")
                return f"[Image Extraction Failed]"
        
        return f"[Image: {target}]"

    # First pass: collect all paragraphs and tables
    elements = []
    for child in body:
        tag = child.tag.replace('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}', 'w:')
        
        if tag == 'w:p':
            text = get_paragraph_text(child, include_formatting=True, hyperlink_map=rels_map, image_handler=image_handler)
            
            # Extract bookmarks from this paragraph (for anchor targets)
            bookmarks = []
            for bookmark in child.findall('.//w:bookmarkStart', ns):
                bm_name = bookmark.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}name', '')
                # Skip internal Word bookmarks (start with _ like _GoBack)
                if bm_name and not bm_name.startswith('_'):
                    bookmarks.append(bm_name)

            is_list = is_list_item(child)
            is_code_para = is_code_style(child)
            is_blockquote = is_blockquote_style_para(child)
            list_type = get_list_type(child) if is_list else None
            list_indent = get_list_indent_level(child) if is_list else 0
            style_heading_level = get_heading_style_level(child)
            elements.append({'type': 'para', 'text': text, 'is_list': is_list, 'is_code': is_code_para, 'is_blockquote': is_blockquote, 'bookmarks': bookmarks, 'list_type': list_type, 'list_indent': list_indent, 'style_heading_level': style_heading_level})
        elif tag == 'w:tbl':
            elements.append({'type': 'table', 'element': child})
    
    # Second pass: identify code blocks and group them
    if progress_callback:
        progress_callback("Processing content blocks...")
        
    lines = []
    i = 0
    while i < len(elements):
        elem = elements[i]
        
        if elem['type'] == 'table':
            table_md = parse_table(elem['element'], format_dax_code=format_dax_code, format_pq_code=format_pq_code)

            if table_md:
                lines.append(table_md)
            i += 1
            continue
        
        text = elem['text'].strip()
        
        if not text:
            i += 1
            continue
        
        # Check for Code style paragraphs (from MD→DOCX conversion)
        # Group consecutive Code style paragraphs into a fenced code block
        if elem.get('is_code', False):
            code_lines = [elem['text']]  # Preserve original text
            j = i + 1
            while j < len(elements):
                if elements[j]['type'] != 'para':
                    break
                if not elements[j].get('is_code', False):
                    break
                code_lines.append(elements[j]['text'])
                j += 1
            
            # Detect language and emit fenced block
            code_content = '\n'.join(code_lines)
            lang = detect_code_language(code_content) or ''
            lines.append(f"```{lang}\n{code_content}\n```")
            i = j
            continue
        
        # Check if this starts a code block (look for 'let')
        # Matches "let", "1 let", "let "
        is_code_start = False
        if text.strip() == 'let' or text.lstrip().startswith('let'):
             is_code_start = True
        elif re.match(r'^\d+\s*let\b', text.strip()):
             is_code_start = True
             
        if is_code_start:
            code_lines = [elem['text']]  # Use original text with whitespace
            j = i + 1
            in_block = True
            found_in = False
            
            while j < len(elements) and in_block:
                if elements[j]['type'] != 'para':
                    break
                next_text = elements[j]['text'].strip()
                
                if not next_text:
                    j += 1
                    continue
                
                # Check if this looks like code or is part of the block
                if is_code_content(next_text):
                    code_lines.append(elements[j]['text'])  # Use original text with whitespace
                    if next_text == 'in' or next_text.startswith('in'):
                        found_in = True
                    j += 1
                elif found_in and next_text == 'Source':
                    # This is the result expression after 'in'
                    code_lines.append(elements[j]['text'])  # Use original text with whitespace
                    j += 1
                    in_block = False
                else:
                    # End of code block
                    break
            
            # Detect code language for syntax highlighting
            lang = "powerquery"  # Default for M code
            for code_line in code_lines:
                detected = detect_code_language(code_line)
                if detected:
                    lang = detected
                    break
            
            # Output as code block
            # Output as code block
            code_block_content = "\n".join(code_lines)
            
            # Apply formatting if enabled
            if lang == 'dax' and format_dax_code and format_dax:
                 if progress_callback: progress_callback("Formatting DAX code...")
                 formatted = format_dax(code_block_content)
                 if formatted:
                     code_block_content = formatted
            
            if lang == 'powerquery' and format_pq_code and format_pq:
                 if progress_callback: progress_callback("Formatting Power Query code...")
                 formatted = format_pq(code_block_content)
                 if formatted:
                     code_block_content = formatted

            lines.append(f"```{lang}\n{code_block_content}\n```")

            i = j
            continue
        
        # Check for header (style-based first, then text-pattern fallback)
        header_level = elem.get('style_heading_level', 0)
        if header_level == 0:
            header_level = detect_header_level(text)
        if header_level > 0:
            prefix = "#" * header_level + " "
            lines.append(f"{prefix}{text}")
            i += 1
            continue
        
        # Check for list item (but skip labels like "Bulleted List:")
        if elem['is_list'] and not text.endswith(':'):
            indent_level = elem.get('list_indent', 0)
            indent = '  ' * indent_level  # 2 spaces per level
            
            if elem.get('list_type') == 'number':
                # Track numbered list counter (per indent level)
                if not hasattr(get_docx_content, '_num_counters'):
                    get_docx_content._num_counters = {}
                if indent_level not in get_docx_content._num_counters:
                    get_docx_content._num_counters[indent_level] = 0
                get_docx_content._num_counters[indent_level] += 1
                num = get_docx_content._num_counters[indent_level]
                lines.append(f"{indent}{num}. {text}")
            else:
                # Reset numbered counters when switching to bullets
                get_docx_content._num_counters = {}
                lines.append(f"{indent}- {text}")
            i += 1
            continue
        
        # Blockquote styled paragraph
        if elem.get('is_blockquote', False):
            # Prefix each line with >
            quoted_lines = [f"> {line}" for line in text.split('\n')]
            lines.append('\n'.join(quoted_lines))
            i += 1
            continue
        
        # Regular paragraph - add anchor tags for bookmarks first
        bookmarks = elem.get('bookmarks', [])
        anchor_tags = ''.join([f'<a id="{bm}"></a>' for bm in bookmarks])
        if anchor_tags:
            lines.append(anchor_tags + text)
        else:
            lines.append(text)
        i += 1
    
    return lines

def main() -> None:
    parser = argparse.ArgumentParser(description="Convert DOCX to Markdown including code blocks and tables.")
    parser.add_argument("source_file", nargs='?', default="Word Document to Convert to Markdown.docx", 
                        help="Path to the source .docx file")
    
    args = parser.parse_args()
    
    source_path = os.path.abspath(args.source_file)
    if not os.path.exists(source_path):
        logger.error(f"Source file '{source_path}' does not exist.")
        return

    # Create output filename
    base_name = os.path.splitext(source_path)[0]
    output_file = f"{base_name}.md"
    
    logger.info(f"Converting '{source_path}' to '{output_file}'...")

    # Create a temp copy to avoid file lock issues
    temp_file = f"temp_{int(time.time())}.docx"
    try:
        shutil.copy(source_path, temp_file)
        
        markdown_lines = get_docx_content(temp_file)

        if markdown_lines:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write('\n\n'.join(markdown_lines))
            logger.info(f"Conversion successful! Output saved to: {output_file}")
        else:
            logger.warning("No content extracted or error occurred.")
            
    except Exception as e:
        logger.error(f"An error occurred: {e}")
    finally:
        # Cleanup
        if os.path.exists(temp_file):
            try:
                os.remove(temp_file)
            except Exception: # nosec B110
                pass


if __name__ == "__main__":
    main()
