"""
Error handling utilities for Markify.
Provides specific error detection and user-friendly error messages.
"""
import os


def classify_docx_error(exception: Exception, filename: str) -> dict[str, str]:
    """
    Classify a DOCX conversion error and return a user-friendly error dict.

    Args:
        exception: The exception that was raised
        filename: Path to the file being converted

    Returns:
        Dict with keys: title, message, details, hint
    """
    error_str = str(exception).lower()
    basename = os.path.basename(filename)

    # Permission error (file locked)
    if isinstance(exception, PermissionError) or "permission" in error_str:
        return {
            "title": "File Access Error",
            "message": "Cannot access the Word document",
            "details": f"📄 {basename}",
            "hint": "Close the file in Microsoft Word and try again."
        }

    # Corrupted ZIP/DOCX
    if "bad zip" in error_str or "not a zip file" in error_str or "badzip" in error_str:
        return {
            "title": "Corrupted Document",
            "message": "Document appears to be corrupted or invalid",
            "details": f"📄 {basename}\n\nThe file structure is damaged and cannot be read.",
            "hint": "Try opening in Word first to repair, then save as new .docx file."
        }

    # Password protected
    if "password" in error_str or "encrypted" in error_str:
        return {
            "title": "Protected Document",
            "message": "Document is password protected",
            "details": f"📄 {basename}",
            "hint": "Remove password protection in Word before converting."
        }

    # File not found
    if isinstance(exception, FileNotFoundError) or "not found" in error_str:
        return {
            "title": "File Not Found",
            "message": "Cannot find the document",
            "details": f"📄 {filename}",
            "hint": "Verify the file exists and the path is correct."
        }

    # Invalid format (missing document.xml)
    if "document.xml" in error_str or "keyerror" in error_str:
        return {
            "title": "Invalid Document",
            "message": "Not a valid Word document",
            "details": f"📄 {basename}\n\nMissing required document structure.",
            "hint": "Ensure the file is a .docx format (not .doc or other)."
        }

    # XML parsing error
    if "xml" in error_str and ("parse" in error_str or "syntax" in error_str):
        return {
            "title": "Document Parse Error",
            "message": "Cannot parse document content",
            "details": f"📄 {basename}\n\nThe XML structure is malformed.",
            "hint": "Try opening in Word, make a change, and re-save."
        }

    # Generic fallback
    return {
        "title": "Conversion Error",
        "message": "Failed to convert document",
        "details": f"📄 {basename}\n\n{str(exception)}",
        "hint": "Check the file is a valid .docx and not corrupted."
    }


def classify_xlsx_error(exception: Exception, filename: str) -> dict[str, str]:
    """
    Classify an XLSX conversion error and return a user-friendly error dict.

    Args:
        exception: The exception that was raised
        filename: Path to the file being converted

    Returns:
        Dict with keys: title, message, details, hint
    """
    error_str = str(exception).lower()
    basename = os.path.basename(filename)

    # Permission error (file locked)
    if isinstance(exception, PermissionError) or "permission" in error_str:
        return {
            "title": "File Access Error",
            "message": "Cannot access the Excel file",
            "details": f"📊 {basename}",
            "hint": "Close the file in Microsoft Excel and try again."
        }

    # Corrupted ZIP/XLSX
    if "bad zip" in error_str or "not a zip file" in error_str:
        return {
            "title": "Corrupted Spreadsheet",
            "message": "Spreadsheet appears to be corrupted or invalid",
            "details": f"📊 {basename}\n\nThe file structure is damaged.",
            "hint": "Try opening in Excel first to repair, then save as new .xlsx file."
        }

    # Password protected
    if "password" in error_str or "encrypted" in error_str:
        return {
            "title": "Protected Spreadsheet",
            "message": "Spreadsheet is password protected",
            "details": f"📊 {basename}",
            "hint": "Remove password protection in Excel before converting."
        }

    # Empty spreadsheet
    if "empty" in error_str or "no content" in error_str or "no data" in error_str:
        return {
            "title": "Empty Spreadsheet",
            "message": "Spreadsheet contains no data",
            "details": f"📊 {basename}",
            "hint": "Verify the spreadsheet has content in the first sheet."
        }

    # Generic fallback
    return {
        "title": "Excel Conversion Error",
        "message": "Failed to convert spreadsheet",
        "details": f"📊 {basename}\n\n{str(exception)}",
        "hint": "Check the file is a valid .xlsx and not corrupted."
    }


def is_file_locked_error(exception: Exception) -> bool:
    """Check if an exception indicates a file is locked."""
    if isinstance(exception, PermissionError):
        return True
    error_str = str(exception).lower()
    return any(x in error_str for x in ["permission", "locked", "in use", "access denied"])


def is_corrupted_file_error(exception: Exception) -> bool:
    """Check if an exception indicates file corruption."""
    error_str = str(exception).lower()
    return any(x in error_str for x in ["bad zip", "not a zip", "corrupted", "invalid"])
