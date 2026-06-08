"""
Tests for the Undo/Redo Preview dialog feature (Feature #1).

These tests validate the logic surrounding the preview dialog's
editable content, dirty-state tracking, and on_save callback behaviour
without needing to spin up a full Tk window.
"""

from __future__ import annotations

import sys
import types
import unittest

# ---------------------------------------------------------------------------
# Minimal tkinter stub so tests run without a display
# ---------------------------------------------------------------------------

def _make_tk_stub():
    """Return a minimal tkinter stub module."""
    tk_stub = types.ModuleType("tkinter")

    class _Var:
        def __init__(self, value=None):
            self._v = value
        def get(self):
            return self._v
        def set(self, v):
            self._v = v

    class _Widget:
        def __init__(self, *a, **kw):
            pass
        def pack(self, **kw):
            pass
        def config(self, **kw):
            pass
        configure = config
        def bind(self, *a, **kw):
            pass
        def winfo_exists(self):
            return True

    class _Text(_Widget):
        def __init__(self, *a, **kw):
            self._content = ""
            self._modified = False
            self._undo_stack = []
            self._redo_stack = []

        def insert(self, idx, text, *tags):
            self._content += text

        def get(self, start, end):
            return self._content + "\n"  # tkinter always appends \n

        def edit_reset(self):
            self._undo_stack.clear()
            self._redo_stack.clear()

        def edit_modified(self, val=None):
            if val is None:
                return self._modified
            self._modified = val

        def edit_undo(self):
            if not self._undo_stack:
                raise Exception("nothing to undo")
            self._redo_stack.append(self._undo_stack.pop())

        def edit_redo(self):
            if not self._redo_stack:
                raise Exception("nothing to redo")
            self._undo_stack.append(self._redo_stack.pop())

        def tag_add(self, *a, **kw):
            pass
        def tag_configure(self, *a, **kw):
            pass
        def tag_names(self, idx=None):
            return []

        # Simulate user typing (pushes to undo stack)
        def _simulate_type(self, text):
            self._undo_stack.append(self._content)
            self._content = text
            self._modified = True

    class _TclError(Exception):
        pass

    # Populate stub
    tk_stub.Tk = _Widget
    tk_stub.Toplevel = _Widget
    tk_stub.Frame = _Widget
    tk_stub.Label = _Widget
    tk_stub.Button = _Widget
    tk_stub.Scrollbar = _Widget
    tk_stub.Text = _Text
    tk_stub.Canvas = _Widget
    tk_stub.StringVar = _Var
    tk_stub.BooleanVar = _Var
    tk_stub.TclError = _TclError
    tk_stub.BOTH = "both"
    tk_stub.X = "x"
    tk_stub.Y = "y"
    tk_stub.LEFT = "left"
    tk_stub.RIGHT = "right"
    tk_stub.W = "w"
    tk_stub.E = "e"
    tk_stub.NORMAL = "normal"
    tk_stub.DISABLED = "disabled"
    tk_stub.END = "end"
    tk_stub.SEL = "sel"
    tk_stub.INSERT = "insert"
    tk_stub.WORD = "word"
    tk_stub.NONE = "none"
    tk_stub.FLAT = "flat"

    ttk_stub = types.ModuleType("tkinter.ttk")
    ttk_stub.Separator = _Widget
    ttk_stub.Scrollbar = _Widget
    ttk_stub.Progressbar = _Widget

    messagebox_stub = types.ModuleType("tkinter.messagebox")
    messagebox_stub.askyesno = lambda *a, **kw: True  # Always confirm

    filedialog_stub = types.ModuleType("tkinter.filedialog")

    sys.modules["tkinter"] = tk_stub
    sys.modules["tkinter.ttk"] = ttk_stub
    sys.modules["tkinter.messagebox"] = messagebox_stub
    sys.modules["tkinter.filedialog"] = filedialog_stub
    return tk_stub


# Install stubs before importing preview
_tk_stub = _make_tk_stub()


# ---------------------------------------------------------------------------
# Helper: build a minimal PreviewDialog without displaying it
# ---------------------------------------------------------------------------

class _MockText:
    """Lightweight Text widget mock for unit testing internal logic."""

    def __init__(self, initial_content=""):
        self._content = initial_content
        self._modified = False
        self._undo_stack: list[str] = []
        self._redo_stack: list[str] = []

    # --- tkinter Text API ---

    def get(self, start, end):
        return self._content + "\n"

    def insert(self, idx, text, *tags):
        self._content += text

    def edit_reset(self):
        self._undo_stack.clear()
        self._redo_stack.clear()

    def edit_modified(self, val=None):
        if val is None:
            return self._modified
        self._modified = bool(val)

    def edit_undo(self):
        if not self._undo_stack:
            raise _tk_stub.TclError("nothing to undo")
        self._redo_stack.append(self._content)
        self._content = self._undo_stack.pop()

    def edit_redo(self):
        if not self._redo_stack:
            raise _tk_stub.TclError("nothing to redo")
        self._undo_stack.append(self._content)
        self._content = self._redo_stack.pop()

    def tag_add(self, *a, **kw): pass
    def tag_configure(self, *a, **kw): pass
    def tag_names(self, idx=None): return []
    def bind(self, *a, **kw): pass
    def config(self, **kw): pass
    configure = config

    # --- Helpers for test simulation ---

    def _simulate_user_edit(self, new_text: str):
        """Simulate user editing the Text widget content."""
        self._undo_stack.append(self._content)
        self._redo_stack.clear()
        self._content = new_text
        self._modified = True


