"""
Code language detection utilities for Markify.
Detects Power Query (M), DAX, Python, and SQL code patterns.
Patterns are loaded dynamically from config for user customization.
"""
from __future__ import annotations

import re

# Import config for dynamic patterns
from config import get_patterns
from config import reload_patterns as _reload_config


# =============================================================================
# Dynamic Pattern Accessors
# =============================================================================
def _get_dax_keywords() -> list[str]:
    """Get DAX keywords from config."""
    return get_patterns().get("dax_keywords", [])


def _get_dax_functions() -> list[str]:
    """Get DAX functions from config."""
    return get_patterns().get("dax_functions", [])


def _get_python_keywords() -> list[str]:
    """Get Python keywords from config."""
    return get_patterns().get("python_keywords", [])


def _get_python_builtins() -> list[str]:
    """Get Python builtins from config."""
    return get_patterns().get("python_builtins", [])


def _get_powerquery_exact_matches() -> list[str]:
    """Get Power Query exact match patterns from config."""
    return get_patterns().get("powerquery_exact_matches", [])


def _get_powerquery_functions() -> list[str]:
    """Get Power Query function patterns from config."""
    return get_patterns().get("powerquery_functions", [])


def _get_sql_keywords() -> list[str]:
    """Get SQL keywords from config."""
    return get_patterns().get("sql_keywords", [])


def _get_sql_functions() -> list[str]:
    """Get SQL function patterns from config."""
    return get_patterns().get("sql_functions", [])


# For backward compatibility - export getter function references
# These are called as functions: DAX_KEYWORDS() instead of DAX_KEYWORDS
DAX_KEYWORDS = _get_dax_keywords
DAX_FUNCTIONS = _get_dax_functions
PYTHON_KEYWORDS = _get_python_keywords
PYTHON_BUILTINS = _get_python_builtins
SQL_KEYWORDS = _get_sql_keywords
SQL_FUNCTIONS = _get_sql_functions


# Reload function for refreshing patterns after config changes
def reload_patterns() -> None:
    """Reload patterns from config file."""
    _reload_config()


# =============================================================================
# Detection Functions
# =============================================================================

def is_code_content(text: str) -> bool:
    """Check if text looks like M/Power Query code."""
    text_stripped = text.strip()

    # Exact matches
    if text_stripped in ['let', 'in', 'Source', '[', ']', ']),', '))', ')),']:
        return True

    # Lines that are just variable names (result of in clause)
    if text_stripped == 'Source':
        return True

    # M code patterns - starts with
    if text_stripped.startswith('let') or text_stripped.startswith('in'):
        return True

    # Handle line-numbered code (e.g., "1 let")
    if re.match(r'^\d+\s+let\b', text_stripped):
        return True

    # Assignment patterns
    if re.match(r'^\s*(Source|ApiKey|TokenResponse|SecretResponse|AccessToken)\s*=', text_stripped):
        return True
    if re.match(r'^\s*\w+\s*=\s*(Web\.Contents|Json\.Document|Text\.ToBinary)', text_stripped):
        return True

    # Function calls
    if 'Web.Contents(' in text_stripped or 'Json.Document(' in text_stripped:
        return True
    if 'Text.ToBinary(' in text_stripped:
        return True

    # Array/record patterns
    if text_stripped.startswith('[') and ('=' in text_stripped or text_stripped == '['):
        return True
    if text_stripped.startswith('Content = ') or text_stripped.startswith('Headers = '):
        return True

    # Closing patterns
    if text_stripped in [']),', '))', ')),', ']', ']),']:
        return True
    if text_stripped.endswith(']),') or text_stripped.endswith(')),'):
        return True

    # URLs in quotes (likely part of API calls)
    if text_stripped.startswith('"https://') and text_stripped.endswith('",'):
        return True

    # Indented code lines (4 spaces)
    if text.startswith('    ') and ('=' in text_stripped or '[' in text_stripped):
        return True

    return False


