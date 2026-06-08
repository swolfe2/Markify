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
- [x] Undo/Redo in Preview (Allows editing converted Markdown before saving)
- [x] Syntax Highlighting Themes (Monokai, GitHub Light, One Dark, Dracula)
- [x] Markdown Linting (Heading hierarchy, empty alt tags, malformed tables, broken relative links)
- [x] Auto-Update Check (Query GitHub Releases API asynchronously on launch)
- [x] Azure DevOps Wiki Format (Export formatted Word documents to native ADO Wiki syntax)
- [x] DAX Studio Integration (Import and format plain-text .dax/.msdax query files)
- [x] Power BI Report Metadata (Extract measures, tables, relationships from .pbix files)
- [x] Tabular Editor Integration (Import tables, columns, measures, and hierarchies from .bim/.tmdl files)
- [x] PowerPoint to Markdown (Convert slides, tables, and speaker notes from .pptx files)

---

## Planned / In Progress 🚧

Features are organized into sequential phases — **foundations first**, then extensions, then advanced features. All features should be **complete and tested** before PyPI publishing.

> **Design Principle:** Keep Markify dependency-free for all core features. The primary conversion path is `.docx` ↔ `.md`. Features requiring external libraries are deferred to the Future section.

---

### 🏗️ Phase 1 — UI Polish & Quick Wins

Self-contained, low-risk changes that touch isolated parts of the codebase. No conversion logic is modified.

#### 1. Undo/Redo in Preview ✅ `HIGH PRIORITY`
> Allow users to edit the converted Markdown in the preview dialog before saving.

**Implementation Steps:**
1. Make the preview Text widget editable (remove `state=DISABLED` default in `src/ui/dialogs/preview.py`)
2. Add an undo/redo stack using tkinter's built-in `Text` widget undo support (`undo=True`, `maxundo=-1`)
3. Bind `Ctrl+Z` / `Ctrl+Y` keyboard shortcuts
4. Add Undo/Redo buttons to the button row (between Cancel and Save)
5. Track "dirty" state — if user edits content, pass the modified text to `on_save` instead of original
6. Add confirmation prompt if user clicks Cancel after making edits
7. Update `src/ui/dialogs/shortcuts_dialog.py` to list the new shortcuts
8. Write tests for undo stack behavior

**Files Modified:** `src/ui/dialogs/preview.py`, `src/ui/dialogs/shortcuts_dialog.py`
**Risk:** Low — isolated to preview dialog, no conversion logic touched

---

#### 2. Syntax Highlighting Themes ✅
> Customizable color schemes for code blocks in the preview dialog.

**Implementation Steps:**
1. Define syntax color schemes in `src/themes.py` (e.g., Monokai, GitHub Light, One Dark — colors for keywords, strings, comments, numbers)
2. Extend `_apply_highlighting()` in `src/ui/dialogs/preview.py` to tokenize code fence contents and apply tag-based coloring
3. Add a "Code Theme" dropdown to the Options dialog (`src/ui/dialogs/options.py`)
4. Persist the selected code theme in preferences (`src/markify_prefs.py`)
5. Apply the selected theme when rendering preview and diff viewer
6. Update the diff viewer (`src/ui/dialogs/diff_viewer.py`) to use the same syntax theme

**Files Modified:** `src/themes.py`, `src/ui/dialogs/preview.py`, `src/ui/dialogs/options.py`, `src/markify_prefs.py`, `src/ui/dialogs/diff_viewer.py`
**Risk:** Low — purely cosmetic, no conversion logic touched

---

#### 3. Markdown Linting ✅
> Validate converted Markdown for common issues (broken links, missing alt text, malformed tables).

**Implementation Steps:**
1. Create `src/core/linter.py` with a `lint_markdown(content: str) -> list[LintIssue]` function
2. Define `LintIssue` dataclass (line number, severity, message, rule ID)
3. Implement lint rules:
   - Broken relative image/link references (check file existence)
   - Missing alt text on images (`![](url)` with empty alt)
   - Malformed table rows (inconsistent column count)
   - Consecutive blank lines (more than 2)
   - Missing heading hierarchy (e.g., H1 → H3 with no H2)
4. Show lint results in the preview dialog (icon/badge on status bar)
5. Add a "Lint" button or auto-lint toggle in Options
6. Write comprehensive tests in `tests/test_linter.py`

**Files Created:** `src/core/linter.py`, `tests/test_linter.py`
**Files Modified:** `src/ui/dialogs/preview.py`, `src/ui/dialogs/options.py`
**Risk:** Low — new module, additive only

---

#### 4. Auto-Update Check ✅
> Notify users when a new version of Markify is available.

