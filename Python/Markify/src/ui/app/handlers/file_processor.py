"""
File processing and conversion handler.
Handles the core conversion logic for DOCX and XLSX files.
"""
from __future__ import annotations

import os
import threading
from collections.abc import Callable

from core.error_types import classify_docx_error, classify_xlsx_error
from markify_core import get_docx_content
from xlsx_core import get_xlsx_content


class FileProcessor:
    """Handles file conversion operations."""

    def __init__(
        self,
        prefs: object,
        colors: dict[str, str],
        on_progress: Callable[[str], None] | None = None,
        on_complete: Callable[[bool, str, dict], None] | None = None,
    ):
        """
        Initialize file processor.

        Args:
            prefs: Preferences object.
            colors: Theme color dictionary.
            on_progress: Callback for progress updates.
            on_complete: Callback when conversion completes (success, output_path, error_info).
        """
        self.prefs = prefs
        self.colors = colors
        self.on_progress = on_progress
        self.on_complete = on_complete

    def process_docx(
        self,
        source_path: str,
        format_dax: bool = False,
        format_pq: bool = False,
        extract_images: bool = False,
        add_front_matter: bool = False,
        add_toc: bool = False,
    ) -> tuple[bool, str | None, dict | None]:
        """
        Process a DOCX file conversion.

        Returns:
            Tuple of (success, output_path, error_info).
        """
        try:
            if self.on_progress:
                self.on_progress(f"Converting {os.path.basename(source_path)}...")

            # Get output path
            output_mode = self.prefs.get("output_mode", "same")
            if output_mode == "custom":
                custom_dir = self.prefs.get("custom_output_dir", "")
                if custom_dir and os.path.exists(custom_dir):
                    base_name = os.path.splitext(os.path.basename(source_path))[0]
                    output_path = os.path.join(custom_dir, f"{base_name}.md")
                else:
                    output_path = os.path.splitext(source_path)[0] + ".md"
            else:
                output_path = os.path.splitext(source_path)[0] + ".md"

            # Perform conversion
            content = get_docx_content(
                source_path,
                format_dax_code=format_dax,
                format_pq_code=format_pq,
                extract_images=extract_images,
                progress_callback=self.on_progress,
            )

            # Add front matter if requested
            if add_front_matter:
                from core.frontmatter import add_front_matter_to_markdown

                content = add_front_matter_to_markdown(
                    content, source_path, title=None, author=None
                )

            # Add TOC if requested
            if add_toc:
                from core.toc_generator import insert_toc

                content = insert_toc(content, position="after_title")

            # Write output
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(content)

            if self.on_progress:
                self.on_progress("Conversion complete!")

            return (True, output_path, None)

        except Exception as e:
            error_info = classify_docx_error(e, source_path)
            return (False, None, error_info)

    def process_xlsx(
        self,
        source_path: str,
    ) -> tuple[bool, str | None, dict | None]:
        """
        Process an XLSX file conversion.

        Returns:
            Tuple of (success, output_path, error_info).
        """
        try:
            if self.on_progress:
                self.on_progress(f"Converting {os.path.basename(source_path)}...")

            # Get output path
            output_mode = self.prefs.get("output_mode", "same")
            if output_mode == "custom":
                custom_dir = self.prefs.get("custom_output_dir", "")
                if custom_dir and os.path.exists(custom_dir):
                    base_name = os.path.splitext(os.path.basename(source_path))[0]
                    output_path = os.path.join(custom_dir, f"{base_name}.md")
                else:
                    output_path = os.path.splitext(source_path)[0] + ".md"
            else:
                output_path = os.path.splitext(source_path)[0] + ".md"

            # Perform conversion
            content = get_xlsx_content(
                source_path,
                progress_callback=self.on_progress,
            )

            # Write output
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(content)

            if self.on_progress:
                self.on_progress("Conversion complete!")

            return (True, output_path, None)

        except Exception as e:
            error_info = classify_xlsx_error(e, source_path)
            return (False, None, error_info)

    def process_async(
        self,
        source_path: str,
        is_xlsx: bool = False,
        format_dax: bool = False,
        format_pq: bool = False,
        extract_images: bool = False,
        add_front_matter: bool = False,
        add_toc: bool = False,
    ) -> None:
        """
        Process file conversion in a background thread.

        Args:
            source_path: Path to source file.
            is_xlsx: True if XLSX file, False for DOCX.
            format_dax: Enable DAX formatting.
            format_pq: Enable Power Query formatting.
            extract_images: Extract embedded images.
            add_front_matter: Add YAML front matter.
            add_toc: Add table of contents.
        """
        def run_thread():
            if is_xlsx:
                success, output_path, error_info = self.process_xlsx(source_path)
            else:
                success, output_path, error_info = self.process_docx(
                    source_path,
                    format_dax=format_dax,
                    format_pq=format_pq,
                    extract_images=extract_images,
                    add_front_matter=add_front_matter,
                    add_toc=add_toc,
                )

            if self.on_complete:
                self.on_complete(success, output_path, error_info)

        thread = threading.Thread(target=run_thread, daemon=True)
        thread.start()

