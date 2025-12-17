"""
XLSX file parser for Markify.
Parses Excel spreadsheets using only Python standard library.
XLSX files are ZIP archives containing XML files.
"""
from __future__ import annotations

import zipfile
import xml.etree.ElementTree as ET  # nosec B405
import re
from typing import List, Dict, Any, Tuple

from logging_config import get_logger

logger = get_logger("xlsx_parser")


# =============================================================================
# XML Namespaces
# =============================================================================

NS = {
    "main": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}


# =============================================================================
# Cell Reference Parsing
# =============================================================================

def cell_ref_to_indices(ref: str) -> Tuple[int, int]:
    """
    Convert Excel cell reference (e.g., 'A1', 'B2', 'AA10') to (row, col) indices.
    
    Args:
        ref: Cell reference like 'A1', 'B2', 'AA10'
        
    Returns:
        Tuple of (row_index, col_index), both 0-based
    """
    match = re.match(r"([A-Z]+)(\d+)", ref.upper())
    if not match:
        return (0, 0)
    
    col_str, row_str = match.groups()
    
    # Convert column letters to index (A=0, B=1, ..., Z=25, AA=26, etc.)
    col_idx = 0
    for char in col_str:
        col_idx = col_idx * 26 + (ord(char) - ord('A') + 1)
    col_idx -= 1  # Convert to 0-based
    
    row_idx = int(row_str) - 1  # Convert to 0-based
    
    return (row_idx, col_idx)


def get_max_column(cells: List[Tuple[int, int, str]]) -> int:
    """Get the maximum column index from a list of cells."""
    if not cells:
        return 0
    return max(col for _, col, _ in cells) + 1


# =============================================================================
# Shared Strings Parsing
# =============================================================================

def parse_shared_strings(zip_file: zipfile.ZipFile) -> List[str]:
    """
    Parse the shared strings table from an XLSX file.
    
    Excel stores repeated string values in a shared table to save space.
    Cells reference strings by their index in this table.
    
    Args:
        zip_file: Open ZipFile object for the XLSX
        
    Returns:
        List of string values indexed by their position
    """
    try:
        with zip_file.open("xl/sharedStrings.xml") as f:
            tree = ET.parse(f)  # nosec B314
            root = tree.getroot()
    except KeyError:
        # Some XLSX files don't have shared strings (all inline values)
        logger.debug("No sharedStrings.xml found in XLSX")
        return []
    
    strings = []
    # Each <si> element contains one string entry
    for si in root.findall(".//main:si", NS):
        # String can be simple <t> or rich text with multiple <r><t> elements
        text_parts = []
        for t in si.findall(".//main:t", NS):
            if t.text:
                text_parts.append(t.text)
        strings.append("".join(text_parts))
    
    logger.debug(f"Parsed {len(strings)} shared strings")
    return strings


# =============================================================================
# Workbook Metadata
# =============================================================================

def parse_workbook_sheets(zip_file: zipfile.ZipFile) -> List[Dict[str, str]]:
    """
    Parse workbook.xml to get sheet names and relationships.
    
    Args:
        zip_file: Open ZipFile object for the XLSX
        
    Returns:
        List of dicts with 'name' and 'sheetId' for each sheet
    """
    try:
        with zip_file.open("xl/workbook.xml") as f:
            tree = ET.parse(f)  # nosec B314
            root = tree.getroot()
    except KeyError:
        logger.error("No workbook.xml found in XLSX")
        return []
    
    sheets = []
    for sheet in root.findall(".//main:sheet", NS):
        sheets.append({
            "name": sheet.get("name", "Sheet"),
            "sheetId": sheet.get("sheetId", "1"),
            "rId": sheet.get(f"{{{NS['r']}}}id", "")
        })
    
    logger.debug(f"Found {len(sheets)} sheets: {[s['name'] for s in sheets]}")
    return sheets


# =============================================================================
# Worksheet Parsing
# =============================================================================

