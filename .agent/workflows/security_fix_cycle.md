---
description: Run security and linting scans, fix issues, and validate.
---

1. Create a `security` folder if it doesn't exist.
2. Run `ruff check . --output-format json > security/ruff_results.json` and `bandit -r . -f json -o security/bandit_results.json`.
3. Iterate over files with issues:
    a. Create a backup of the file (e.g., `filename.py.bak`).
    b. Apply fixes (replace content).
    c. Run tools again on the file to validate.
    d. If valid, delete backup. If invalid, restore backup.
4. Run full scan again to confirm project is clean.
5. If clean, empty the JSON files (or write strict schema placeholder).
