#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

make_fake_sandbox_root() {
    local mode="${1:-}"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    mkdir -p "$tmp_dir/host"
    cp "$REPO_ROOT/host/sandbox" "$tmp_dir/host/sandbox"
    chmod +x "$tmp_dir/host/sandbox"

    if [[ "$mode" == "with_env" ]]; then
        : > "$tmp_dir/.env"
        mkdir -p "$tmp_dir/.agent-home"
    fi

    echo "$tmp_dir"
}

setup_stub_bins() {
    local tmp_dir="$1"
    local stub_dir="$tmp_dir/stubs"
    local log_file="$tmp_dir/stub_calls.log"

    mkdir -p "$stub_dir"

    for cmd in docker git; do
        cat > "$stub_dir/$cmd" <<'STUB'
#!/bin/bash
set -euo pipefail
log_file="${STUB_CALLS_LOG:-}"
if [[ -n "$log_file" ]]; then
    echo "$0 $*" >> "$log_file"
fi
exit 1
STUB
        chmod +x "$stub_dir/$cmd"
    done

    export STUB_CALLS_LOG="$log_file"
    export PATH="$stub_dir:$PATH"
    hash -r
}

run_cmd() {
    local stderr_file
    stderr_file="$(mktemp)"

    set +e
    RUN_STDOUT="$("$@" 2>"$stderr_file")"
    RUN_CODE=$?
    RUN_STDERR="$(cat "$stderr_file")"
    set -e

    rm -f "$stderr_file"
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    if [[ "$expected" != "$actual" ]]; then
        echo "Expected exit code $expected, got $actual" >&2
        return 1
    fi
}

assert_stdout_eq() {
    local expected="$1"
    local actual="$2"
    if [[ "$expected" != "$actual" ]]; then
        echo "Expected stdout to be: $expected" >&2
        echo "Actual stdout: $actual" >&2
        return 1
    fi
}

assert_stdout_contains() {
    local expected="$1"
    local actual="$2"
    if [[ "$actual" != *"$expected"* ]]; then
        echo "Expected stdout to contain: $expected" >&2
        echo "Actual stdout: $actual" >&2
        return 1
    fi
}

assert_no_files_created() {
    local tmp_dir="$1"
    if [[ -e "$tmp_dir/.env" || -e "$tmp_dir/.agent-home" ]]; then
        echo ".env or .agent-home was created unexpectedly" >&2
        return 1
    fi
}

assert_no_stub_calls() {
    local tmp_dir="$1"
    local log_file="$tmp_dir/stub_calls.log"
    if [[ -s "$log_file" ]]; then
        echo "Stubbed commands were invoked unexpectedly:" >&2
        cat "$log_file" >&2
        return 1
    fi
}

run_test() {
    local name="$1"
    shift
    echo "==> $name"
    "$@"
}