def parse_worksheet(
    zip_file: zipfile.ZipFile, 
    sheet_path: str, 
    shared_strings: List[str]
) -> List[List[str]]:
    """
    Parse a single worksheet XML file into a 2D list of cell values.
    
    Args:
        zip_file: Open ZipFile object for the XLSX
        sheet_path: Path to worksheet XML (e.g., 'xl/worksheets/sheet1.xml')
        shared_strings: List of shared string values
        
    Returns:
        2D list of cell values (rows x columns)
    """
    try:
        with zip_file.open(sheet_path) as f:
            tree = ET.parse(f)  # nosec B314
            root = tree.getroot()
    except KeyError:
        logger.error(f"Worksheet not found: {sheet_path}")
        return []
    
    # Collect all cells with their positions
    cells: List[Tuple[int, int, str]] = []
    
    for row in root.findall(".//main:row", NS):
        for cell in row.findall("main:c", NS):
            cell_ref = cell.get("r", "")
            if not cell_ref:
                continue
            
            row_idx, col_idx = cell_ref_to_indices(cell_ref)
            
            # Get cell value
            value_elem = cell.find("main:v", NS)
            cell_type = cell.get("t", "")  # s=shared string, n=number, etc.
            
            if value_elem is not None and value_elem.text:
                raw_value = value_elem.text
                
                if cell_type == "s":
                    # Shared string - look up by index
                    try:
                        str_idx = int(raw_value)
                        value = shared_strings[str_idx] if str_idx < len(shared_strings) else ""
                    except (ValueError, IndexError):
                        value = raw_value
                elif cell_type == "b":
                    # Boolean
                    value = "TRUE" if raw_value == "1" else "FALSE"
                else:
                    # Number or inline string
                    value = raw_value
            else:
                # Check for inline string
                is_elem = cell.find("main:is", NS)
                if is_elem is not None:
                    t_elem = is_elem.find("main:t", NS)
                    value = t_elem.text if t_elem is not None and t_elem.text else ""
                else:
                    value = ""
            
            cells.append((row_idx, col_idx, value))
    
    if not cells:
        return []
    
    # Build 2D array from sparse cell data
    max_row = max(row for row, _, _ in cells) + 1
    max_col = get_max_column(cells)
    
    # Initialize with empty strings
    data: List[List[str]] = [["" for _ in range(max_col)] for _ in range(max_row)]
    
    # Fill in cell values
    for row_idx, col_idx, value in cells:
        data[row_idx][col_idx] = value
    
    logger.debug(f"Parsed worksheet: {max_row} rows x {max_col} columns")
    return data


# =============================================================================
# Main Parsing Function
# =============================================================================

def parse_xlsx(filepath: str) -> List[Dict[str, Any]]:
    """
    Parse an XLSX file and return all sheets with their data.
    
    Args:
        filepath: Path to the .xlsx file
        
    Returns:
        List of dicts, each containing:
        - 'name': Sheet name
        - 'data': 2D list of cell values (rows x columns)
    """
    logger.info(f"Parsing XLSX file: {filepath}")
    
    result = []
    
    try:
        with zipfile.ZipFile(filepath, 'r') as zf:
            # Get shared strings first
            shared_strings = parse_shared_strings(zf)
            
            # Get sheet metadata
            sheets = parse_workbook_sheets(zf)
            
            # Parse each worksheet
            for i, sheet_info in enumerate(sheets, start=1):
                sheet_path = f"xl/worksheets/sheet{i}.xml"
                data = parse_worksheet(zf, sheet_path, shared_strings)
                
                result.append({
                    "name": sheet_info["name"],
                    "data": data
                })
                
    except zipfile.BadZipFile:
        logger.error(f"Invalid XLSX file (not a valid ZIP): {filepath}")
        raise ValueError(f"Invalid XLSX file: {filepath}")
    except Exception as e:
        logger.error(f"Error parsing XLSX: {e}")
        raise
    
    logger.info(f"Successfully parsed {len(result)} sheet(s)")
    return result


def parse_xlsx_sheet(filepath: str, sheet_index: int = 0) -> List[List[str]]:
    """
    Parse a single sheet from an XLSX file.
    
    Args:
        filepath: Path to the .xlsx file
        sheet_index: 0-based index of the sheet to parse
        
    Returns:
        2D list of cell values (rows x columns)
    """
    sheets = parse_xlsx(filepath)
    
    if not sheets:
        return []
    
    if sheet_index >= len(sheets):
        logger.warning(f"Sheet index {sheet_index} out of range, using first sheet")
        sheet_index = 0
    
    return sheets[sheet_index]["data"]
