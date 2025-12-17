"""
Excel XLSX to Markdown conversion logic.
Converts Excel spreadsheet tables to Markdown table format.
"""
from __future__ import annotations

import os
import argparse
from typing import List, Optional, Callable

from logging_config import setup_logging, get_logger
from core.xlsx.parser import parse_xlsx

# Initialize logging
setup_logging()
logger = get_logger("xlsx_core")


# =============================================================================
# Markdown Table Generation
# =============================================================================

def table_to_markdown(
    rows: List[List[str]], 
    include_header: bool = True,
    max_col_width: int = 50
) -> str:
    """
    Convert a 2D list of cell values to a Markdown table.
    
    Args:
        rows: 2D list of cell values (rows x columns)
        include_header: If True, treat first row as header
        max_col_width: Maximum column width (truncate longer values)
        
    Returns:
        Markdown table string
    """
    if not rows or not rows[0]:
        return ""
    
    # Calculate column widths
    num_cols = max(len(row) for row in rows)
    col_widths = [0] * num_cols
    
    for row in rows:
        for i, cell in enumerate(row):
            cell_len = min(len(str(cell)), max_col_width)
            col_widths[i] = max(col_widths[i], cell_len, 3)  # Minimum 3 for ---
    
    def format_cell(value: str, width: int) -> str:
        """Format a single cell value, truncating if needed."""
        text = str(value).replace("|", "\\|").replace("\n", " ")
        if len(text) > max_col_width:
            text = text[:max_col_width - 3] + "..."
        return text.ljust(width)
    
    lines = []
    
    for row_idx, row in enumerate(rows):
        # Pad row to full width if needed
        padded_row = list(row) + [""] * (num_cols - len(row))
        
        # Format cells
        formatted = [format_cell(cell, col_widths[i]) for i, cell in enumerate(padded_row)]
        lines.append("| " + " | ".join(formatted) + " |")
        
        # Add header separator after first row
        if row_idx == 0 and include_header:
            separator = ["-" * col_widths[i] for i in range(num_cols)]
            lines.append("| " + " | ".join(separator) + " |")
    
    return "\n".join(lines)


def sheets_to_markdown(
    sheets: List[dict],
    include_headers: bool = True,
    sheet_indices: Optional[List[int]] = None
) -> str:
    """
    Convert multiple sheets to Markdown, each with a heading.
    
    Args:
        sheets: List of sheet dicts from parse_xlsx()
        include_headers: If True, treat first row of each sheet as header
        sheet_indices: Optional list of sheet indices to include (None = all)
        
    Returns:
        Combined Markdown string with sheet headings
    """
    parts = []
    
    for i, sheet in enumerate(sheets):
        if sheet_indices is not None and i not in sheet_indices:
            continue
        
        if not sheet["data"]:
            continue
        
        # Add sheet heading if multiple sheets
        if len(sheets) > 1:
            parts.append(f"## {sheet['name']}\n")
        
        table_md = table_to_markdown(sheet["data"], include_header=include_headers)
        parts.append(table_md)
        parts.append("")  # Blank line between sheets
    
    return "\n".join(parts)


# =============================================================================
# Main Conversion Functions
# =============================================================================

def get_xlsx_content(
    filename: str,
    sheet_index: Optional[int] = None,
    include_header: bool = True,
    progress_callback: Optional[Callable[[str], None]] = None
) -> str:
    """
    Convert an Excel file to Markdown table format.
    
    Args:
        filename: Path to the .xlsx file
        sheet_index: Specific sheet to convert (None = all sheets)
        include_header: If True, treat first row as table header
        progress_callback: Optional callback for progress updates
        
    Returns:
        Markdown string with table(s)
    """
    if progress_callback:
        progress_callback("Reading Excel file...")
    
    logger.info(f"Converting XLSX to Markdown: {filename}")
    
    try:
        sheets = parse_xlsx(filename)
    except Exception as e:
        logger.error(f"Failed to parse XLSX: {e}")
        raise
    
    if not sheets:
        return "*(Empty Excel file)*"
    
    if progress_callback:
        progress_callback(f"Found {len(sheets)} sheet(s), converting...")
    
    # Convert to Markdown
    if sheet_index is not None:
        # Single sheet
        if sheet_index >= len(sheets):
            sheet_index = 0
        
        sheet = sheets[sheet_index]
        if not sheet["data"]:
            return f"*(Sheet '{sheet['name']}' is empty)*"
        
        result = table_to_markdown(sheet["data"], include_header=include_header)
    else:
        # All sheets
        result = sheets_to_markdown(sheets, include_headers=include_header)
    
    if progress_callback:
        progress_callback("Conversion complete")
    
    logger.info(f"Successfully converted XLSX ({len(result)} characters)")
    return result


def convert_xlsx_to_md(
    input_path: str,
    output_path: Optional[str] = None,
    sheet_index: Optional[int] = None,
    include_header: bool = True
) -> str:
    """
    Convert an Excel file to Markdown and optionally save to file.
    
    Args:
        input_path: Path to the .xlsx file
        output_path: Where to save .md file (None = same location as input)
        sheet_index: Specific sheet to convert (None = all sheets)
        include_header: If True, treat first row as table header
        
    Returns:
        Path to the output .md file
    """
    # Determine output path
    if output_path is None:
        base, _ = os.path.splitext(input_path)
        output_path = base + ".md"
    
    # Convert
    markdown = get_xlsx_content(
        input_path, 
        sheet_index=sheet_index, 
        include_header=include_header
    )
    
    # Write output
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(markdown)
    
    logger.info(f"Saved Markdown to: {output_path}")
    return output_path


def get_xlsx_sheet_names(filename: str) -> List[str]:
    """
    Get list of sheet names from an Excel file.
    
    Args:
        filename: Path to the .xlsx file
        
    Returns:
        List of sheet names
    """
    sheets = parse_xlsx(filename)
    return [sheet["name"] for sheet in sheets]


# =============================================================================
# CLI Entry Point
# =============================================================================

def main() -> None:
    """Command-line interface for XLSX to Markdown conversion."""
    parser = argparse.ArgumentParser(
        description="Convert Excel (.xlsx) files to Markdown tables."
    )
    parser.add_argument(
        "input_file",
        help="Path to the .xlsx file to convert"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output .md file path (default: same as input with .md extension)"
    )
    parser.add_argument(
        "-s", "--sheet",
        type=int,
        help="Sheet index to convert (0-based, default: all sheets)"
    )
    parser.add_argument(
        "--no-header",
        action="store_true",
        help="Don't treat first row as header"
    )
    parser.add_argument(
        "--list-sheets",
        action="store_true",
        help="List sheet names and exit"
    )
    
    args = parser.parse_args()
    
    # Validate input file
    if not os.path.isfile(args.input_file):
        print(f"Error: File not found: {args.input_file}")
        return
    
    if not args.input_file.lower().endswith(".xlsx"):
        print("Warning: File does not have .xlsx extension")
    
    # List sheets mode
    if args.list_sheets:
        sheets = get_xlsx_sheet_names(args.input_file)
        print(f"Sheets in '{args.input_file}':")
        for i, name in enumerate(sheets):
            print(f"  [{i}] {name}")
        return
    
    # Convert
    try:
        output_path = convert_xlsx_to_md(
            args.input_file,
            output_path=args.output,
            sheet_index=args.sheet,
            include_header=not args.no_header
        )
        print(f"Successfully converted to: {output_path}")
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    main()
