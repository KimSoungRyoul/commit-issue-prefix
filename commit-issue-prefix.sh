#!/bin/sh
# commit-issue-prefix — prepare-commit-msg hook (POSIX sh, no runtime dependency).
#
# Reads the issue token (and, when --types is given, the type) from the current branch name and
# writes them in front of the commit message. It never rejects a commit: every path except a usage
# error exits 0.
#
#   branch   20266-fix-side-panel-stacking
#   args     --issue-regex '^[0-9]+' --template '[#{issue}]' --types feat,fix,chore
#   result   [#20266] fix: <your subject>
#
# Usage:
#   commit-issue-prefix.sh [options] <commit-msg-file> [<source> [<sha>]]
#
# pre-commit and prek pass only <commit-msg-file>; git itself passes <source> and <sha> as well
# when the script is installed directly as .git/hooks/prepare-commit-msg.
#
# Options:
#   -r, --issue-regex <ERE>    ERE that finds the issue token in the branch name.
#                              Default: '#[0-9]{1,5}'. (--regex is accepted as a v1 alias.)
#   -t, --template <text>      Issue part; {issue} is replaced by the token. Default: '[{issue}]'.
#                              The v1 placeholder '{}' is still accepted.
#       --types <a,b,...>      Comma-separated type list. Enables type detection: the type is the
#                              branch segment before the first '/' or the segment right after the
#                              issue token. Default: empty (no type part, same output as v1).
#       --type-template <text> Type part, written after the issue part when a type was found.
#                              {type} is replaced by the type. Default: '{type}:'. '' disables it.
#   -s, --suffix [true|false]  Append the issue part to the end of the first line instead.
#                              The type part is not used in suffix mode. Default: false.
#   -q, --quiet                Do not print the notice for "issue found, but no type segment".
#   -h, --help                 Show this text.
#
# Nothing is written when: the branch has no issue token, HEAD is detached, a merge or squash is
# in progress (.git/MERGE_HEAD or .git/SQUASH_MSG exists, or <source> is merge/squash), or the
# first line already contains the issue part (so --amend is safe).
set -eu

usage() {
  sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit "${1:-2}"
}

# Literal (non-regex) replacement of every occurrence of $2 in $1 with $3.
replace_literal() {
  s=$1
  out=''
  while :; do
    case $s in
      *"$2"*)
        out="$out${s%%"$2"*}$3"
        s=${s#*"$2"}
        ;;
      *)
        out="$out$s"
        break
        ;;
    esac
  done
  printf '%s' "$out"
}

to_bool() {
  case $(printf '%s' "$1" | tr '[:upper:]' '[:lower:]') in
    true | 1 | yes | on) printf 'true' ;;
    false | 0 | no | off) printf 'false' ;;
    *)
      printf 'commit-issue-prefix: expected true or false, got %s\n' "$1" >&2
      exit 2
      ;;
  esac
}

issue_regex='#[0-9]{1,5}'
template='[{issue}]'
types=''
type_template='{type}:'
suffix=false
quiet=false

while [ $# -gt 0 ]; do
  case $1 in
    -r | --issue-regex | --regex)
      [ $# -ge 2 ] || usage
      issue_regex=$2
      shift 2
      ;;
    --issue-regex=* | --regex=*)
      issue_regex=${1#*=}
      shift
      ;;
    -t | --template)
      [ $# -ge 2 ] || usage
      template=$2
      shift 2
      ;;
    --template=*)
      template=${1#*=}
      shift
      ;;
    --types)
      [ $# -ge 2 ] || usage
      types=$2
      shift 2
      ;;
    --types=*)
      types=${1#*=}
      shift
      ;;
    --type-template)
      [ $# -ge 2 ] || usage
      type_template=$2
      shift 2
      ;;
    --type-template=*)
      type_template=${1#*=}
      shift
      ;;
    -s | --suffix)
      # v1 required a value (`--suffix true`); v2 also accepts the bare flag.
      if [ $# -ge 2 ]; then
        case $(printf '%s' "$2" | tr '[:upper:]' '[:lower:]') in
          true | false | 1 | 0 | yes | no | on | off)
            suffix=$(to_bool "$2")
            shift 2
            continue
            ;;
        esac
      fi
      suffix=true
      shift
      ;;
    --suffix=*)
      suffix=$(to_bool "${1#*=}")
      shift
      ;;
    -q | --quiet)
      quiet=true
      shift
      ;;
    -h | --help)
      usage 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      printf 'commit-issue-prefix: unknown option %s\n' "$1" >&2
      usage
      ;;
    *)
      break
      ;;
  esac