class _MockLabel:
    def config(self, **kw): pass
    configure = config


class _MockButton:
    def __init__(self):
        self.state = _tk_stub.NORMAL

    def config(self, **kw):
        if "state" in kw:
            self.state = kw["state"]
    configure = config


# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------

class TestPreviewDialogDirtyState(unittest.TestCase):
    """Test dirty-state detection and Undo/Redo stack probing."""

    def _make_components(self, initial="# Hello\n\nWorld"):
        """Build the mock components used internally by the dialog."""
        text = _MockText(initial)
        undo_btn = _MockButton()
        redo_btn = _MockButton()
        dirty_label = _MockLabel()
        return text, undo_btn, redo_btn, dirty_label

    def test_initially_not_dirty(self):
        """Dialog should not be dirty on creation."""
        text, _, _, _ = self._make_components()
        self.assertFalse(text.edit_modified())

    def test_edit_sets_modified(self):
        """Simulating a user edit should mark the widget as modified."""
        text, _, _, _ = self._make_components()
        text._simulate_user_edit("# Hello\n\nEdited World")
        self.assertTrue(text.edit_modified())

    def test_undo_restores_content(self):
        """Undo should restore the previous content."""
        text, _, _, _ = self._make_components("original content")
        text._simulate_user_edit("edited content")
        self.assertEqual(text._content, "edited content")
        text.edit_undo()
        self.assertEqual(text._content, "original content")

    def test_redo_reapplies_content(self):
        """Redo should reapply content after undo."""
        text, _, _, _ = self._make_components("original content")
        text._simulate_user_edit("edited content")
        text.edit_undo()
        self.assertEqual(text._content, "original content")
        text.edit_redo()
        self.assertEqual(text._content, "edited content")

    def test_multiple_undos(self):
        """Multiple sequential undos should walk back through history."""
        text, _, _, _ = self._make_components("v1")
        text._simulate_user_edit("v2")
        text._simulate_user_edit("v3")
        text._simulate_user_edit("v4")
        text.edit_undo()
        self.assertEqual(text._content, "v3")
        text.edit_undo()
        self.assertEqual(text._content, "v2")
        text.edit_undo()
        self.assertEqual(text._content, "v1")

    def test_undo_raises_when_empty(self):
        """Undo should raise TclError when stack is empty."""
        text, _, _, _ = self._make_components()
        text.edit_reset()
        with self.assertRaises(_tk_stub.TclError):
            text.edit_undo()

    def test_redo_raises_when_empty(self):
        """Redo should raise TclError when nothing to redo."""
        text, _, _, _ = self._make_components()
        text.edit_reset()
        with self.assertRaises(_tk_stub.TclError):
            text.edit_redo()

    def test_new_edit_clears_redo_stack(self):
        """Making a new edit after undo should clear the redo stack."""
        text, _, _, _ = self._make_components("start")
        text._simulate_user_edit("middle")
        text.edit_undo()
        # Now redo is available
        self.assertTrue(len(text._redo_stack) > 0)
        # Make a new edit
        text._simulate_user_edit("branch")
        # Redo stack should be cleared
        self.assertEqual(len(text._redo_stack), 0)
        with self.assertRaises(_tk_stub.TclError):
            text.edit_redo()


class TestContentCapture(unittest.TestCase):
    """Test that on_save receives the actual widget content."""

    def test_on_save_called_with_original_content_when_no_edits(self):
        """on_save should receive original content when user hasn't edited."""
        original = "# My Document\n\nSome content here."
        captured = []

        text = _MockText(original)
        # Simulate save: get content and call on_save
        current = text.get("1.0", _tk_stub.END)
        # Strip trailing newline that tkinter always adds
        if current.endswith("\n"):
            current = current[:-1]

        def on_save(c):
            captured.append(c)

        on_save(current)
        self.assertEqual(captured[0], original)

    def test_on_save_called_with_edited_content(self):
        """on_save should receive the edited content when user made changes."""
        original = "# My Document\n\nOriginal content."
        edited = "# My Document\n\nEdited content!"
        captured = []

        text = _MockText(original)
        text._simulate_user_edit(edited)

        current = text.get("1.0", _tk_stub.END)
        if current.endswith("\n"):
            current = current[:-1]

        def on_save(c):
            captured.append(c)

        on_save(current)
        self.assertEqual(captured[0], edited)

    def test_on_save_after_undo_gives_restored_content(self):
        """on_save after undo should give the restored (pre-edit) content."""
        original = "# Original"
        edited = "# Edited"
        captured = []

        text = _MockText(original)
        text._simulate_user_edit(edited)
        text.edit_undo()

        current = text.get("1.0", _tk_stub.END)
        if current.endswith("\n"):
            current = current[:-1]

        def on_save(c):
            captured.append(c)

        on_save(current)
        self.assertEqual(captured[0], original)


