# FAQ & Troubleshooting

Common questions and solutions for Markify users.

---

## Installation Issues

### Q: "File is locked" error when converting
**A:** Close the Word document before converting. Word locks open files.

### Q: EXE is blocked by security software
**A:** Use `Markify.bat` instead of the EXE. Some corporate security tools (BeyondInsight, etc.) block unsigned executables.

### Q: "Python not found" error
**A:** Install Python 3.10+ and ensure it's in your PATH. Download from [python.org](https://www.python.org/downloads/).

### Q: Application window is blank or frozen
**A:** Try these steps:
1. Close and reopen the application
2. Delete `markify_prefs.json` to reset settings
3. Run from command line to see error messages:
   ```bash
   python src/markify_app.py
   ```

---

## Conversion Issues

### Q: Tables aren't formatting correctly
**A:** Ensure your Word table uses simple formatting. Complex merged cells may not convert perfectly.

### Q: Code isn't being detected
**A:** Check that your code matches detection patterns:
- DAX: Contains `CALCULATE`, `SUMX`, `:=`, etc.
- Power Query: Has `let`/`in` or `#"` patterns
- Python: Uses `def`, `class`, `import`
- SQL: Contains `SELECT`, `FROM`, `WHERE`

You can also customize patterns in **Options → Edit Patterns**.

### Q: Images aren't extracted
**A:** Enable image extraction in **Options → Extract Images** ✓

### Q: Hyperlinks are missing
**A:** Ensure links in Word are actual hyperlinks (right-click → Edit Hyperlink), not just blue underlined text.

### Q: Emojis aren't displaying
**A:** Markdown output includes emojis, but your viewer needs emoji support. Try VS Code or a modern browser.

---

## API Formatting Issues

### Q: DAX formatting fails
**A:** 
- Check internet connection
- The API at daxformatter.com may be temporarily unavailable
- Try disabling the option and formatting manually

### Q: Power Query formatting produces errors
**A:**
- Verify your code is valid Power Query
- The API validates syntax and rejects invalid code
- Check for unterminated strings or brackets

---

## Performance

### Q: Large documents take a long time
**A:** Markify processes documents in memory. Very large documents (100+ pages) may take longer. Consider:
- Splitting into smaller documents
- Disabling image extraction
- Disabling API formatting

### Q: Watch Mode uses too much CPU
**A:** The folder watcher polls periodically. If monitoring large directories, use a specific subfolder instead.

---

## Output Quality

### Q: Markdown looks different in different editors
**A:** Markdown rendering varies by tool. For best results:
- Use VS Code with Markdown preview
- Install recommended extensions (see below)
- GitHub renders GFM (GitHub Flavored Markdown)

### Q: How do I verify round-trip fidelity?
**A:** 
1. Convert DOCX → MD
2. Convert MD → DOCX
3. Use **Diff View** to compare original and result

---

## VS Code Extensions

For the best Markdown viewing experience:

| Extension | Purpose |
|-----------|---------|
| [Markdown Preview Mermaid Support](https://open-vsx.org/vscode/item?itemName=bierner.markdown-mermaid) | Render diagrams |
| [Python](https://open-vsx.org/vscode/item?itemName=ms-python.python) | Syntax highlighting |
| [DAX Formatter](https://open-vsx.org/vscode/item?itemName=DaxFormatter.DaxFormatter) | DAX highlighting |
| [SQL Server](https://open-vsx.org/vscode/item?itemName=ms-mssql.mssql) | SQL highlighting |

---

## Tips & Tricks

### Quick Clipboard Conversion
1. Copy text in Word (`Ctrl+C`)
2. Open Markify
3. Press `Ctrl+V`
4. Instant Markdown!

### Bulk Convert a Folder
Drag and drop a folder onto Markify to convert all `.docx` files recursively.

### Preview in Browser
Click the **Browser Preview** button to open your Markdown in a live renderer for instant visual feedback.

### Reset All Settings
Delete `markify_prefs.json` in the application folder to start fresh.

---

## Still Need Help?

- **GitHub Issues**: [Report a bug](https://github.com/swolfe2/Markify/issues)
- **Email**: swolfe2@gmail.com
- **Security Issues**: See [SECURITY.md](https://github.com/swolfe2/Markify/blob/main/SECURITY.md)
