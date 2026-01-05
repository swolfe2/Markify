"""
Configuration management for Markify.
Handles loading and saving user-customizable detection patterns.
"""
from __future__ import annotations

import json
import os
from typing import Any

from logging_config import get_logger

logger = get_logger("config")

# Default patterns - these match current hardcoded values in detectors.py
DEFAULT_PATTERNS: dict[str, list[str]] = {
    "dax_keywords": [
        "EVALUATE", "DEFINE", "MEASURE", "VAR", "RETURN",
        "CALCULATE", "CALCULATETABLE", "FILTER", "ALL", "ALLEXCEPT",
        "SUMX", "AVERAGEX", "COUNTX", "MINX", "MAXX", "RANKX",
        "COUNTROWS", "DISTINCTCOUNT", "RELATED", "RELATEDTABLE",
        "EARLIER", "EARLIEST", "USERELATIONSHIP", "CROSSFILTER",
        "SELECTEDVALUE", "HASONEVALUE", "ISFILTERED", "ISCROSSFILTERED",
        "FIRSTDATE", "LASTDATE", "DATEADD", "DATESYTD", "DATESMTD",
        "TOTALYTD", "TOTALMTD", "SAMEPERIODLASTYEAR",
        "SWITCH", "IF", "AND", "OR", "NOT", "TRUE", "FALSE", "BLANK",
        "FORMAT", "CONCATENATE", "DIVIDE", "ROUND", "INT", "ABS"
    ],
    "dax_functions": [
        "SUM", "AVERAGE", "COUNT", "COUNTA", "MIN", "MAX",
        "VALUES", "DISTINCT", "TOPN", "GENERATE", "SUMMARIZE",
        "ADDCOLUMNS", "SELECTCOLUMNS", "NATURALLEFTOUTERJOIN",
        "LOOKUPVALUE", "TREATAS", "DATATABLE", "ROW"
    ],
    "python_keywords": [
        "def ", "class ", "import ", "from ", "return ", "yield ", "async ", "await "
    ],
    "python_builtins": [
        "print(", "len(", "range(", "list(", "dict(", "set(", "tuple(", "str(", "int(", "float("
    ],
    "powerquery_exact_matches": [
        "let", "in", "Source", "[", "]", "]),", "))", ")),"
    ],
    "powerquery_functions": [
        "Web.Contents", "Json.Document", "Text.ToBinary"
    ],
    "sql_keywords": [
        "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP",
        "FROM", "WHERE", "JOIN", "INNER JOIN", "LEFT JOIN", "RIGHT JOIN", "OUTER JOIN",
        "ON", "AND", "OR", "IN", "NOT", "NULL", "IS NULL", "IS NOT NULL",
        "GROUP BY", "ORDER BY", "HAVING", "DISTINCT", "AS", "UNION", "UNION ALL",
        "INTO", "VALUES", "SET", "TABLE", "INDEX", "VIEW", "PROCEDURE", "FUNCTION",
        "BEGIN", "END", "IF", "ELSE", "CASE", "WHEN", "THEN", "DECLARE", "EXEC",
        "WITH", "CTE", "TRUNCATE", "MERGE", "EXCEPT", "INTERSECT"
    ],
    "sql_functions": [
        "COUNT(", "SUM(", "AVG(", "MIN(", "MAX(", "COALESCE(", "ISNULL(",
        "CAST(", "CONVERT(", "DATEADD(", "DATEDIFF(", "GETDATE(", "GETUTCDATE(",
        "LEN(", "LEFT(", "RIGHT(", "SUBSTRING(", "CHARINDEX(", "REPLACE(",
        "UPPER(", "LOWER(", "TRIM(", "LTRIM(", "RTRIM(",
        "ROW_NUMBER(", "RANK(", "DENSE_RANK(", "OVER(", "PARTITION BY",
        "STRING_AGG(", "STUFF(", "FORMAT(", "TRY_CAST(", "TRY_CONVERT("
    ]
}

# Default Word style to Markdown element mappings
DEFAULT_STYLE_MAPPINGS: dict[str, Any] = {
    # Map Word heading styles to Markdown heading levels
    "heading_styles": {
        "Title": 1,
        "Heading1": 1,
        "Heading2": 2,
        "Heading3": 3,
        "Heading4": 4,
        "Heading5": 5,
        "Heading6": 6,
    },
    # Word styles that should become blockquotes (> prefix)
    "blockquote_styles": ["Quote", "IntenseQuote", "BlockQuote", "BlockText"],
    # Word styles that should become code blocks
    "code_styles": ["Code", "CodeBlock", "PlainText", "HTMLPreformatted"],
}


def get_config_path() -> str:
    """Get the path to the detection patterns config file."""
    appdata = os.environ.get("APPDATA", os.path.expanduser("~"))
    config_dir = os.path.join(appdata, "Markify")
    return os.path.join(config_dir, "detection_patterns.json")


