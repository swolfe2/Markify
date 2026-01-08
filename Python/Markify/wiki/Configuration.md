# Configuration & Options

Customize Markify's behavior through the Options dialog and configuration files.

---

## Opening Options

- Click **Options** button in the main window
- Or press `Ctrl+O`

---

## Available Settings

### Formatting Options

| Option | Description | Default |
|--------|-------------|---------|
| **Format DAX Code** | Send DAX to daxformatter.com API | ❌ Off |
| **Format Power Query** | Send M to powerqueryformatter.com API | ❌ Off |
| **Extract Images** | Save embedded images to subfolder | ❌ Off |
| **Generate TOC** | Auto-create table of contents | ❌ Off |
| **YAML Front Matter** | Add Hugo/Jekyll metadata header | ❌ Off |

### Output Location

| Option | Behavior |
|--------|----------|
| **Same as source** | Saves `.md` next to `.docx` |
| **Custom folder** | All output goes to selected folder |

---

## Theme Selection

7 built-in color themes with carefully curated palettes:

### VS Code Dark (Default)
| Role | Color | Description |
|------|-------|-------------|
| Background | `#1e1e1e` | Dark charcoal |
| Foreground | `#d4d4d4` | Light gray |
| Accent | `#007acc` | Blue |
| Accent Hover | `#0098ff` | Bright blue |
| Secondary BG | `#2d2d30` | Dark gray |
| Success | `#4caf50` | Green |
| Warning | `#ff9800` | Orange |
| Error | `#f44336` | Red |

### VS Code Light
| Role | Color | Description |
|------|-------|-------------|
| Background | `#ffffff` | White |
| Foreground | `#1e1e1e` | Dark charcoal |
| Accent | `#007acc` | Blue |
| Accent Hover | `#0098ff` | Bright blue |
| Secondary BG | `#f3f3f3` | Light gray |
| Success | `#388e3c` | Green |
| Warning | `#f57c00` | Orange |
| Error | `#d32f2f` | Red |

### Dracula
| Role | Color | Description |
|------|-------|-------------|
| Background | `#282a36` | Dark purple-gray |
| Foreground | `#f8f8f2` | Off-white |
| Accent | `#bd93f9` | Purple |
| Accent Hover | `#ff79c6` | Pink |
| Secondary BG | `#44475a` | Muted purple |
| Success | `#50fa7b` | Bright green |
| Warning | `#ffb86c` | Orange |
| Error | `#ff5555` | Red |

### Nord
| Role | Color | Description |
|------|-------|-------------|
| Background | `#2e3440` | Polar night |
| Foreground | `#eceff4` | Snow storm |
| Accent | `#88c0d0` | Frost blue |
| Accent Hover | `#8fbcbb` | Teal |
| Secondary BG | `#3b4252` | Dark gray-blue |
| Success | `#a3be8c` | Aurora green |
| Warning | `#ebcb8b` | Aurora yellow |
| Error | `#bf616a` | Aurora red |

### Solarized Dark
| Role | Color | Description |
|------|-------|-------------|
| Background | `#002b36` | Base03 (darkest) |
| Foreground | `#839496` | Base0 |
| Accent | `#268bd2` | Blue |
| Accent Hover | `#2aa198` | Cyan |
| Secondary BG | `#073642` | Base02 |
| Success | `#859900` | Green |
| Warning | `#b58900` | Yellow |
| Error | `#dc322f` | Red |

### Solarized Light
| Role | Color | Description |
|------|-------|-------------|
| Background | `#fdf6e3` | Base3 (lightest) |
| Foreground | `#657b83` | Base00 |
| Accent | `#268bd2` | Blue |
| Accent Hover | `#2aa198` | Cyan |
| Secondary BG | `#eee8d5` | Base2 |
| Success | `#859900` | Green |
| Warning | `#b58900` | Yellow |
| Error | `#dc322f` | Red |

### High Contrast
| Role | Color | Description |
|------|-------|-------------|
| Background | `#000000` | Pure black |
| Foreground | `#ffffff` | Pure white |
| Accent | `#00ff00` | Bright green |
| Accent Hover | `#ffff00` | Yellow |
| Secondary BG | `#1a1a1a` | Near-black |
| Success | `#00ff00` | Bright green |
| Warning | `#ffff00` | Yellow |
| Error | `#ff0000` | Bright red |

> 💡 **Tip:** Theme changes apply immediately. Press `Ctrl+T` to cycle through themes.
> 
> **Note:** GitHub renders color chips next to hex codes. In other viewers, reference the description column.

---

## Detection Patterns (Advanced)

Customize code detection via JSON configuration.

### Accessing Pattern Editor
1. Open **Options**
2. Click **Edit Patterns**
3. JSON editor opens

### Pattern Structure
```json
{
  "power_query": {
    "keywords": ["let", "in", "#\"", "Source ="],
    "patterns": ["^let\\s*$", "^in\\s*$"]
  },
  "dax": {
    "keywords": ["CALCULATE", "SUMX", "FILTER", ":="],
    "patterns": ["^\\s*\\w+\\s*:?="]
  }
}
```

### Adding Custom Patterns
Add keywords or regex patterns to detect additional code types.

> ⚠️ Invalid JSON will be rejected. Use a JSON validator if needed.

---

## Preferences File

Settings are saved to `markify_prefs.json` in the application directory.

### Stored Preferences
- Last used theme
- Output folder path
- Formatting toggles
- Window size/position
- Recent files list

### Reset to Defaults
Delete `markify_prefs.json` to reset all settings.

---

## YAML Front Matter Options

When enabled, adds metadata header:

```yaml
---
title: "Document Title"
date: 2026-01-06
slug: document-title
draft: false
---
```

### Variables Available
| Variable | Value |
|----------|-------|
| `title` | Extracted from document |
| `date` | Conversion date |
| `slug` | URL-friendly title |
| `draft` | Always `false` |

---

## Template System

Create custom output templates.

### Template Variables
| Variable | Replacement |
|----------|-------------|
| `{{filename}}` | Source filename |
| `{{date}}` | Current date |
| `{{time}}` | Current time |
| `{{content}}` | Converted Markdown |

### Example Template
```markdown
# {{filename}}

> Converted on {{date}} at {{time}}

{{content}}
```

See [[Export Formats]] for more template options.
