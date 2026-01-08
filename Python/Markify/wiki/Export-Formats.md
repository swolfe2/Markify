# Export Formats

Markify supports multiple output formats beyond standard Markdown.

---

## Standard Markdown

The default output format, compatible with:
- GitHub
- VS Code
- Any Markdown editor
- Static site generators

---

## Confluence / Jira Syntax

Export wiki markup for Atlassian products.

### Enable
**File → Export as Confluence**

### Syntax Differences

| Element | Markdown | Confluence |
|---------|----------|------------|
| Bold | `**text**` | `*text*` |
| Italic | `*text*` | `_text_` |
| Headers | `# H1` | `h1. H1` |
| Links | `[text](url)` | `[text\|url]` |
| Code | ` ``` ` | `{code}` |
| Tables | `\|---\|` | `\|\|heading\|\|` |

### Example Output
```
h1. Document Title

This is *bold* and _italic_ text.

{code:language=sql}
SELECT * FROM users
{code}
```

---

## Obsidian Export

Optimized output for the Obsidian knowledge base.

### Enable
**File → Export for Obsidian**

### Features

| Feature | Standard | Obsidian |
|---------|----------|----------|
| Links | `[text](page.md)` | `[[page]]` |
| Callouts | `> Note:` | `> [!note]` |
| Tags | N/A | `#tag` preserved |

### Callout Syntax
```markdown
> [!note]
> This is a note callout

> [!warning]
> This is a warning callout

> [!tip]
> This is a tip callout
```

---

## YAML Front Matter

Add metadata headers for static site generators.

### Enable
**Options → Generate YAML Front Matter** ✓

### Output Example
```yaml
---
title: "My Document"
date: 2026-01-06
slug: my-document
draft: false
---

# My Document

Content starts here...
```

### Compatible With
- **Hugo** – Static site generator
- **Jekyll** – GitHub Pages
- **Gatsby** – React-based sites
- **11ty** – JavaScript static sites

---

## Template System

Create custom output formats with variables.

### Built-in Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{filename}}` | Source filename | `Report.docx` |
| `{{title}}` | Document title | `Report` |
| `{{date}}` | Conversion date | `2026-01-06` |
| `{{time}}` | Conversion time | `14:30:00` |
| `{{content}}` | Converted Markdown | (full content) |

### Creating Templates

1. Go to **Options → Templates**
2. Click **New Template**
3. Enter template content with variables
4. Save with a descriptive name

### Example: Blog Post Template
```markdown
---
title: "{{title}}"
date: {{date}}
author: Your Name
categories: [documentation]
---

# {{title}}

{{content}}

---
*Converted from {{filename}} on {{date}}*
```

### Using a Template
1. Convert a document normally
2. In preview, select **Apply Template**
3. Choose your template
4. Content is reformatted

---

## Table of Contents

Auto-generate a linked TOC from headers.

### Enable
**Options → Generate TOC** ✓

### Output Example
```markdown
## Table of Contents

- [Introduction](#introduction)
- [Getting Started](#getting-started)
  - [Installation](#installation)
  - [Configuration](#configuration)
- [Features](#features)
```

### Customization
- Includes H1–H6 by default
- Nested based on heading level
- Anchor links auto-generated

---

## Image Extraction

Save embedded images to a subfolder.

### Enable
**Options → Extract Images** ✓

### Behavior
1. Images extracted to `{filename}_images/`
2. Markdown references updated:
   ```markdown
   ![Image](Report_images/image1.png)
   ```

### Supported Formats
- PNG
- JPEG
- GIF
- BMP
