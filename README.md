# commit-issue-prefix

[![CI](https://github.com/KimSoungRyoul/commit-issue-prefix/actions/workflows/ci.yaml/badge.svg)](https://github.com/KimSoungRyoul/commit-issue-prefix/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)

A `prepare-commit-msg` hook that prefixes your commit message with the issue number taken from
the branch name, and optionally with the change type.

One POSIX `sh` script. No Python, no Node: it runs wherever `git` runs (Linux, macOS, Windows via Git for Windows' `sh`), under
[prek](https://github.com/j178/prek) or [pre-commit](https://pre-commit.com/).

For people who always say "oh I forgot to prefix the commit message!"

## How it works

| Branch | Args | You type | Result |
|---|---|---|---|
| `feat/#111` | (defaults) | `Add new feature` | `[#111] Add new feature` |
| `feat/#111` | `--types feat,fix` | `Add new feature` | `[#111] feat: Add new feature` |
| `20266-fix-side-panel` | `--issue-regex '^[0-9]+' --template '[#{issue}]' --types feat,fix` | `Fix stacking` | `[#20266] fix: Fix stacking` |
| `feature/ABC-123-impl` | `--issue-regex '[A-Z]+-[0-9]+'` | `Add feature` | `[ABC-123] Add feature` |
| `feat/#111` | `--suffix` | `Add feature` | `Add feature [#111]` |

The hook only adds text. It never rejects a commit.

## Quick start

`.pre-commit-config.yaml`:

```yaml
default_install_hook_types: [pre-commit, prepare-commit-msg]
default_stages: [pre-commit]   # keeps your pre-commit hooks from running again at the prepare-commit-msg stage

repos:
  - repo: https://github.com/KimSoungRyoul/commit-issue-prefix
    rev: v1.3.0
    hooks:
      - id: commit-issue-prefix
```

Then install the hooks once per clone:

```bash
prek install          # or: pre-commit install
```

Both tools read `default_install_hook_types` and install the `prepare-commit-msg` shim for you.
Without that key you need `prek install --hook-type prepare-commit-msg` (same flag for pre-commit).

## Options

Pass them through `args:`.

| Option | Default | Meaning |
|---|---|---|
| `-r`, `--issue-regex <ERE>` | `#[0-9]{1,5}` | POSIX extended regex that finds the issue token in the branch name. The first match wins. `--regex` is accepted as an alias. |
| `-t`, `--template <text>` | `[{issue}]` | Issue part. `{issue}` is replaced by the token (upper-cased, so `abc-123` becomes `ABC-123`). `{}` still works as in v1. |
| `--types <a,b,...>` | (empty) | Enables type detection. The type is the branch segment before the first `/` (`fix/#111-x`) or the segment right after the issue token (`20266-fix-x`). Slug words are never taken as a type. |
| `--type-template <text>` | `{type}:` | Type part, written after the issue part when a type was found. `''` disables it. |
| `-s`, `--suffix [true\|false]` | `false` | Append the issue part to the end of the first line instead. The type part is not used in suffix mode. |
| `-q`, `--quiet` | | Do not print the notice for "issue found, but no type segment". |

### Examples

Issue number and type from a branch named `<issue>-<type>-<slug>` (the convention this hook was
written for, e.g. `20266-fix-side-panel-stacking`):

```yaml
      - id: commit-issue-prefix
        args:
          - '--issue-regex=^[0-9]+'
          - '--template=[#{issue}]'
          - '--types=feat,fix,refactor,chore,docs,test,perf,build,ci,revert,style'
```

JIRA keys, prefix in parentheses:

```yaml
        args: ['--issue-regex=[A-Z]+-[0-9]+', '--template=({issue})']
```

Issue as a suffix:

```yaml
        args: ['--suffix']
```

## When nothing is written

- The branch has no issue token, or HEAD is detached (rebase in progress).
- A merge or squash is in progress: `.git/MERGE_HEAD` or `.git/SQUASH_MSG` exists, or git/pre-commit
  reports the message source as `merge` or `squash`. Merge commits keep git's own message.
- The first line already contains the issue part, so `git commit --amend` is safe.
- With `--types`, a subject that already starts with a type (`fix(auth): …`, `feat!: …`) keeps it: only the
  issue part is added, so the type is never written twice. This lets a tool or the author choose the type
  per commit while the branch supplies the default.

When `--types` is set but the branch has no type segment, the issue part is still written and a
one-line notice goes to stderr (silence it with `--quiet`).

If the message file starts with a comment line (a commit template), the prefix gets its own first
line so you type the subject after it instead of inside the comment.

## Use as a plain git hook

The script also works without prek or pre-commit. git passes the message file, the source and the
commit SHA; extra options go in a two-line wrapper:

```bash
cat > .git/hooks/prepare-commit-msg <<'SH'
#!/bin/sh
exec /path/to/commit-issue-prefix.sh --types feat,fix "$@"
SH
chmod +x .git/hooks/prepare-commit-msg
```

## Changes in v1.3.0

- The hook is a single POSIX `sh` script (`language: script`). No Python runtime is needed any more;
  the Python package is gone from the repository. The hook id, the defaults and the v1 options
  (`--regex`, `{}`, `--suffix true`) are unchanged, so bumping `rev` is enough.
- New: `--types` and `--type-template` add the change type taken from the branch name.
  A subject that already starts with a type keeps it; only the issue part is added.
- New: merge and squash commits are left alone; a message that starts with a comment line gets the
  prefix on its own line; `--suffix` works as a bare flag.
- A missing message file is a usage error (exit 2) instead of being created.

## Development

```bash
shellcheck -s sh commit-issue-prefix.sh tests/test.sh
sh tests/test.sh        # also: bash tests/test.sh, dash tests/test.sh
```

## License

MIT License - see [LICENSE.md](LICENSE.md) for details.
