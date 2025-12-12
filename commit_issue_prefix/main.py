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


def update_commit_message(filepath: Path, prefix: str, suffix: bool = False) -> bool:
    """Add prefix or suffix to commit message file.

    Args:
        filepath: Path to commit message file.
        prefix: Prefix/suffix to add.
        suffix: If True, add as suffix instead of prefix.

    Returns:
        True if message was updated, False otherwise.
    """
    content = filepath.read_text(encoding="utf-8")
    first_line = content.split("\n", maxsplit=1)[0].strip()

    # Don't add if prefix already exists
    if prefix in first_line:
        return False

    if suffix:
        # Add as suffix: "message [#123]"
        lines = content.split("\n", maxsplit=1)
        first_line = lines[0].rstrip()
        new_content = f"{first_line} {prefix}"
        if len(lines) > 1:
            # Preserve the newline and any content after it (even if empty)
            new_content += "\n" + lines[1]
        filepath.write_text(new_content, encoding="utf-8")
    else:
        # Add as prefix: "[#123] message"
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
    parser.add_argument(
        "-s",
        "--suffix",
        type=lambda x: x.lower() == "true",
        default=False,
        help="Add issue number as suffix instead of prefix (default: false).",
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
    update_commit_message(args.commit_msg_filepath, prefix, args.suffix)

    return 0


if __name__ == "__main__":
    sys.exit(main())