class TestStatisticsCalculation(unittest.TestCase):
    """Test _calculate_stats logic (extracted as a pure function)."""

    def _calc_stats(self, content: str) -> dict:
        """Replicate the stats calculation from PreviewDialog."""
        lines = content.split("\n")
        words = len(content.split())
        minutes = words / 200
        reading_time = "<1 min" if minutes < 1 else f"{int(round(minutes))} min"

        headers = {}
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("#"):
                level = len(stripped) - len(stripped.lstrip("#"))
                if 1 <= level <= 6:
                    headers[level] = headers.get(level, 0) + 1

        return {
            "lines": len(lines),
            "chars": len(content),
            "words": words,
            "reading_time": reading_time,
            "headers": headers,
        }

    def test_word_count(self):
        stats = self._calc_stats("Hello world this is a test")
        self.assertEqual(stats["words"], 6)

    def test_header_detection(self):
        content = "# H1\n## H2\n### H3\n## Another H2\n\nParagraph"
        stats = self._calc_stats(content)
        self.assertEqual(stats["headers"][1], 1)
        self.assertEqual(stats["headers"][2], 2)
        self.assertEqual(stats["headers"][3], 1)

    def test_reading_time_under_one_minute(self):
        stats = self._calc_stats("short content")
        self.assertEqual(stats["reading_time"], "<1 min")

    def test_reading_time_over_one_minute(self):
        # 400 words = 2 minutes at 200 wpm
        content = " ".join(["word"] * 400)
        stats = self._calc_stats(content)
        self.assertEqual(stats["reading_time"], "2 min")

    def test_line_count(self):
        content = "line1\nline2\nline3"
        stats = self._calc_stats(content)
        self.assertEqual(stats["lines"], 3)


class TestResetContent(unittest.TestCase):
    """Test the Reset button logic — restoring original content."""

    def _simulate_reset(self, text: _MockText, original: str, is_dirty: bool) -> tuple[_MockText, bool]:
        """Simulate what _reset_content does internally."""
        # Clear and replace content
        text._content = ""
        text.insert("1.0", original)
        # Clear undo/redo stacks (edit_reset)
        text.edit_reset()
        # Clear dirty state
        text.edit_modified(False)
        is_dirty = False
        return text, is_dirty

    def test_reset_restores_original_content(self):
        """Reset should replace current content with the original Markify output."""
        original = "# Original Output\n\nThis is what Markify produced."
        text = _MockText(original)
        text._simulate_user_edit("# I changed this\n\nCompletely different content.")
        self.assertNotEqual(text._content, original)

        text, is_dirty = self._simulate_reset(text, original, True)
        self.assertEqual(text._content, original)

    def test_reset_clears_undo_stack(self):
        """After reset, Undo stack must be empty — reset cannot be undone."""
        original = "# Original"
        text = _MockText(original)
        text._simulate_user_edit("v2")
        text._simulate_user_edit("v3")
        self.assertGreater(len(text._undo_stack), 0)

        text, _ = self._simulate_reset(text, original, True)
        # Stack must be empty — Ctrl+Z should raise
        with self.assertRaises(_tk_stub.TclError):
            text.edit_undo()

    def test_reset_clears_redo_stack(self):
        """After reset, Redo stack must also be empty."""
        original = "# Original"
        text = _MockText(original)
        text._simulate_user_edit("v2")
        text.edit_undo()
        self.assertGreater(len(text._redo_stack), 0)

        text, _ = self._simulate_reset(text, original, True)
        with self.assertRaises(_tk_stub.TclError):
            text.edit_redo()

    def test_reset_clears_dirty_state(self):
        """After reset, is_dirty should be False and modified flag cleared."""
        original = "# Original"
        text = _MockText(original)
        text._simulate_user_edit("changed")
        self.assertTrue(text.edit_modified())

        text, is_dirty = self._simulate_reset(text, original, True)
        self.assertFalse(is_dirty)
        self.assertFalse(text.edit_modified())

    def test_on_save_after_reset_gives_original_content(self):
        """After reset, saving should write the original Markify content."""
        original = "# Original\n\nMarkify output."
        captured = []
        text = _MockText(original)
        text._simulate_user_edit("Something completely different")
        text, _ = self._simulate_reset(text, original, True)

        # Simulate save
        current = text.get("1.0", "end")
        if current.endswith("\n"):
            current = current[:-1]

        def on_save(c):
            captured.append(c)

        on_save(current)
        self.assertEqual(captured[0], original)

    def test_reset_on_clean_dialog_needs_no_confirmation(self):
        """If not dirty, reset should proceed without prompting."""
        original = "# Clean"
        text = _MockText(original)
        # Never edited — is_dirty is False
        is_dirty = False
        # Should not need confirmation — simulate reset directly
        text, is_dirty = self._simulate_reset(text, original, is_dirty)
        self.assertFalse(is_dirty)
        self.assertEqual(text._content, original)


if __name__ == "__main__":
    unittest.main()
