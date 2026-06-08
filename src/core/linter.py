"""
Markdown Linter for Markify.
Provides structural and formatting validation rules for converted documents.
"""
from __future__ import annotations

import os
import re
import urllib.parse
from dataclasses import dataclass


@dataclass
class LintIssue:
    line_number: int
    severity: str  # "warning" or "error"
    message: str
    rule_id: str


def lint_markdown(content: str, base_dir: str | None = None) -> list[LintIssue]:
    """
    Scan markdown content for common formatting issues.

    Args:
        content: The Markdown content to validate.
        base_dir: Optional base directory to resolve relative file references.

    Returns:
        List of LintIssue objects.
    """
    issues: list[LintIssue] = []
    lines = content.splitlines()

    # Rule Patterns
    link_pattern = re.compile(r'(!?)\[(.*?)\]\((.*?)\)')

    # Stateful variables for rules
    last_heading_level = 0
    consecutive_blanks = 0
    in_table = False
    table_cols = 0
    table_start_line = 0

    for idx, line in enumerate(lines, 1):
        stripped = line.strip()

        # --- Rule 4: Malformed Tables (MD052) ---
        is_table_line = stripped.startswith('|') and stripped.endswith('|') and len(stripped) > 1
        if is_table_line:
            # Count columns (number of pipe characters)
            pipes = line.count('|')
            if not in_table:
                in_table = True
                table_cols = pipes
                table_start_line = idx
            else:
                if pipes != table_cols:
                    issues.append(
                        LintIssue(
                            line_number=idx,
                            severity="warning",
                            message=f"Table row column count ({pipes - 1}) differs from table start on line {table_start_line} ({table_cols - 1})",
                            rule_id="MD052",
                        )
                    )
        else:
            in_table = False

        # --- Rule 5: Consecutive Blank Lines (MD053) ---
        if not stripped:
            consecutive_blanks += 1
            if consecutive_blanks == 3:
                issues.append(
                    LintIssue(
                        line_number=idx,
                        severity="warning",
                        message="Three or more consecutive blank lines",
                        rule_id="MD053",
                    )
                )
        else:
            consecutive_blanks = 0

        # --- Rule 1: Heading Hierarchy (MD001) ---
        if stripped.startswith('#') and not in_table:
            # Count level
            level = 0
            for char in stripped:
                if char == '#':
                    level += 1
                else:
                    break
            # Ensure it is a valid heading level (1 to 6) and has a space after
            if 1 <= level <= 6 and len(stripped) > level and stripped[level] == ' ':
                if last_heading_level > 0 and level > last_heading_level + 1:
                    issues.append(
                        LintIssue(
                            line_number=idx,
                            severity="warning",
                            message=f"Heading level jumps too quickly from H{last_heading_level} to H{level}",
                            rule_id="MD001",
                        )
                    )
                last_heading_level = level

        # --- Rules 2 & 3: Image Alt Text (MD045) & Broken Links (MD051) ---
        # Don't look for links inside code fences
        # Simple fence check: we can ignore line rules check if they're inside fences
        # but for simplicity, we check if line starts with ```. Let's just track fence block
        # (Though links inside code fences are rare, we can skip link parsing if inside a block)
        pass

    # Better to track code block state globally to skip Rules 2 & 3 inside code blocks
    in_code_block = False
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code_block = not in_code_block
            continue

        if in_code_block:
            continue

        # Scan for links/images
        for match in link_pattern.finditer(line):
            is_image = bool(match.group(1))
            alt_text = match.group(2).strip()
            url = match.group(3).strip()

            # Rule 2: Image Alt Text (MD045)
            if is_image and not alt_text:
                issues.append(
                    LintIssue(
                        line_number=idx,
                        severity="warning",
                        message="Image is missing alt text",
                        rule_id="MD045",
                    )
                )

            # Rule 3: Broken Links/Images (MD051)
            # Skip remote paths or local section anchors
            if url.startswith(('http://', 'https://', 'mailto:', '#')):
                continue

            if base_dir:
                # Remove anchor from local file URL (e.g. "intro.md#section" -> "intro.md")
                clean_url = url.split('#')[0]
                if not clean_url:
                    continue  # Just an anchor on current page

                # Unquote URL encoding (e.g., spaces converted to %20)
                decoded_url = urllib.parse.unquote(clean_url)

                # Check file existence relative to base directory
                full_path = os.path.normpath(os.path.join(base_dir, decoded_url))
                if not os.path.exists(full_path):
                    ref_type = "Image" if is_image else "Link"
                    issues.append(
                        LintIssue(
                            line_number=idx,
                            severity="warning",
                            message=f"{ref_type} target file does not exist: {decoded_url}",
                            rule_id="MD051",
                        )
                    )

    # Sort issues by line number
    issues.sort(key=lambda x: x.line_number)
    return issues
