"""
Tests for the Update Checker (Feature #4).
"""
from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from core.update_checker import (
    check_for_updates_async,
    get_latest_release,
    is_newer_version,
    parse_version,
)


class TestUpdateChecker(unittest.TestCase):
    def test_parse_version(self):
        """Test parse_version with standard and non-standard version tags."""
        self.assertEqual(parse_version("1.2.0"), (1, 2, 0))
        self.assertEqual(parse_version("v1.2.0"), (1, 2, 0))
        self.assertEqual(parse_version("V2.4.15"), (2, 4, 15))
        self.assertEqual(parse_version("1.3.0-beta"), (1, 3, 0))
        self.assertEqual(parse_version("  v3.0.0-rc1  "), (3, 0, 0))
        self.assertEqual(parse_version("1"), (1,))
        self.assertEqual(parse_version("invalid"), (0,))

    def test_is_newer_version(self):
        """Test is_newer_version logic comparing various cases."""
        # Remote is newer
        self.assertTrue(is_newer_version("1.3.0", "1.2.0"))
        self.assertTrue(is_newer_version("v1.3.0", "1.2.0"))
        self.assertTrue(is_newer_version("1.2.1", "1.2.0"))
        self.assertTrue(is_newer_version("2.0.0", "1.9.9"))

        # Remote is not newer (same or older)
        self.assertFalse(is_newer_version("1.2.0", "1.2.0"))
        self.assertFalse(is_newer_version("1.1.0", "1.2.0"))
        self.assertFalse(is_newer_version("v1.2.0", "1.2.0"))

        # Invalid versions should handle exception gracefully and return False
        self.assertFalse(is_newer_version("invalid", "1.2.0"))

    @patch("urllib.request.urlopen")
    def test_get_latest_release_success(self, mock_urlopen):
        """Test get_latest_release when GitHub API returns 200 OK."""
        mock_response = MagicMock()
        mock_response.status = 200
        mock_response.read.return_value = b'{"tag_name": "v1.3.0"}'
        mock_urlopen.return_value.__enter__.return_value = mock_response

        tag = get_latest_release()
        self.assertEqual(tag, "v1.3.0")

    @patch("urllib.request.urlopen")
    def test_get_latest_release_failure(self, mock_urlopen):
        """Test get_latest_release when GitHub API fails (non-200 or exception)."""
        # Non-200 status
        mock_response = MagicMock()
        mock_response.status = 404
        mock_urlopen.return_value.__enter__.return_value = mock_response
        self.assertNil = self.assertIsNone(get_latest_release())

        # Exception raised during open (e.g. timeout / no network)
        mock_urlopen.side_effect = Exception("Connection timed out")
        self.assertIsNone(get_latest_release())

    @patch("core.update_checker.get_latest_release")
    def test_check_for_updates_async(self, mock_get_latest):
        """Test check_for_updates_async runs callback with remote version."""
        mock_get_latest.return_value = "v1.3.0"

        callback_called = MagicMock()
        results = []

        def callback(val):
            results.append(val)
            callback_called()

        import threading
        event = threading.Event()

        # We wrapper callback to set the event when called
        def on_callback(val):
            results.append(val)
            event.set()

        check_for_updates_async(on_callback)

        # Wait up to 2 seconds for background thread to execute
        event.wait(timeout=2)

        self.assertTrue(event.is_set())
        self.assertEqual(results, ["v1.3.0"])
