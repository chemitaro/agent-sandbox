#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/_helpers.sh
source "$SCRIPT_DIR/_helpers.sh"

load_sandbox_functions() {
    local tmp_dir="$1"
    # shellcheck source=/dev/null
    source "$tmp_dir/host/sandbox"
}

setup_stub_git() {
    local tmp_dir="$1"
    local stub_dir="$tmp_dir/git-stub"
    mkdir -p "$stub_dir"

    cat > "$stub_dir/git" <<'STUB'
#!/bin/bash
set -euo pipefail

if [[ "$*" == *"rev-parse --show-toplevel"* ]]; then
    if [[ "${STUB_GIT_FAIL_REV_PARSE:-}" == "1" ]]; then
        exit 1
    fi
    printf '%s\n' "${STUB_GIT_REV_PARSE_ROOT}"
    exit 0
fi

if [[ "$*" == *"worktree list --porcelain"* ]]; then
    printf '%s\n' "${STUB_GIT_WORKTREE_LIST}"
    exit 0
fi

exit 1
STUB
    chmod +x "$stub_dir/git"

    export PATH="$stub_dir:$PATH"
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    if [[ "$expected" != "$actual" ]]; then
        echo "Expected: $expected" >&2
        echo "Actual:   $actual" >&2
        return 1
    fi
}

auto_detect_mount_root_lca() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    load_sandbox_functions "$tmp_dir"
    setup_stub_git "$tmp_dir"

    local base="$tmp_dir/repo"
    local main="$base/main"
    local work1="$base/work1"
    local work2="$base/work2"
    mkdir -p "$main" "$work1" "$work2"
    touch "$work1/.git"

    export STUB_GIT_REV_PARSE_ROOT="$work1"
    STUB_GIT_WORKTREE_LIST="$(printf 'worktree %s\nworktree %s\nworktree %s\n' "$main" "$work1" "$work2")"
    export STUB_GIT_WORKTREE_LIST

    CALLER_PWD="$work1"
    parse_common_args --workdir "$work1"
    determine_paths

    local expected_root
    expected_root="$(resolve_path "$base")"
    assert_eq "$expected_root" "$ABS_MOUNT_ROOT"
}

guard_forbidden_path_errors() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    load_sandbox_functions "$tmp_dir"
    setup_stub_git "$tmp_dir"

    local base="$tmp_dir/forbidden"
    local workdir="$base/work1"
    mkdir -p "$workdir"
    touch "$workdir/.git"

    export STUB_GIT_REV_PARSE_ROOT="$workdir"
    STUB_GIT_WORKTREE_LIST="$(printf 'worktree %s\nworktree %s\n' "/" "$workdir")"
    export STUB_GIT_WORKTREE_LIST

    CALLER_PWD="$workdir"
    parse_common_args --workdir "$workdir"
    if determine_paths; then
        echo "Expected forbidden path guard to fail" >&2
        return 1
    fi
}

guard_max_up_level_errors() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    load_sandbox_functions "$tmp_dir"
    setup_stub_git "$tmp_dir"

    local base="$tmp_dir/a"
    local repo_root="$base/b/repo"
    local other="$base/worktree"
    mkdir -p "$repo_root" "$other"
    touch "$repo_root/.git"

    export STUB_GIT_REV_PARSE_ROOT="$repo_root"
    STUB_GIT_WORKTREE_LIST="$(printf 'worktree %s\nworktree %s\n' "$repo_root" "$other")"
    export STUB_GIT_WORKTREE_LIST

    CALLER_PWD="$repo_root"
    parse_common_args --workdir "$repo_root"
    if determine_paths; then
        echo "Expected MAX_UP_LEVEL guard to fail" >&2
        return 1
    fi
}

git_rev_parse_failure_errors() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    load_sandbox_functions "$tmp_dir"
    setup_stub_git "$tmp_dir"

    local repo_root="$tmp_dir/repo"
    mkdir -p "$repo_root"
    touch "$repo_root/.git"

    export STUB_GIT_FAIL_REV_PARSE=1
    export STUB_GIT_REV_PARSE_ROOT=""
    export STUB_GIT_WORKTREE_LIST=""

    CALLER_PWD="$repo_root"
    parse_common_args --workdir "$repo_root"
    if determine_paths; then
        echo "Expected git rev-parse failure to error" >&2
        return 1
    fi
}

run_test "auto_detect_mount_root_lca" auto_detect_mount_root_lca
run_test "guard_forbidden_path_errors" guard_forbidden_path_errors
run_test "guard_max_up_level_errors" guard_max_up_level_errors
run_test "git_rev_parse_failure_errors" git_rev_parse_failure_errors