def load_patterns() -> dict[str, list[str]]:
    """Load detection patterns from config file, or return defaults if not found."""
    config_path = get_config_path()

    if os.path.exists(config_path):
        try:
            with open(config_path, encoding="utf-8") as f:
                patterns = json.load(f)
                logger.info(f"Loaded patterns from {config_path}")
                # Merge with defaults for any missing keys
                for key in DEFAULT_PATTERNS:
                    if key not in patterns:
                        patterns[key] = DEFAULT_PATTERNS[key]
                return patterns
        except (OSError, json.JSONDecodeError) as e:
            logger.warning(f"Failed to load patterns: {e}, using defaults")
            return DEFAULT_PATTERNS.copy()

    return DEFAULT_PATTERNS.copy()


def save_patterns(patterns: dict[str, list[str]]) -> bool:
    """Save detection patterns to config file."""
    config_path = get_config_path()
    config_dir = os.path.dirname(config_path)

    try:
        os.makedirs(config_dir, exist_ok=True)
        with open(config_path, "w", encoding="utf-8") as f:
            json.dump(patterns, f, indent=2)
        logger.info(f"Saved patterns to {config_path}")
        return True
    except OSError as e:
        logger.error(f"Failed to save patterns: {e}")
        return False


def reset_to_defaults() -> dict[str, list[str]]:
    """Reset patterns to defaults and save."""
    patterns = DEFAULT_PATTERNS.copy()
    save_patterns(patterns)
    return patterns


def ensure_config_exists() -> str:
    """Ensure config file exists (create with defaults if not). Returns path."""
    config_path = get_config_path()
    if not os.path.exists(config_path):
        save_patterns(DEFAULT_PATTERNS.copy())
    return config_path


# Global patterns cache
_patterns_cache: dict[str, list[str]] = {}


def get_patterns() -> dict[str, list[str]]:
    """Get cached patterns, loading from file if needed."""
    global _patterns_cache
    if not _patterns_cache:
        _patterns_cache = load_patterns()
    return _patterns_cache


def reload_patterns() -> dict[str, list[str]]:
    """Force reload patterns from file."""
    global _patterns_cache
    _patterns_cache = load_patterns()
    return _patterns_cache


# ============================================================================
# Style Mapping Configuration
# ============================================================================

def get_style_config_path() -> str:
    """Get the path to the style mappings config file."""
    appdata = os.environ.get("APPDATA", os.path.expanduser("~"))
    config_dir = os.path.join(appdata, "Markify")
    return os.path.join(config_dir, "style_mappings.json")


def load_style_mappings() -> dict[str, Any]:
    """Load style mappings from config file, or return defaults."""
    config_path = get_style_config_path()

    if os.path.exists(config_path):
        try:
            with open(config_path, encoding="utf-8") as f:
                mappings = json.load(f)
                logger.info(f"Loaded style mappings from {config_path}")
                # Merge with defaults for any missing keys
                for key in DEFAULT_STYLE_MAPPINGS:
                    if key not in mappings:
                        mappings[key] = DEFAULT_STYLE_MAPPINGS[key]
                return mappings
        except (OSError, json.JSONDecodeError) as e:
            logger.warning(f"Failed to load style mappings: {e}, using defaults")
            return DEFAULT_STYLE_MAPPINGS.copy()

    return DEFAULT_STYLE_MAPPINGS.copy()


def save_style_mappings(mappings: dict[str, Any]) -> bool:
    """Save style mappings to config file."""
    config_path = get_style_config_path()
    config_dir = os.path.dirname(config_path)

    try:
        os.makedirs(config_dir, exist_ok=True)
        with open(config_path, "w", encoding="utf-8") as f:
            json.dump(mappings, f, indent=2)
        logger.info(f"Saved style mappings to {config_path}")
        return True
    except OSError as e:
        logger.error(f"Failed to save style mappings: {e}")
        return False


# Global style mappings cache
_style_mappings_cache: dict[str, Any] = {}


def get_style_mappings() -> dict[str, Any]:
    """Get cached style mappings, loading from file if needed."""
    global _style_mappings_cache
    if not _style_mappings_cache:
        _style_mappings_cache = load_style_mappings()
    return _style_mappings_cache


def get_heading_level_for_style(style_name: str) -> int:
    """Get the Markdown heading level for a Word style name. Returns 0 if not a heading."""
    mappings = get_style_mappings()
    heading_styles = mappings.get("heading_styles", {})
    return heading_styles.get(style_name, 0)


def is_blockquote_style(style_name: str) -> bool:
    """Check if a Word style should be converted to a blockquote."""
    mappings = get_style_mappings()
    blockquote_styles = mappings.get("blockquote_styles", [])
    return style_name in blockquote_styles


def is_code_style(style_name: str) -> bool:
    """Check if a Word style should be converted to a code block."""
    mappings = get_style_mappings()
    code_styles = mappings.get("code_styles", [])
    return style_name in code_styles