done

[ $# -ge 1 ] || usage
msg_file=$1
if [ ! -f "$msg_file" ]; then
  printf 'commit-issue-prefix: %s is not a file\n' "$msg_file" >&2
  exit 2
fi
source=${2:-${PRE_COMMIT_COMMIT_MSG_SOURCE:-}}

case $source in
  merge | squash) exit 0 ;;
esac

git_dir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
[ -e "$git_dir/MERGE_HEAD" ] && exit 0
[ -e "$git_dir/SQUASH_MSG" ] && exit 0

branch=$(git symbolic-ref --short -q HEAD 2>/dev/null) || exit 0
[ -n "$branch" ] || exit 0

issue_raw=$(printf '%s\n' "$branch" | grep -oE -- "$issue_regex" | head -n 1) || true
[ -n "$issue_raw" ] || exit 0
issue=$(printf '%s' "$issue_raw" | tr '[:lower:]' '[:upper:]')

type=''
if [ -n "$types" ]; then
  first_segment=''
  case $branch in
    */*) first_segment=${branch%%/*} ;;
  esac
  after_issue=${branch#*"$issue_raw"}
  segment_after_issue=''
  case $after_issue in
    -* | /*)
      after_issue=${after_issue#?}
      segment_after_issue=${after_issue%%[-/]*}
      ;;
  esac
  for candidate in "$first_segment" "$segment_after_issue"; do
    [ -n "$candidate" ] || continue
    case ",$types," in
      *",$candidate,"*)
        type=$candidate
        break
        ;;
    esac
  done
fi

issue_part=$(replace_literal "$template" '{issue}' "$issue")
issue_part=$(replace_literal "$issue_part" '{}' "$issue")
type_part=''
if [ -n "$type" ] && [ -n "$type_template" ]; then
  type_part=$(replace_literal "$type_template" '{type}' "$type")
fi

first_line=''
[ ! -s "$msg_file" ] || first_line=$(head -n 1 "$msg_file")
case $first_line in
  *"$issue_part"*) exit 0 ;;
esac

# The subject already carries a type ("fix(auth): ..." written by the author or a tool): keep it
# and add the issue part only, so the type is never written twice.
subject_has_type=false
if [ -n "$types" ]; then
  types_alt=$(printf '%s' "$types" | tr ',' '|')
  if printf '%s\n' "$first_line" | grep -qE -- "^($types_alt)(\([^)]*\))?!?:"; then
    subject_has_type=true
    type_part=''
  fi
fi

if [ -n "$types" ] && [ -z "$type" ] && [ "$subject_has_type" = false ] && [ "$quiet" = false ] && [ "$suffix" = false ]; then
  printf "commit-issue-prefix: branch '%s' has an issue token but no type segment (types: %s); writing '%s' only\n" \
    "$branch" "$types" "$issue_part" >&2
fi

if [ "$suffix" = true ]; then
  prefix=''
else
  prefix=$issue_part
  [ -z "$type_part" ] || prefix="$prefix $type_part"
fi

if [ ! -s "$msg_file" ]; then
  if [ "$suffix" = true ]; then
    printf '%s\n' "$issue_part" > "$msg_file"
  else
    printf '%s \n' "$prefix" > "$msg_file"
  fi
  exit 0
fi

tmp="$msg_file.commit-issue-prefix.tmp"
trap 'rm -f "$tmp"' EXIT

# Rewrite the first line in plain sh (no awk: on Git for Windows awk drops the CR of CRLF input).
# `read` takes the first line, `cat` copies the rest byte for byte.
cr_char=$(printf '\r')
tab_char=$(printf '\t')
{
  if IFS= read -r line || [ -n "$line" ]; then
    cr=''
    case $line in
      *"$cr_char") cr=$cr_char; line=${line%"$cr_char"} ;;
    esac
    if [ "$suffix" = true ]; then
      while :; do
        case $line in
          *' ' | *"$tab_char") line=${line%?} ;;
          *) break ;;
        esac
      done
      if [ -z "$line" ]; then line=$issue_part; else line="$line $issue_part"; fi
    else
      case $line in
        '#'*)
          # The file starts with a comment (commit template): give the prefix its own first line so
          # the author types the subject after it instead of inside the comment.
          printf '%s %s\n' "$prefix" "$cr"
          ;;
        *) line="$prefix $line" ;;
      esac
    fi
    printf '%s%s\n' "$line" "$cr"
  fi
  cat
} < "$msg_file" > "$tmp"
mv -f "$tmp" "$msg_file"
trap - EXIT
exit 0
