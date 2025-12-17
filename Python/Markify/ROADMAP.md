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
- [x] SQL Code Detection (SELECT, INSERT, JOIN patterns with DAX conflict avoidance)
- [x] Mermaid Diagram Viewer (Auto-adds [mermaid.live](https://mermaid.live/) links to mermaid code blocks)

---

## Planned / In Progress 🚧

### High Priority

### Medium Priority
- [ ] **Reverse Conversion (MD → DOCX)**: Convert Markdown back to Word documents
- [ ] **Front Matter Generation**: Auto-generate YAML front matter for static site generators
- [ ] **Folder Mode**: Drop a folder → convert all `.docx` files recursively

### Low Priority / Nice-to-Have
- [ ] **Template System**: User-defined templates with variables (`{{filename}}`, `{{date}}`)
- [ ] **Confluence Wiki Syntax**: Output in Confluence/Jira markup instead of Markdown
- [ ] **Diff View**: Compare two `.md` files side-by-side

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute to this project.

Ideas and pull requests are welcome!
