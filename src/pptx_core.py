"""
PowerPoint to Markdown Converter for Markify.
Extracts slide content, tables, and speaker notes from .pptx files.
Zero dependencies - uses only Python built-ins.
"""
from __future__ import annotations

import os
import re
import xml.etree.ElementTree as ET  # nosec B405
import zipfile

from logging_config import get_logger

logger = get_logger("pptx_core")

NAMESPACES = {
    "p": "http://schemas.openxmlformats.org/presentationml/2006/main",
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
}


def get_element_text(elem: ET.Element, include_formatting: bool = True) -> str:
    """Extract and format text from an element containing paragraphs and runs."""
    paragraphs = []

    # Find all paragraph elements <a:p>
    for p in elem.findall(".//a:p", NAMESPACES):
        p_text_parts = []

        # Get list indent level (0-based)
        lvl = 0
        pPr = p.find("a:pPr", NAMESPACES)
        if pPr is not None and "lvl" in pPr.attrib:
            try:
                lvl = int(pPr.attrib["lvl"])
            except ValueError:
                pass

        # Find runs <a:r> or line breaks <a:br>
        for child in p:
            if child.tag.endswith("}r"):
                # Run properties (bold, italic)
                rPr = child.find("a:rPr", NAMESPACES)
                is_bold = rPr is not None and rPr.attrib.get("b") == "1"
                is_italic = rPr is not None and rPr.attrib.get("i") == "1"

                t_elem = child.find("a:t", NAMESPACES)
                if t_elem is not None and t_elem.text:
                    text_val = t_elem.text
                    if include_formatting:
                        if is_bold and is_italic:
                            text_val = f"***{text_val}***"
                        elif is_bold:
                            text_val = f"**{text_val}**"
                        elif is_italic:
                            text_val = f"*{text_val}*"
                    p_text_parts.append(text_val)

            elif child.tag.endswith("}br"):
                p_text_parts.append("\n")

        p_text = "".join(p_text_parts).strip()
        if p_text:
            if lvl > 0 or pPr is not None and (pPr.find("a:buNone", NAMESPACES) is None):
                # Format as a list item if it has level or standard bullet
                indent = "  " * lvl
                paragraphs.append(f"{indent}- {p_text}")
            else:
                paragraphs.append(p_text)

    return "\n".join(paragraphs).strip()


def parse_pptx_table(graphic_frame: ET.Element) -> str:
    """Parse a PowerPoint table graphicFrame into a Markdown table."""
    tbl = graphic_frame.find(".//a:tbl", NAMESPACES)
    if tbl is None:
        return ""

    rows = []
    for tr in tbl.findall("a:tr", NAMESPACES):
        cells = []
        for tc in tr.findall("a:tc", NAMESPACES):
            cell_text = get_element_text(tc, include_formatting=True)
            # Replace inner newlines to prevent broken markdown tables
            cell_text = cell_text.replace("\n", " ").replace("\r", " ").strip()
            cells.append(cell_text)
        rows.append(cells)

    if not rows:
        return ""

    # Generate Markdown Table
    md_table = []

    # Header
    headers = rows[0]
    md_table.append("| " + " | ".join(headers) + " |")

    # Separator
    separators = ["---"] * len(headers)
    md_table.append("| " + " | ".join(separators) + " |")

    # Data Rows
    for row in rows[1:]:
        # Pad row if missing cells
        if len(row) < len(headers):
            row.extend([""] * (len(headers) - len(row)))
        md_table.append("| " + " | ".join(row[:len(headers)]) + " |")

    return "\n".join(md_table) + "\n"


def parse_slide_xml(slide_xml_bytes: bytes) -> tuple[str, list[str]]:
    """Parse slide XML content and return the slide title and body elements."""
    root = ET.fromstring(slide_xml_bytes)  # nosec B314

    title = ""
    body_elements = []

    # 1. Identify title shape if specified by placeholder
    title_shapes = []
    body_shapes = []

    # Traverse shapes in document order
    for sp in root.findall(".//p:sp", NAMESPACES):
        # Check placeholder type
        ph = sp.find(".//p:ph", NAMESPACES)
        if ph is not None:
            ph_type = ph.attrib.get("type", "")
            if ph_type in ("title", "ctrTitle", "subTitle"):
                title_shapes.append(sp)
                continue
        body_shapes.append(sp)

    # 2. Extract title
    if title_shapes:
        title_texts = []
        for t_sp in title_shapes:
            txBody = t_sp.find("p:txBody", NAMESPACES)
            if txBody is not None:
                txt = get_element_text(txBody, include_formatting=False)
                if txt:
                    title_texts.append(txt)
        title = " / ".join(title_texts).strip()

    # 3. Extract body text elements
    for sp in body_shapes:
        txBody = sp.find("p:txBody", NAMESPACES)
        if txBody is not None:
            txt = get_element_text(txBody, include_formatting=True)
            if txt:
                # If we don't have a title yet, treat first non-empty text as title
                if not title:
                    title = txt.split("\n")[0]
                    # If it has more lines, add the rest to body elements
                    rest = "\n".join(txt.split("\n")[1:]).strip()
                    if rest:
                        body_elements.append(rest)
                else:
                    body_elements.append(txt)

    # 4. Parse Tables
    for gf in root.findall(".//p:graphicFrame", NAMESPACES):
        table_md = parse_pptx_table(gf)
        if table_md:
            body_elements.append(table_md)

    return title, body_elements


