# Developer Guide

This guide covers setting up a development environment, project structure, testing, and contributing to Markify.

---

## Prerequisites

- **Python 3.10+**
- **Git** for version control
- No external runtime dependencies!

---

## Setup

### Clone the Repository
```bash
git clone https://github.com/swolfe2/Markify.git
cd Markify
```

### Install Development Dependencies
```bash
pip install pytest ruff bandit pyinstaller
```

### Run from Source
```bash
python src/markify_app.py
```

---

## Project Structure

```
Markify/
├── src/                    # Source code
│   ├── markify_app.py      # Main GUI application
│   ├── markify_core.py     # Core conversion engine
│   ├── config.py           # Configuration management
│   ├── themes.py           # Theme definitions
│   ├── core/               # Core modules
│   │   ├── converters/     # Format converters
│   │   ├── detectors/      # Code detection
│   │   └── formatters/     # Output formatters
│   ├── ui/                 # UI components
│   └── cli/                # Command-line interface
├── tests/                  # Test suite
├── samples/                # Demo files
├── resources/              # Icons and assets
├── dist/                   # Built executable
└── wiki/                   # Wiki pages
```

---

## Key Modules

| Module | Purpose |
|--------|---------|
| `markify_app.py` | Main GUI entry point, window management |
| `markify_core.py` | DOCX parsing and Markdown generation |
| `config.py` | User preferences and pattern configuration |
| `themes.py` | Color theme definitions |
| `win_dnd.py` | Windows drag-and-drop (ctypes) |
| `win_clipboard.py` | Windows clipboard access (ctypes) |
| `watch_mode.py` | Folder monitoring for auto-conversion |
| `xlsx_core.py` | Excel table extraction |

---

## Running Tests

### Full Test Suite
```bash
python -m pytest tests/ -v
```

### With Coverage Report
```bash
python -m pytest tests/ --cov=src --cov-report=term-missing
```

### Test Categories

| Test File | Coverage |
|-----------|----------|
| `test_helpers.py` | Core conversion logic |
| `test_detectors.py` | DAX, M, Python, SQL detection |
| `test_html_to_md.py` | HTML-to-Markdown (clipboard) |
| `test_templates.py` | Template variable substitution |
| `test_confluence.py` | Confluence wiki export |
| `test_diff_view.py` | Side-by-side diff |
| `test_folder_scanner.py` | Recursive folder processing |
| `test_front_matter.py` | YAML front matter |
| `test_md_to_docx.py` | Reverse conversion |
| `test_round_trip.py` | Round-trip fidelity |
| `test_quick_wins.py` | TOC, Obsidian, footnotes |

---

## Code Quality

### Linting (Ruff)
```bash
ruff check .
```

### Security Scan (Bandit)
```bash
bandit -r . -x ./dist,./build
```

Both checks run automatically in CI/CD.

---

## Building the Executable

### Create Standalone EXE
```bash
pyinstaller Markify.spec
```

Output: `dist/Markify/Markify.exe`

### Spec File Options
The `Markify.spec` file configures:
- Icon embedding
- Hidden imports
- Data files (resources)
- Single-folder bundle

---

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/test.yml`):

1. **Lint** – Ruff code style check
2. **Security** – Bandit vulnerability scan
3. **Test** – pytest suite
4. **Build** – PyInstaller executable

All checks must pass before merging PRs.

---

## Contributing

### Workflow
1. **Fork** the repository
2. **Create branch**: `git checkout -b feature/my-feature`
3. **Make changes** and add tests
4. **Run checks**: `ruff check . && python -m pytest tests/`
5. **Commit**: `git commit -m "Add feature: description"`
6. **Push**: `git push origin feature/my-feature`
7. **Open PR** against `main`

### Code Style
- 4 spaces indentation (no tabs)
- PEP 8 naming conventions
- Docstrings on public functions
- Type hints encouraged

### Issue Templates
- **Bug Report**: Include Python version, OS, steps to reproduce
- **Feature Request**: Describe use case and expected behavior

---

## Architecture Notes

### Zero Dependencies Philosophy
Markify uses only Python standard library:
- `tkinter` for GUI
- `xml.etree` for DOCX/XLSX parsing
- `zipfile` for archive handling
- `ctypes` for Windows API (drag-drop, clipboard)

This ensures:
- Easy installation
- Corporate environment compatibility
- No supply chain security concerns

### Theme System
Themes are defined in `themes.py` as dictionaries:
```python
THEMES = {
    "dracula": {
        "bg": "#282a36",
        "fg": "#f8f8f2",
        "accent": "#bd93f9",
        ...
    }
}
```

### Code Detection
Pattern matching in `core/detectors/`:
- Keyword lists (fast matching)
- Regex patterns (complex rules)
- Confidence scoring (avoid false positives)
