"""Tests for commit_issue_prefix.main module."""

from pathlib import Path

import pytest

from commit_issue_prefix.main import extract_issue_number, update_commit_message


class TestExtractIssueNumber:
    """Tests for extract_issue_number function."""

    @pytest.mark.parametrize(
        ("branch", "expected"),
        [
            ("feat/#111", "#111"),
            ("feature/#111", "#111"),
            ("fix/#111-hello-branch", "#111"),
            ("chore/#111-run-autoflake", "#111"),
            ("feature/#12345-some-feature", "#12345"),
            ("bugfix/#1", "#1"),
        ],
    )
    def test_extract_issue_number_default_pattern(self, branch: str, expected: str) -> None:
        """Test extracting issue number with default pattern."""
        result = extract_issue_number(branch, r"#\d{1,5}")
        assert result == expected

    @pytest.mark.parametrize(
        "branch",
        [
            "main",
            "develop",
            "feature/no-issue",
            "release/v1.0.0",
        ],
    )
    def test_extract_issue_number_no_match(self, branch: str) -> None:
        """Test branches without issue numbers."""
        result = extract_issue_number(branch, r"#\d{1,5}")
        assert result is None

    def test_extract_issue_number_custom_pattern(self) -> None:
        """Test with custom regex pattern (JIRA style)."""
        result = extract_issue_number("feature/ABC-123-some-feature", r"[A-Z]+-\d+")
        assert result == "ABC-123"


class TestUpdateCommitMessage:
    """Tests for update_commit_message function."""

    def test_add_prefix(self, tmp_path: Path) -> None:
        """Test adding prefix to commit message."""
        msg_file = tmp_path / "COMMIT_EDITMSG"
        msg_file.write_text("Initial commit\n\nSome description")

        result = update_commit_message(msg_file, "[#123]")

        assert result is True
        assert msg_file.read_text() == "[#123] Initial commit\n\nSome description"

    def test_skip_existing_prefix(self, tmp_path: Path) -> None:
        """Test skipping if prefix already exists."""
        msg_file = tmp_path / "COMMIT_EDITMSG"
        msg_file.write_text("[#123] Initial commit\n\nSome description")

        result = update_commit_message(msg_file, "[#123]")

        assert result is False
        assert msg_file.read_text() == "[#123] Initial commit\n\nSome description"

    def test_empty_message(self, tmp_path: Path) -> None:
        """Test with empty commit message."""
        msg_file = tmp_path / "COMMIT_EDITMSG"
        msg_file.write_text("")

        result = update_commit_message(msg_file, "[#123]")

        assert result is True
        assert msg_file.read_text() == "[#123] "

    def test_add_suffix(self, tmp_path: Path) -> None:
        """Test adding suffix to commit message."""
        msg_file = tmp_path / "COMMIT_EDITMSG"
        msg_file.write_text("Add new feature\n\nSome description")

        result = update_commit_message(msg_file, "[#111]", suffix=True)

        assert result is True
        assert msg_file.read_text() == "Add new feature [#111]\n\nSome description"

    def test_add_suffix_single_line(self, tmp_path: Path) -> None:
        """Test adding suffix to single line commit message."""
        msg_file = tmp_path / "COMMIT_EDITMSG"
        msg_file.write_text("Fix bug")

        result = update_commit_message(msg_file, "[#456]", suffix=True)

        assert result is True
        assert msg_file.read_text() == "Fix bug [#456]"

    def test_skip_existing_suffix(self, tmp_path: Path) -> None:
        """Test skipping if suffix already exists."""
        msg_file = tmp_path / "COMMIT_EDITMSG"
        msg_file.write_text("Add new feature [#111]\n\nSome description")

        result = update_commit_message(msg_file, "[#111]", suffix=True)

        assert result is False
        assert msg_file.read_text() == "Add new feature [#111]\n\nSome description"

    def test_suffix_with_trailing_whitespace(self, tmp_path: Path) -> None:
        """Test suffix handling with trailing whitespace in first line."""
        msg_file = tmp_path / "COMMIT_EDITMSG"
        msg_file.write_text("Add feature   \n\nDescription")

        result = update_commit_message(msg_file, "[#789]", suffix=True)

        assert result is True
        assert msg_file.read_text() == "Add feature [#789]\n\nDescription"

    def test_add_suffix_single_line_with_trailing_newline(self, tmp_path: Path) -> None:
        """Test adding suffix to single line with trailing newline."""
        msg_file = tmp_path / "COMMIT_EDITMSG"
        msg_file.write_text("Fix bug\n")

        result = update_commit_message(msg_file, "[#456]", suffix=True)

        assert result is True
        assert msg_file.read_text() == "Fix bug [#456]\n"
