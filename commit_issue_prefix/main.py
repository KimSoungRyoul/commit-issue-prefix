"""Pre-commit hook to automatically add issue number prefix to commit messages."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


def get_current_branch() -> str | None:
    """Get the current Git branch name.

    Returns:
        Branch name or None if unable to retrieve.
    """
    try:
        result = subprocess.run(
            ["git", "symbolic-ref", "--short", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        # Detached HEAD state or not a git repository
        return None


def extract_issue_number(branch: str, regex_pattern: str) -> str | None:
    """Extract issue number from branch name.

    Args:
        branch: Branch name.
        regex_pattern: Regex pattern to find issue number.

    Returns:
        Issue number or None if not found.
    """
    matches = re.findall(regex_pattern, branch)
    if matches:
        return matches[0].upper()
    return None


def update_commit_message(filepath: Path, prefix: str) -> bool:
    """Add prefix to commit message file.

    Args:
        filepath: Path to commit message file.
        prefix: Prefix to add.

    Returns:
        True if message was updated, False otherwise.
    """
    content = filepath.read_text(encoding="utf-8")
    first_line = content.split("\n", maxsplit=1)[0].strip()

    # Don't add if prefix already exists
    if prefix in first_line:
        return False

    filepath.write_text(f"{prefix} {content}", encoding="utf-8")
    return True


def main() -> int:
    """Main entry point.

    Returns:
        Exit code (0: success).
    """
    parser = argparse.ArgumentParser(
        description="Automatically add issue number prefix to commit messages."
    )
    parser.add_argument(
        "commit_msg_filepath",
        type=Path,
        help="Path to commit message file.",
    )
    parser.add_argument(
        "-r",
        "--regex",
        default=r"#\d{1,5}",
        help="Regex pattern to extract issue number from branch (default: #\\d{1,5}).",
    )
    parser.add_argument(
        "-t",
        "--template",
        default="[{}]",
        help="Commit message template (default: [{}] -> [#111]).",
    )
    args = parser.parse_args()

    branch = get_current_branch()
    if not branch:
        # Exit silently if branch cannot be retrieved
        return 0

    issue_number = extract_issue_number(branch, args.regex)
    if not issue_number:
        # Exit silently if no issue number found
        return 0

    prefix = args.template.format(issue_number)
    update_commit_message(args.commit_msg_filepath, prefix)

    return 0


if __name__ == "__main__":
    sys.exit(main())
