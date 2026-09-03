#!/bin/sh
# Test suite for commit-issue-prefix.sh. Run with any POSIX shell: sh tests/test.sh
set -u

here=$(cd "$(dirname "$0")" && pwd)
script="$here/../commit-issue-prefix.sh"
work=$(mktemp -d "${TMPDIR:-/tmp}/commit-issue-prefix-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

pass=0
fail=0
n=0
repo=''
rc=0

# new_repo [branch] — fresh repository with one commit, checked out on <branch> when given.
new_repo() {
  n=$((n + 1))
  repo="$work/r$n"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  [ $# -eq 0 ] || git -C "$repo" checkout -q -b "$1"
}

# msg <escaped-text> — write the message file; \n escapes are interpreted.
msg() {
  printf '%b' "$1" > "$repo/MSG"
}

# run <args...> — run the hook inside the repository; stderr goes to ERR.
run() {
  (cd "$repo" && "$script" "$@" 2> ERR)
  rc=$?
}

# expect <name> <escaped-text> — the message file must equal the text exactly.
expect() {
  actual=$(cat "$repo/MSG"; printf x)
  actual=${actual%x}
  expected=$(printf '%bx' "$2")
  expected=${expected%x}
  if [ "$actual" = "$expected" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n' "$1"
    printf '  expected: '; printf '%s' "$expected" | od -An -c | tr -s ' \n' ' '; printf '\n'
    printf '  actual:   '; printf '%s' "$actual" | od -An -c | tr -s ' \n' ' '; printf '\n'
  fi
}

expect_status() {
  if [ "$rc" -eq "$2" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s: exit rc %s, expected %s\n' "$1" "$rc" "$2"
  fi
}

expect_stderr_has() {
  if grep -q -- "$2" "$repo/ERR"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s: stderr does not contain %s\n  stderr: %s\n' "$1" "$2" "$(cat "$repo/ERR")"
  fi
}

expect_stderr_empty() {
  if [ ! -s "$repo/ERR" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s: stderr not empty\n  stderr: %s\n' "$1" "$(cat "$repo/ERR")"
  fi
}

# --- v1-compatible defaults -------------------------------------------------------------------

new_repo 'feat/#111'
msg 'Add feature\n'
run MSG
expect_status default_status 0
expect default_github '[#111] Add feature\n'
expect_stderr_empty default_no_stderr

new_repo 'feat/#111'
msg 'Add feature\n'
run --template '({})' --regex '#[0-9]+' MSG
expect v1_placeholder_and_regex_alias '(#111) Add feature\n'

new_repo 'feature/ABC-123-impl'
msg 'Impl\n'
run --issue-regex '[A-Z]+-[0-9]+' MSG
expect jira '[ABC-123] Impl\n'

new_repo 'feature/abc-123-impl'
msg 'Impl\n'
run --issue-regex '[a-zA-Z]+-[0-9]+' MSG
expect jira_uppercased '[ABC-123] Impl\n'

new_repo 'feat/#111'
msg 'Add feature\n'
run --suffix true MSG
expect suffix_true 'Add feature [#111]\n'

new_repo 'feat/#111'
msg 'Add feature\n'
run --suffix MSG
expect suffix_bare_flag 'Add feature [#111]\n'

new_repo 'feat/#111'
msg 'Add feature\n'
run -s false MSG
expect suffix_false_is_prefix '[#111] Add feature\n'

new_repo 'feat/#111'
msg '\n# Please enter the commit message\n'
run --suffix MSG
expect suffix_empty_first_line '[#111]\n# Please enter the commit message\n'

# --- type detection (opt-in with --types) ----------------------------------------------------

new_repo 'feat/#111'
msg 'Add feature\n'
run --types feat,fix MSG
expect type_from_path_segment '[#111] feat: Add feature\n'
expect_stderr_empty type_found_no_notice

new_repo '20266-fix-side-panel-stacking'
msg 'Fix panel\n'
run --issue-regex '^[0-9]+' --template '[#{issue}]' --types feat,fix,chore MSG
expect type_after_issue '[#20266] fix: Fix panel\n'

new_repo '20266-fix-side-panel-stacking'
msg 'Fix panel\n'
run --issue-regex='^[0-9]+' --template='[#{issue}]' --types=feat,fix,chore MSG
expect equals_form_options '[#20266] fix: Fix panel\n'

new_repo '20266-fix'
msg 'Fix\n'
run --issue-regex '^[0-9]+' --template '[#{issue}]' --types fix MSG
expect type_is_last_segment '[#20266] fix: Fix\n'

new_repo '#111/fix-thing'
msg 'Fix\n'
run --types fix MSG
expect type_after_issue_slash '[#111] fix: Fix\n'

new_repo '20266-add-test-fixtures'
msg 'Add\n'
run --issue-regex '^[0-9]+' --template '[#{issue}]' --types feat,fix,test MSG
expect type_not_taken_from_slug '[#20266] Add\n'
expect_stderr_has notice_when_no_type 'no type segment'

new_repo '20266-add-test-fixtures'
msg 'Add\n'
run --issue-regex '^[0-9]+' --template '[#{issue}]' --types feat,fix,test -q MSG
expect quiet_output '[#20266] Add\n'
expect_stderr_empty quiet_no_notice

new_repo '20266-add-test-fixtures'
msg 'Add\n'
run --issue-regex '^[0-9]+' --template '[#{issue}]' MSG
expect no_types_no_type_part '[#20266] Add\n'
expect_stderr_empty no_types_no_notice

new_repo 'feat/#111'
msg 'Add feature\n'
run --types feat --type-template '({type})' MSG
expect custom_type_template '[#111] (feat) Add feature\n'

new_repo 'feat/#111'
msg 'Add feature\n'
run --types feat --type-template '' MSG
expect empty_type_template_disables_type '[#111] Add feature\n'

new_repo 'feat/#111'
msg 'Add feature\n'
run --types feat --suffix MSG
expect suffix_ignores_type 'Add feature [#111]\n'
expect_stderr_empty suffix_no_notice

# --- subject already carries a type (agent or author wrote "type(scope): ...") --------------

new_repo '20266-fix-side-panel'
msg 'fix(auth): 만료된 refresh token 재사용 차단\n'
run --issue-regex '^[0-9]+' --template '[#{issue}]' --types feat,fix MSG
expect subject_type_kept_not_duplicated '[#20266] fix(auth): 만료된 refresh token 재사용 차단\n'
expect_stderr_empty subject_type_no_notice

new_repo '20266-add-thing'
msg 'feat(api)!: 주문 API 를 checkout 경로로 변경\n'
run --issue-regex '^[0-9]+' --template '[#{issue}]' --types feat,fix MSG
expect subject_type_breaking_marker '[#20266] feat(api)!: 주문 API 를 checkout 경로로 변경\n'
expect_stderr_empty subject_type_on_typeless_branch_no_notice

new_repo '20266-add-thing'
msg 'fixes the thing\n'
run --issue-regex '^[0-9]+' --template '[#{issue}]' --types feat,fix MSG
expect subject_word_prefix_is_not_a_type '[#20266] fixes the thing\n'
expect_stderr_has subject_word_prefix_still_notices 'no type segment'

new_repo 'feat/#111'
msg 'fix: typed subject without --types\n'
run MSG
expect no_types_ignores_subject_type '[#111] fix: typed subject without --types\n'

# --- message file shapes ---------------------------------------------------------------------

new_repo 'feat/#111'
msg '\n# Please enter the commit message for your changes.\n'
run --types feat MSG
expect editor_template '[#111] feat: \n# Please enter the commit message for your changes.\n'

new_repo 'feat/#111'
msg '# template first line\nbody\n'
run MSG
expect comment_first_line_gets_own_line '[#111] \n# template first line\nbody\n'

new_repo 'feat/#111'
: > "$repo/MSG"
run MSG
expect empty_file '[#111] \n'

new_repo 'feat/#111'
msg 'Subject\n\nBody line one.\nBody line two.\n'
run MSG
expect body_preserved '[#111] Subject\n\nBody line one.\nBody line two.\n'

new_repo 'feat/#111'
printf 'No trailing newline' > "$repo/MSG"
run MSG
expect no_trailing_newline_gets_one '[#111] No trailing newline\n'

new_repo 'feat/#111'
msg 'Add feature\r\nBody\r\n'
run MSG
expect crlf_prefix_keeps_line_ending '[#111] Add feature\r\nBody\r\n'

new_repo 'feat/#111'
msg 'Add feature\r\n'
run --suffix MSG
expect crlf_suffix_before_line_ending 'Add feature [#111]\r\n'

new_repo 'feat/#111'
msg '# template\r\nbody\r\n'
run MSG
expect crlf_comment_first_line '[#111] \r\n# template\r\nbody\r\n'

# --- nothing is written ----------------------------------------------------------------------

new_repo 'feat/#111'
msg '[#111] Already prefixed\n'
run --types feat MSG
expect idempotent '[#111] Already prefixed\n'

new_repo 'feat/#111'
msg 'Add feature [#111]\n'
run --suffix MSG
expect idempotent_suffix 'Add feature [#111]\n'

new_repo 'work'
msg 'Plain branch\n'
run MSG
expect_status no_issue_status 0
expect no_issue_unchanged 'Plain branch\n'

new_repo 'feat/#111'
git -C "$repo" checkout -q --detach
msg 'Detached\n'
run MSG
expect detached_head_unchanged 'Detached\n'

new_repo 'feat/#111'
git -C "$repo" rev-parse HEAD > "$repo/.git/MERGE_HEAD"
msg 'Merge branch x\n'
run MSG
expect merge_in_progress_unchanged 'Merge branch x\n'

new_repo 'feat/#111'
: > "$repo/.git/SQUASH_MSG"
msg 'Squashed commit\n'
run MSG
expect squash_in_progress_unchanged 'Squashed commit\n'

new_repo 'feat/#111'
msg 'Merge branch x\n'
run MSG merge
expect source_arg_merge_unchanged 'Merge branch x\n'

new_repo 'feat/#111'
msg 'Squashed\n'
(cd "$repo" && PRE_COMMIT_COMMIT_MSG_SOURCE=squash "$script" MSG 2> ERR)
rc=$?
expect env_source_squash_unchanged 'Squashed\n'

new_repo 'feat/#111'
msg 'Amend\n'
run MSG commit abc123
expect source_commit_with_sha_still_prefixes '[#111] Amend\n'

# --- usage errors ----------------------------------------------------------------------------

new_repo 'feat/#111'
msg 'x\n'
run --bogus MSG
expect_status unknown_option_exit_2 2
expect unknown_option_unchanged 'x\n'

new_repo 'feat/#111'
msg 'x\n'
run
expect_status missing_file_exit_2 2

new_repo 'feat/#111'
msg 'x\n'
run --suffix maybe MSG
expect_status bad_bool_exit_2 2

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
