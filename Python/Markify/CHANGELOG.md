# Changelog

All notable changes to **Markify** will be documented in this file.

Format based on Keep a Changelog (keepachangelog.com).

## Legend

- **[NEW]** - New feature
- **[CHANGED]** - Changed behavior
- **[FIXED]** - Bug fix
- **[REMOVED]** - Removed/deprecated

---

## [1.0.0] - 2026-01-05

### [NEW]
- **Complete DOCX to Markdown Converter** - Zero dependencies, pure Python stdlib
- **Clipboard Mode** - Paste formatted text from Word → instant Markdown conversion
- **Watch Mode** - Auto-convert files dropped into a watched folder
- **MD→DOCX Conversion** - Reverse conversion from Markdown to Word
- **Preview Before Save** - View converted Markdown with syntax highlighting
- **Recent Files List** - Quick access to last 5 conversions
- **Drag & Drop** - Drop `.docx` files or folders onto the app
- **7 Color Themes** - Dracula, Nord, Solarized, and more
- **YAML Front Matter** - Hugo/Jekyll-compatible metadata headers
- **Confluence Export** - Convert Markdown to Confluence wiki markup
- **Template System** - User-defined templates with variables
- **App Icon** - Custom Markify logo in title bar, taskbar, and main window
- **Round-Trip Fidelity Testing** - Automated tests for Word ↔ Markdown conversions
- **Table Support in MD→DOCX** - Markdown tables now convert to proper Word tables
- **Keyboard Shortcuts Panel** - Press `F1` to view all shortcuts
- **Export Statistics** - Word count, reading time, header breakdown in preview
- **Table of Contents Generator** - Auto-generate linked TOC from headers
- **Diff View** - Side-by-side comparison of two Markdown files
- **Footnote Support** - Convert Word footnotes to Markdown syntax
- **Obsidian Export** - Wikilinks and callout syntax support
- **Code Block Detection** - Auto-detect Power Query, DAX, Python, SQL
- **Optional API Formatting** - Format DAX/M code via external APIs
- **Image Extraction** - Extract embedded images to subfolder
- **Hyperlink Preservation** - Convert Word links to Markdown syntax
- **Browser Preview** - One-click preview in live Markdown renderer
- **Round-Trip Fidelity Fixes** - Code block fencing and multi-line paragraph preservation
- **Word Style Mapping** - Configurable mapping of Word styles → Markdown elements
- **Cross-Reference Support** - Handle Word bookmarks and internal cross-refs
- **Improved Error Handling** - User-friendly error messages with actionable hints

### [CHANGED]
- Modern UI with smooth transitions
- Refactored `get_heading_style_level()` to use configurable mappings
- Added `src/core/error_types.py` for structured error classification
- Improved table detection and formatting
- Better handling of nested lists
- Reorganized `samples/` folder structure

### [FIXED]
- Table formatting preserved in round-trip conversions
- Success dialog now uses custom app icon
- Specific detection for locked files, corrupted documents, password protection

### [NEW]
- **Clipboard Mode** - Paste formatted text from Word → instant Markdown conversion
- **Watch Mode** - Auto-convert files dropped into a watched folder
- **MD→DOCX Conversion** - Reverse conversion from Markdown to Word
- **Preview Before Save** - View converted Markdown with syntax highlighting
- **Recent Files List** - Quick access to last 5 conversions
- **Drag & Drop** - Drop `.docx` files or folders onto the app
- **7 Color Themes** - Dracula, Nord, Solarized, and more
- **YAML Front Matter** - Hugo/Jekyll-compatible metadata headers
- **Confluence Export** - Convert Markdown to Confluence wiki markup
- **Template System** - User-defined templates with variables

### [CHANGED]
- Updated UI with modern design and smooth transitions

---

## [0.9.0] - 2025-12-20

### [NEW]
- **Code Block Detection** - Auto-detect Power Query, DAX, Python, SQL
- **Optional API Formatting** - Format DAX/M code via external APIs
- **Image Extraction** - Extract embedded images to subfolder
- **Hyperlink Preservation** - Convert Word links to Markdown syntax
- **Browser Preview** - One-click preview in live Markdown renderer

### [CHANGED]
- Improved table detection and formatting
- Better handling of nested lists

---

## [0.8.0] - 2025-12-20

### [NEW]
- Initial release
- Basic DOCX to Markdown conversion
- GUI application with file selection
- Header detection (Title, Heading 1-6)
- Table conversion to Markdown format
- Emoji header support


