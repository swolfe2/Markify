"""
Tests for the Git Integration features:
- is_git_repository check
- commit_file operation
"""
import os
import sys
from unittest import mock

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from core.git_integration import commit_file, is_git_repository


class TestGitIntegration:
    """Tests for Git integration utilities."""

    @mock.patch("os.path.isdir")
    def test_is_git_repository_not_dir(self, mock_isdir):
        """Test is_git_repository returns False if directory does not exist."""
        mock_isdir.return_value = False
        assert is_git_repository("/fake/path/file.md") is False

    @mock.patch("os.path.isdir")
    @mock.patch("subprocess.run")
    def test_is_git_repository_true(self, mock_run, mock_isdir):
        """Test is_git_repository returns True when git command returns true."""
        mock_isdir.return_value = True
        mock_run.return_value = mock.Mock(returncode=0, stdout="true\n")
        assert is_git_repository("/fake/path/file.md") is True
        mock_run.assert_called_once()

    @mock.patch("os.path.isdir")
    @mock.patch("subprocess.run")
    def test_is_git_repository_false(self, mock_run, mock_isdir):
        """Test is_git_repository returns False when git command returns false."""
        mock_isdir.return_value = True
        mock_run.return_value = mock.Mock(returncode=0, stdout="false\n")
        assert is_git_repository("/fake/path/file.md") is False

    @mock.patch("os.path.isdir")
    @mock.patch("subprocess.run")
    def test_is_git_repository_error(self, mock_run, mock_isdir):
        """Test is_git_repository returns False on command error."""
        mock_isdir.return_value = True
        mock_run.return_value = mock.Mock(returncode=1, stdout="", stderr="error")
        assert is_git_repository("/fake/path/file.md") is False

    @mock.patch("os.path.isdir")
    @mock.patch("subprocess.run")
    def test_is_git_repository_no_git(self, mock_run, mock_isdir):
        """Test is_git_repository returns False if git is not installed."""
        mock_isdir.return_value = True
        mock_run.side_effect = FileNotFoundError()
        assert is_git_repository("/fake/path/file.md") is False

    @mock.patch("subprocess.run")
    def test_commit_file_success(self, mock_run):
        """Test commit_file stages and commits successfully."""
        # Mock git add returning 0, and git commit returning 0
        mock_run.side_effect = [
            mock.Mock(returncode=0, stdout="", stderr=""),
            mock.Mock(returncode=0, stdout="[main a1b2c3d] Markify commit\n 1 file changed", stderr="")
        ]

        success, msg = commit_file("/repo/file.md", "source.docx")
        assert success is True
        assert "[main a1b2c3d] Markify commit" in msg
        assert mock_run.call_count == 2

    @mock.patch("subprocess.run")
    def test_commit_file_add_fails(self, mock_run):
        """Test commit_file returns error message if git add fails."""
        mock_run.return_value = mock.Mock(returncode=1, stdout="", stderr="Permission denied")

        success, msg = commit_file("/repo/file.md", "source.docx")
        assert success is False
        assert "Git add failed" in msg

    @mock.patch("subprocess.run")
    def test_commit_file_commit_fails(self, mock_run):
        """Test commit_file returns error message if git commit fails."""
        mock_run.side_effect = [
            mock.Mock(returncode=0, stdout="", stderr=""),
            mock.Mock(returncode=1, stdout="", stderr="Commit hook failed")
        ]

        success, msg = commit_file("/repo/file.md", "source.docx")
        assert success is False
        assert "Git commit failed" in msg

    @mock.patch("subprocess.run")
    def test_commit_file_no_changes(self, mock_run):
        """Test commit_file handles no changes to commit gracefully."""
        mock_run.side_effect = [
            mock.Mock(returncode=0, stdout="", stderr=""),
            mock.Mock(returncode=1, stdout="nothing to commit, working tree clean", stderr="")
        ]

        success, msg = commit_file("/repo/file.md", "source.docx")
        assert success is True
        assert "No changes to commit" in msg

    @mock.patch("subprocess.run")
    def test_commit_file_no_git_installed(self, mock_run):
        """Test commit_file returns cleanly if git executable is missing."""
        mock_run.side_effect = FileNotFoundError()

        success, msg = commit_file("/repo/file.md", "source.docx")
        assert success is False
        assert "Git executable not found" in msg
