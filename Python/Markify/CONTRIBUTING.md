# Contributing to Markify

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

---

## Getting Started

1. **Fork** the repository
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/code-examples.git
   ```
3. **Create a branch** for your feature or fix:
   ```bash
   git checkout -b feature/my-new-feature
   ```

---

## Development Setup

### Prerequisites
- Python 3.10+
- No external dependencies required (uses only standard library)

### Running from Source
```bash
python src/markify_app.py
```

### Running Tests
```bash
python -m pytest tests/ -v
```

**Test Coverage includes:**
- `test_helpers.py` - Core conversion logic and code detection
- `test_detectors.py` - Power Query, DAX, Python, SQL pattern detection
- `test_html_to_md.py` - HTML-to-Markdown conversion (clipboard mode)
- `test_clipboard_code_detection.py` - Code block detection and formatting
- `test_templates.py` - Template variable substitution
- `test_confluence.py` - Confluence wiki syntax export
- `test_diff_view.py` - Side-by-side diff comparison
- `test_folder_scanner.py` - Recursive folder processing
- `test_front_matter.py` - YAML front matter generation
- `test_md_to_docx.py` - Reverse conversion (MD → DOCX)
- `test_round_trip.py` - Round-trip fidelity (DOCX↔MD↔DOCX)
- `test_quick_wins.py` - TOC generator, Obsidian export, footnotes

**Run with coverage report:**
```bash
python -m pytest tests/ --cov=src --cov-report=term-missing
```

---

## Code Style

- Use **4 spaces** for indentation (no tabs)
- Follow **PEP 8** naming conventions
- Add **docstrings** to new functions
- Keep functions focused and reasonably sized

---

## Quality Standards (CI/CD)

This project enforces **Linting** and **Security** checks in the CI pipeline.

### 1. Linting (Ruff)
We use `ruff` to ensure code style and catch errors.
```bash
pip install ruff
ruff check .
```

### 2. Security (Bandit)
We use `bandit` to scan for common security vulnerabilities.
```bash
pip install bandit
bandit -r . -x ./dist,./build
```

**Note:** Both of these checks **must pass** before your PR can be merged. The CI workflow (`.github/workflows/test.yml`) runs them automatically.

---

## Submitting Changes

1. **Run tests** before submitting:
   ```bash
   python -m pytest tests/
   ```
2. **Commit** with a clear message:
   ```bash
   git commit -m "Add feature: description of change"
   ```
3. **Push** to your fork:
   ```bash
   git push origin feature/my-new-feature
   ```
4. **Open a Pull Request** against the `main` branch

---

## Reporting Issues

When reporting bugs, please include:
- Python version (`python --version`)
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Sample `.docx` file if applicable (or describe its structure)

---

## Questions?

Contact: steve.wolfe@kcc.com