**Implementation Steps:**
1. Create `src/core/update_checker.py`
2. On app launch, make an async HTTPS GET to GitHub Releases API (`https://api.github.com/repos/swolfe2/Markify/releases/latest`)
3. Compare remote version tag against `version` in `pyproject.toml` (or a `__version__` constant)
4. If newer version exists, show a non-blocking notification bar in the main window
5. Add "Check for Updates" option in the Help/About menu
6. Add a preference to disable auto-check (`src/markify_prefs.py`)
7. Handle network failures gracefully (timeout, no internet) — never block the UI

**Files Created:** `src/core/update_checker.py`
**Files Modified:** `src/markify_app.py`, `src/markify_prefs.py`
**Risk:** Low — network call is fire-and-forget, fully optional

---

### 🔧 Phase 2 — Format Expansion & Power BI Integration

These features extend Markify's conversion capabilities. They follow existing patterns in the codebase and use only stdlib. Power BI features are core to the product — Markify should recognize and correctly format code blocks from these tools.

#### 5. Azure DevOps Wiki Format ✅
> Export Markdown as Azure DevOps wiki syntax.

**Implementation Steps:**
1. Create `src/core/ado_wiki.py` following the same pattern as `src/core/confluence.py`
2. Implement ADO-specific syntax differences:
   - TOC macro (`[[_TOC_]]`)
   - Mermaid diagrams (`::: mermaid` fences)
   - Attachment links (`[text](/attachments/file)`)
   - Nested table handling
3. Add "Azure DevOps Wiki" option to the export format selector in Options
4. Wire into the conversion pipeline in `src/markify_app.py`
5. Write tests in `tests/test_ado_wiki.py`

**Files Created:** `src/core/ado_wiki.py`, `tests/test_ado_wiki.py`
**Files Modified:** `src/ui/dialogs/options.py`, `src/markify_app.py`
**Risk:** Low — follows proven Confluence exporter pattern

---

#### 6. DAX Studio Integration ✅
> Import `.dax` and `.msdax` query files directly into Markify for documentation.

**Implementation Steps:**
1. Create `src/core/dax_import.py`
2. Parse DAX Studio export files (plain text `.dax` files)
3. Wrap in Markdown code fences with `dax` language tag
4. Apply existing DAX formatting if enabled (reuse `src/core/formatters/dax.py`)
5. Add `.dax` / `.msdax` to the GUI file picker filter
6. Write tests in `tests/test_dax_import.py`

**Files Created:** `src/core/dax_import.py`, `tests/test_dax_import.py`
**Files Modified:** `src/markify_app.py` (file picker)
**Risk:** Low — leverages existing DAX detection and formatting infrastructure

---

#### 7. Power BI Report Metadata ✅
> Extract metadata from `.pbix` files (measures, tables, relationships) and generate Markdown documentation.

**Implementation Steps:**
1. Create `src/pbix_core.py`
2. Parse `.pbix` (ZIP file containing `DataModelSchema` JSON) using stdlib `zipfile` + `json`
3. Extract:
   - Table names and column lists
   - Measure definitions (DAX expressions → fenced code blocks)
   - Relationships between tables (→ Markdown table)
   - Report page names
4. Generate structured Markdown documentation with tables and code blocks
5. Add `.pbix` to the GUI file picker filter
6. Write tests with sample `.pbix` fixtures in `tests/test_pbix_conversion.py`

**Files Created:** `src/pbix_core.py`, `tests/test_pbix_conversion.py`
**Files Modified:** `src/markify_app.py` (file picker)
**Risk:** Medium — PBIX internal format may vary between Power BI versions. Needs defensive parsing.

---

#### 8. Tabular Editor Integration ✅
> Import BIM/TMDL model documentation files and generate Markdown.

**Implementation Steps:**
1. Create `src/core/tmdl_import.py`
2. Parse `.bim` files (JSON — Tabular Object Model) using stdlib `json`
3. Parse `.tmdl` files (text-based model definition format)
4. Extract table definitions, measures, calculated columns, hierarchies
5. Generate structured Markdown documentation with DAX code blocks
6. Leverage existing DAX detection (`src/core/detectors.py`) for measure formatting
7. Add `.bim` / `.tmdl` to the GUI file picker filter
8. Write tests in `tests/test_tmdl_import.py`

**Files Created:** `src/core/tmdl_import.py`, `tests/test_tmdl_import.py`
**Files Modified:** `src/markify_app.py` (file picker)
**Risk:** Medium — TMDL is a newer format; spec may evolve. BIM (JSON) is stable.

---

#### 9. PowerPoint to Markdown ✅
> Convert `.pptx` slide decks to Markdown, extracting slide content and speaker notes.

**Implementation Steps:**
1. Create `src/pptx_core.py` following the same pattern as `markify_core.py`
2. Parse PPTX (OOXML ZIP format) using stdlib `zipfile` + `xml.etree`:
   - Extract `ppt/slides/slide*.xml` for slide content
   - Extract `ppt/notesSlides/notesSlide*.xml` for speaker notes
   - Extract `ppt/media/*` for embedded images
