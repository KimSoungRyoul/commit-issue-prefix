# add-github-issue-prefix

[![PyPI version](https://badge.fury.io/py/add-github-issue-prefix.svg)](https://badge.fury.io/py/add-github-issue-prefix)
[![Python](https://img.shields.io/pypi/pyversions/add-github-issue-prefix.svg)](https://pypi.org/project/add-github-issue-prefix/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)

A pre-commit hook that automatically adds GitHub issue number prefix to your commit messages based on branch name.

For people who always say "oh I forgot to prefix the commit message!"

## How It Works

The hook extracts the issue number from your branch name and prepends it to your commit message.

| Branch Name | Commit Message | Result |
|-------------|----------------|--------|
| `feat/#111` | `Add new feature` | `[#111] Add new feature` |
| `feature/#111` | `Add new feature` | `[#111] Add new feature` |
| `fix/#111-hello-branch` | `Fix bug` | `[#111] Fix bug` |
| `chore/#111-run-autoflake` | `Run linter` | `[#111] Run linter` |

## Quick Start

### Prerequisites

- Python 3.9+
- [pre-commit](https://pre-commit.com/)

```bash
# Install pre-commit (macOS)
brew install pre-commit

# Or using pip
pip install pre-commit
```

### Installation

1. Create `.pre-commit-config.yaml` in your repository root:

```yaml
repos:
  - repo: https://github.com/KimSoungRyoul/add-github-issue-prefix
    rev: v1.0.4
    hooks:
      - id: add-github-issue-prefix
```

2. Install the hook:

```bash
pre-commit install --hook-type prepare-commit-msg
```

3. Done! Now when you commit, the hook will automatically add the issue prefix.

## Configuration

You can customize the template and regex pattern:

```yaml
repos:
  - repo: https://github.com/KimSoungRyoul/add-github-issue-prefix
    rev: v1.0.4
    hooks:
      - id: add-github-issue-prefix
        args:
          - --template=[{}]      # default: [{}]
          - --regex=#\d{1,5}     # default: #\d{1,5}
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--template` | `[{}]` | Template for the prefix. `{}` is replaced with the issue number. |
| `--regex` | `#\d{1,5}` | Regex pattern to extract issue number from branch name. |

### Examples

**JIRA-style issue numbers:**

```yaml
args:
  - --template=[{}]
  - --regex=[A-Z]+-\d+
```

This will match branches like `feature/ABC-123-description` and create prefix `[ABC-123]`.

**Different prefix format:**

```yaml
args:
  - --template=({})
  - --regex=#\d{1,5}
```

This will create prefix `(#123)` instead of `[#123]`.

## Development

```bash
# Clone the repository
git clone https://github.com/KimSoungRyoul/add-github-issue-prefix.git
cd add-github-issue-prefix

# Install dependencies
uv sync --extra dev

# Run tests
uv run pytest

# Run linter
uv run ruff check .
```

## License

MIT License - see [LICENSE.md](LICENSE.md) for details.
