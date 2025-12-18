# Roadmap

This document tracks planned enhancements and feature ideas for the Word to Markdown Converter.

---

## Completed ✅

- [x] Core DOCX to Markdown conversion
- [x] GUI with dark mode theme
- [x] Batch processing (multi-file selection)
- [x] Standalone executable (.exe)
- [x] Built-in documentation viewer
- [x] Code block detection (Power Query/M code)
- [x] Table conversion
- [x] DAX code detection with language-tagged fences
- [x] Python code detection with language-tagged fences
- [x] SQL code detection with language-tagged fences
- [x] DAX Formatter API integration module
- [x] Power Query Formatter API integration module
- [x] Hyperlink preservation (converts Word links to Markdown)
- [x] Drag & Drop Support (Zero-dependency ctypes implementation)
- [x] Preferences Persistence (Last folder, DAX check)
- [x] Progress Bar (Visual feedback for batch processing)
- [x] Output Folder Selector (Custom vs Input folder)
- [x] Image Extraction (Save embedded images to folder)
- [x] UI Redesign (Options dialog, improved landing page)
- [x] Type Hints (Python type annotations throughout codebase)
- [x] Logging (Replaced `print()` with proper `logging` module)
- [x] Dark/Light Theme Toggle (7 themes including Dracula, Nord, Solarized)
- [x] Recent Files List (Table view with clickable links, smart deduplication)
- [x] Diff Preview (Preview dialog before saving with syntax highlighting)
- [x] Config File (JSON-based customizable detection patterns)
- [x] Clipboard Conversion (Paste formatted text → Markdown with HTML parsing)
- [x] Excel Table Import (Convert `.xlsx` tables to Markdown tables, zero deps)
- [x] Watch Mode (Monitor folder and auto-convert new `.docx`/`.xlsx` files)
- [x] Custom App Icon (W→M branded icon with transparent background)
- [x] Mermaid Diagram Viewer (Auto-adds [mermaid.live](https://mermaid.live/) links to mermaid code blocks)
- [x] Folder Mode (Drop a folder → convert all `.docx`/`.xlsx` files recursively)
- [x] Front Matter Generation (YAML header with title, date, slug for Hugo/Jekyll)
- [x] Reverse Conversion (MD → DOCX using pure Python XML generation)
- [x] Template System (User-defined templates with variables `{{filename}}`, `{{date}}`)
- [x] Confluence Wiki Syntax (Output in Confluence/Jira markup instead of Markdown)
- [x] Diff View (Compare two `.md` files side-by-side with highlighting)
- [x] Table of Contents Generation (Auto-generate TOC from headers)
- [x] Footnote Conversion (Word footnotes → Markdown `[^1]` format)
- [x] Obsidian Export (Wikilinks `[[page]]`, callout blocks support)
- [x] Export Statistics (Word count, reading time, header structure)
- [x] Keyboard Shortcuts Panel (Show all hotkeys via F1 key)
- [x] Round-Trip Table Fidelity (Tables preserved in Word↔Markdown cycles)
- [x] CI/CD Round-Trip Testing (Automated tests for Word↔MD fidelity)
- [x] Standardized App Icon (Icon displayed on all dialogs and windows)
- [x] Changelog (CHANGELOG.md with "What's New" in-app viewer)
- [x] Round-Trip Fidelity Fixes (Code block fencing, multi-line paragraphs)
- [x] Improved Error Handling (User-friendly messages for locked/corrupted files)
- [x] Word Style Mapping (Custom mapping of Word styles → Markdown elements)
- [x] Cross-Reference Support (Handle Word bookmarks and cross-refs)

---

## Planned / In Progress 🚧

### High Priority
- [ ] **Undo/Redo in Preview** - Allow edits before saving

### Medium Priority
- [ ] **Export to PDF** - Direct PDF generation from Markdown
- [ ] **Syntax Highlighting Themes** - Customizable code block colors
- [ ] **PowerPoint to Markdown** - Extract slides/speaker notes
- [ ] **Markdown Linting** - Check for broken links, missing alt text
- [ ] **Git Integration** - Auto-commit after conversion
- [ ] **Presentation Mode** - View Markdown as slides (reveal.js style)
- [ ] **Azure DevOps Wiki Format** - Direct export to ADO wiki syntax

### Low Priority / Nice-to-Have
- [ ] **Auto-Update Check** - Notify users of new versions
- [ ] **Localization (i18n)** - Multi-language UI support
- [ ] **Plugin System** - User-extensible converters/formatters
- [ ] **SharePoint/OneDrive Integration** - Direct cloud file access

### Power BI Specific (Future)
- [ ] **DAX Studio Integration** - Import queries directly
- [ ] **Power BI Report Metadata** - Extract info from `.pbix`
- [ ] **Tabular Editor Integration** - Import model documentation

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute to this project.

Ideas and pull requests are welcome!

