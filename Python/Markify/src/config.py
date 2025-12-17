"""
Configuration management for Markify.
Handles loading and saving user-customizable detection patterns.
"""
from __future__ import annotations

import json
import os
from typing import Dict, List, Any

from logging_config import get_logger

logger = get_logger("config")

# Default patterns - these match current hardcoded values in detectors.py
DEFAULT_PATTERNS: Dict[str, List[str]] = {
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


def get_config_path() -> str:
    """Get the path to the detection patterns config file."""
    appdata = os.environ.get("APPDATA", os.path.expanduser("~"))
    config_dir = os.path.join(appdata, "Markify")
    return os.path.join(config_dir, "detection_patterns.json")


def load_patterns() -> Dict[str, List[str]]:
    """Load detection patterns from config file, or return defaults if not found."""
    config_path = get_config_path()
    
    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                patterns = json.load(f)
                logger.info(f"Loaded patterns from {config_path}")
                # Merge with defaults for any missing keys
                for key in DEFAULT_PATTERNS:
                    if key not in patterns:
                        patterns[key] = DEFAULT_PATTERNS[key]
                return patterns
        except (json.JSONDecodeError, IOError) as e:
            logger.warning(f"Failed to load patterns: {e}, using defaults")
            return DEFAULT_PATTERNS.copy()
    
    return DEFAULT_PATTERNS.copy()


def save_patterns(patterns: Dict[str, List[str]]) -> bool:
    """Save detection patterns to config file."""
    config_path = get_config_path()
    config_dir = os.path.dirname(config_path)
    
    try:
        os.makedirs(config_dir, exist_ok=True)
        with open(config_path, "w", encoding="utf-8") as f:
            json.dump(patterns, f, indent=2)
        logger.info(f"Saved patterns to {config_path}")
        return True
    except IOError as e:
        logger.error(f"Failed to save patterns: {e}")
        return False


def reset_to_defaults() -> Dict[str, List[str]]:
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
_patterns_cache: Dict[str, List[str]] = {}


def get_patterns() -> Dict[str, List[str]]:
    """Get cached patterns, loading from file if needed."""
    global _patterns_cache
    if not _patterns_cache:
        _patterns_cache = load_patterns()
    return _patterns_cache


def reload_patterns() -> Dict[str, List[str]]:
    """Force reload patterns from file."""
    global _patterns_cache
    _patterns_cache = load_patterns()
    return _patterns_cache