def parse_notes_xml(notes_xml_bytes: bytes) -> str:
    """Parse speaker notes XML content and return plain text notes."""
    root = ET.fromstring(notes_xml_bytes)  # nosec B314
    notes_parts = []

    # Find shapes with placeholder type body or generic notes shapes
    for sp in root.findall(".//p:sp", NAMESPACES):
        txBody = sp.find("p:txBody", NAMESPACES)
        if txBody is not None:
            txt = get_element_text(txBody, include_formatting=True)
            if txt:
                # Avoid appending slide number placeholders
                ph = sp.find(".//p:ph", NAMESPACES)
                if ph is not None and ph.attrib.get("type") == "sldNum":
                    continue
                notes_parts.append(txt)

    return "\n".join(notes_parts).strip()


def convert_pptx_to_markdown(filepath: str) -> str:
    """Convert a PowerPoint (.pptx) file to Markdown with speaker notes and slide separators."""
    if not zipfile.is_zipfile(filepath):
        raise ValueError(f"File {filepath} is not a valid PPTX zip file.")

    slides_data = []

    with zipfile.ZipFile(filepath, "r") as z:
        # Resolve slide order using presentation.xml relationships
        slide_list = []
        try:
            pres_xml = z.read("ppt/presentation.xml")
            pres_root = ET.fromstring(pres_xml)  # nosec B314

            # Find slides under sldIdLst
            sldIdLst = pres_root.find("p:sldIdLst", NAMESPACES)
            if sldIdLst is not None:
                # Resolve slide filenames
                # E.g. relation maps r:id to slide file
                # Standard PPTX maps are in ppt/_rels/presentation.xml.rels
                rels_content = z.read("ppt/_rels/presentation.xml.rels")
                rels_root = ET.fromstring(rels_content)  # nosec B314

                rel_map = {}
                for rel in rels_root.findall("Relationship"):
                    r_id = rel.attrib.get("Id")
                    target = rel.attrib.get("Target")
                    if r_id and target:
                        # Convert target path to direct filename inside ZIP
                        if not target.startswith("ppt/"):
                            target = f"ppt/{target}"
                        rel_map[r_id] = target

                for sldId in sldIdLst.findall("p:sldId", NAMESPACES):
                    r_id = sldId.attrib.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
                    if r_id in rel_map:
                        slide_list.append(rel_map[r_id])
        except Exception as e:
            logger.warning(f"Failed to parse slide order from presentation.xml: {e}. Falling back to name sorting.")

        # Fallback to sequential scanning if relationship parsing failed
        if not slide_list:
            slide_list = sorted([name for name in z.namelist() if re.match(r"^ppt/slides/slide\d+\.xml$", name)])

        # Process each slide
        for idx, slide_path in enumerate(slide_list, 1):
            try:
                slide_xml = z.read(slide_path)
                title, body_elems = parse_slide_xml(slide_xml)

                # Retrieve speaker notes for this slide
                notes = ""
                # Check for relations file of this slide to locate notes slide
                slide_dir = os.path.dirname(slide_path)
                slide_base = os.path.basename(slide_path)
                rels_path = f"{slide_dir}/_rels/{slide_base}.rels"

                notes_slide_path = None
                if rels_path in z.namelist():
                    try:
                        rels_content = z.read(rels_path)
                        rels_root = ET.fromstring(rels_content)  # nosec B314
                        for rel in rels_root.findall("Relationship"):
                            rel_type = rel.attrib.get("Type", "")
                            if "notesSlide" in rel_type:
                                target = rel.attrib.get("Target", "")
                                # Target is relative to ppt/slides/, e.g., "../notesSlides/notesSlide1.xml"
                                notes_slide_path = os.path.normpath(os.path.join(slide_dir, target)).replace("\\", "/")
                                break
                    except Exception as e:
                        logger.warning(f"Failed to read relationships for {slide_base}: {e}")

                # Fallback to sequential notes matching
                if not notes_slide_path:
                    notes_slide_name = f"ppt/notesSlides/notesSlide{idx}.xml"
                    if notes_slide_name in z.namelist():
                        notes_slide_path = notes_slide_name

                if notes_slide_path and notes_slide_path in z.namelist():
                    try:
                        notes_xml = z.read(notes_slide_path)
                        notes = parse_notes_xml(notes_xml)
                    except Exception as e:
                        logger.error(f"Failed to parse notes slide {notes_slide_path}: {e}")

                slides_data.append({
                    "number": idx,
                    "title": title or f"Slide {idx}",
                    "body": body_elems,
                    "notes": notes
                })
            except Exception as e:
                logger.error(f"Failed to parse slide {slide_path}: {e}")

    # Build Markdown Output
    filename = os.path.basename(filepath)
    md_lines = [f"# Presentation: {filename}\n"]

    for slide in slides_data:
        # Slide Header
        md_lines.append(f"## {slide['title']}\n")

        # Slide Body Elements
        for elem in slide["body"]:
            md_lines.append(elem)
            md_lines.append("")

        # Speaker Notes
        if slide["notes"]:
            md_lines.append("> **Speaker Notes:**")
            for line in slide["notes"].split("\n"):
                md_lines.append(f"> {line}")
            md_lines.append("")

        # Divider between slides (except last)
        if slide["number"] < len(slides_data):
            md_lines.append("---\n")

    return "\n".join(md_lines).strip() + "\n"