def is_dax_content(text: str) -> bool:
    """Check if text looks like DAX (Data Analysis Expressions) code."""
    text_stripped = text.strip().upper()
    text_original = text.strip()

    # Check for DAX keywords at start of line
    for keyword in _get_dax_keywords():
        # Exact match (standalone keyword)
        if text_stripped == keyword:
            return True
        if text_stripped.startswith(keyword + ' ') or text_stripped.startswith(keyword + '('):
            return True
        # Also check with line numbers (e.g., "1 EVALUATE")
        if re.match(rf'^\d+\s+{keyword}\b', text_stripped):
            return True

    # Check for DAX function calls
    for func in _get_dax_functions():
        if f'{func}(' in text_stripped:
            return True

    # DAX measure definition pattern: MeasureName := expression
    if ':=' in text_original:
        return True

    # Table[Column] reference pattern (common in DAX)
    if re.search(r"'?[\w\s]+'?\[[\w\s]+\]", text_original):
        return True

    # DAX table reference in single quotes: 'Table Name'
    if re.search(r"'[\w\s]+'\[", text_original):
        return True

    return False


def is_python_content(text: str) -> bool:
    """Check if text looks like Python code."""
    text_stripped = text.strip()

    # Python keywords at start of line
    for keyword in _get_python_keywords():
        if text_stripped.startswith(keyword):
            return True

    # Decorators
    if text_stripped.startswith('@') and not text_stripped.startswith('@{'):  # Exclude M code
        return True

    # Python main block
    if "__name__" in text_stripped and "__main__" in text_stripped:
        return True

    # Common Python patterns
    for builtin in _get_python_builtins():
        if builtin in text_stripped:
            return True

    # Python-style function definition with type hints
    if re.match(r'^def\s+\w+\s*\([^)]*\)\s*(->\\s*\w+)?\s*:', text_stripped):
        return True

    # Python class definition
    if re.match(r'^class\s+\w+.*:', text_stripped):
        return True

    # Python import patterns
    if re.match(r'^from\s+[\w.]+\s+import\s+', text_stripped):
        return True

    # Python list comprehension or generator
    if re.search(r'\[.+\s+for\s+\w+\s+in\s+', text_stripped):
        return True

    # Python f-string
    if re.search(r'f["\'][^"\']*\{', text_stripped):
        return True

    return False


def is_sql_content(text: str) -> bool:
    """Check if text looks like SQL code."""
    text_stripped = text.strip()
    text_upper = text_stripped.upper()

    # Exclude DAX-specific patterns (check these first to avoid false positives)
    dax_indicators = ["EVALUATE", "DEFINE MEASURE", "MEASURE ", ":=", "VAR "]
    if any(text_upper.startswith(ind) for ind in dax_indicators):
        return False
    if ":=" in text_stripped:  # DAX measure definition
        return False
    # DAX Table[Column] notation - single quotes around table names
    if re.search(r"'[^']+'\[[^\]]+\]", text_stripped):
        return False

    # Check for SQL keywords at start of line
    sql_start_keywords = ["SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER",
                          "DROP", "WITH", "DECLARE", "EXEC", "TRUNCATE", "MERGE"]
    for keyword in sql_start_keywords:
        if text_upper.startswith(keyword + " ") or text_upper.startswith(keyword + "\n"):
            return True
        if text_upper == keyword:
            return True

    # Check for common SQL clauses (these are very SQL-specific)
    sql_clauses = ["FROM ", "WHERE ", "INNER JOIN", "LEFT JOIN", "RIGHT JOIN", "FULL JOIN",
                   "GROUP BY", "ORDER BY", "HAVING ", "UNION ALL", "INSERT INTO", "VALUES ("]
    for clause in sql_clauses:
        if clause in text_upper:
            return True

    # SQL-style comments
    if text_stripped.startswith("--"):
        return True

    # T-SQL variable pattern: @VariableName with SQL context
    if re.search(r'@\w+', text_stripped) and any(kw in text_upper for kw in ["SET @", "DECLARE @", "WHERE @"]):
        return True

    return False


def detect_code_language(text: str) -> str | None:
    """
    Detect the programming language of a code snippet.

    Returns:
        'powerquery' for M/Power Query code
        'dax' for DAX expressions
        'python' for Python code
        'sql' for SQL code
        None if no code detected
    """
    # Check in order of specificity
    if is_code_content(text):  # M/Power Query (most specific patterns)
        return 'powerquery'
    if is_sql_content(text):  # SQL before DAX (SELECT...FROM is distinctive)
        return 'sql'
    if is_dax_content(text):
        return 'dax'
    if is_python_content(text):
        return 'python'
    return None
