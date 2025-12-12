# commit-issue-prefix

[![CI](https://github.com/KimSoungRyoul/add-github-issue-prefix/actions/workflows/ci.yaml/badge.svg)](https://github.com/KimSoungRyoul/add-github-issue-prefix/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)

A pre-commit hook that automatically adds issue number prefix to your commit messages based on branch name.

Supports **GitHub**, **JIRA**, **GitLab**, **Linear**, and any custom issue pattern.

For people who always say "oh I forgot to prefix the commit message!"

## How It Works

The hook extracts the issue number from your branch name and prepends it to your commit message.

| Branch Name | Commit Message | Result (default) | Result (--suffix=true) |
|-------------|----------------|------------------|------------------------|
| `feat/#111` | `Add new feature` | `[#111] Add new feature` | `Add new feature [#111]` |
| `feature/ABC-123-impl` | `Add feature` | `[ABC-123] Add feature` | `Add feature [ABC-123]` |
| `fix/#111-hello-branch` | `Fix bug` | `[#111] Fix bug` | `Fix bug [#111]` |
| `chore/PROJ-456-cleanup` | `Cleanup` | `[PROJ-456] Cleanup` | `Cleanup [PROJ-456]` |

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
  - repo: https://github.com/KimSoungRyoul/commit-issue-prefix
    rev: v1.2.0
    hooks:
      - id: commit-issue-prefix
```

2. Install the hook:

```bash
pre-commit install --hook-type prepare-commit-msg
```

3. Done! Now when you commit, the hook will automatically add the issue prefix.

## Configuration

You can customize the template, regex pattern, and position:

```yaml
repos:
  - repo: https://github.com/KimSoungRyoul/commit-issue-prefix
    rev: v1.2.0
    hooks:
      - id: commit-issue-prefix
        args:
          - --template=[{}]      # default: [{}]
          - --regex=#\d{1,5}     # default: #\d{1,5}
          - --suffix=true        # default: false
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--template` | `[{}]` | Template for the prefix. `{}` is replaced with the issue number. |
| `--regex` | `#\d{1,5}` | Regex pattern to extract issue number from branch name. |
| `--suffix` | `false` | If `true`, adds issue number as suffix instead of prefix. |

### Examples

**GitHub-style issue numbers (default):**

```yaml
args:
  - --template=[{}]
  - --regex=#\d{1,5}
```

This will match branches like `feature/#123-description` and create prefix `[#123]`.

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

**Issue number as suffix:**

```yaml
args:
  - --template=[{}]
  - --regex=#\d{1,5}
  - --suffix=true
```

This will add the issue number at the end: `Add new feature [#123]`.

## Development

```bash
# Clone the repository
git clone https://github.com/KimSoungRyoul/commit-issue-prefix.git
cd commit-issue-prefix

# Install dependencies
uv sync --extra dev

# Run tests
uv run pytest

# Run linter
uv run ruff check .
```

## License

MIT License - see [LICENSE.md](LICENSE.md) for details.