3. Map slide elements to Markdown:
   - Title shapes → `# Heading`
   - Body text → paragraphs
   - Bullet lists → Markdown lists
   - Tables → Markdown tables (reuse `parse_table` logic)
   - Images → extracted + linked
4. Add slide separators (`---`) between slides
5. Speaker notes as blockquotes or collapsible sections below each slide
6. Update GUI file picker to accept `.pptx` files
7. Write tests in `tests/test_pptx_conversion.py`

**Files Created:** `src/pptx_core.py`, `tests/test_pptx_conversion.py`
**Files Modified:** `src/markify_app.py` (file picker filter)
**Risk:** Medium — PPTX XML schema is more complex than DOCX. Slide layout variations may need iterative refinement.

---

### 🚀 Phase 3 — Advanced Features & Packaging

These features have higher complexity or broader architectural impact. They depend on Phase 1/2 features being stable and tested.

#### 10. Git Integration ✅
> Auto-commit converted files to a Git repository after conversion.

**Implementation Steps:**
1. Create `src/core/git_integration.py`
2. Detect if output directory is inside a Git repository (`subprocess` call to `git rev-parse --git-dir`)
3. After successful save, optionally run:
   - `git add <output_file>`
   - `git commit -m "Markify: converted <source_file>"`
4. Add toggle in Options dialog: "Auto-commit after conversion"
5. Persist preference in `src/markify_prefs.py`
6. Handle edge cases: git not installed, dirty working tree, merge conflicts
7. Show commit status in success dialog

**Files Created:** `src/core/git_integration.py`
**Files Modified:** `src/ui/dialogs/options.py`, `src/markify_prefs.py`, `src/markify_app.py`
**Risk:** Medium — `subprocess` calls to `git`, must handle missing git gracefully

---

#### 11. Presentation Mode ⬜
> View Markdown as slides in a presentation format (reveal.js style).

**Implementation Steps:**
1. Create `src/ui/dialogs/presentation.py`
2. Split Markdown content on `---` horizontal rules or `## ` headings into slides
3. Render each slide in a full-screen tkinter window with:
   - Large text rendering
   - Code block display with syntax highlighting (reuse Phase 1 themes)
   - Navigation (arrow keys, mouse click)
4. Add "Present" button to preview dialog
5. Support slide-specific features: title slides, bullet animations (optional)
6. Alternative approach: generate a self-contained HTML file with reveal.js and open in browser

**Files Created:** `src/ui/dialogs/presentation.py`
**Files Modified:** `src/ui/dialogs/preview.py`
**Risk:** Medium — tkinter rendering limitations may affect visual quality. Browser-based approach is more polished but adds complexity.

> **Benefits from:** Syntax Highlighting Themes (#2), Markdown Linting (#3)

---

#### 12. PyPI Publishing ⬜ `CAPSTONE`
> Make Markify installable via `pip install markify`. This should be the **last feature** — ship after all above features are complete and tested.

**Implementation Steps:**
1. Verify `pyproject.toml` entry points work (`markify` CLI, `markify-gui` GUI)
2. Restructure `src/` as a proper Python package with `__init__.py` at the root if needed
3. Ensure all relative imports work when installed as a package (not just when run from `src/`)
4. Add `MANIFEST.in` to include `resources/`, `samples/`, and config files in the sdist
5. Create a GitHub Actions workflow for automated PyPI publishing on release tags
6. Test with `pip install -e .` locally and `pip install markify` from TestPyPI
7. Update README with `pip install markify` instructions
8. Tag a release version and publish to PyPI

**Files Modified:** `pyproject.toml`, `src/` package structure, `.github/workflows/`
**Files Created:** `MANIFEST.in` (if needed)
**Risk:** Low — packaging only, no logic changes. But requires careful import path testing across all new modules.

> **Prerequisite:** All features in Phases 1–3 (#1–#11) should be complete and passing tests before publishing.

---

### 🔮 Future / Distant

These features require external dependencies, significant architectural changes, or are lower priority. They are not blocked by the main build sequence and can be revisited after PyPI publishing.

#### Export to PDF ⬜
> Generate PDF output directly from converted Markdown. Likely requires an optional dependency for quality output.

#### Plugin System ⬜
> User-extensible converters and formatters via a plugin architecture. High architectural impact — design after core features are stable.

#### Localization (i18n) ⬜
> Multi-language UI support. Touches every UI file — best done after all UI features are finalized.

#### SharePoint/OneDrive Integration ⬜
> Direct cloud file access. Requires authentication, MS Graph API, and optional dependencies.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute to this project.

Ideas and pull requests are welcome!

