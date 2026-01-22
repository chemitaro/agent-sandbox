#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/_helpers.sh
source "$SCRIPT_DIR/_helpers.sh"

hash_deterministic_full_paths() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_stub_bins "$tmp_dir"

    mkdir -p "$tmp_dir/a/project" "$tmp_dir/b/project"

    run_cmd "$tmp_dir/host/sandbox" name --mount-root "$tmp_dir/a/project" --workdir "$tmp_dir/a/project"
    assert_exit_code 0 "$RUN_CODE"
    local name1="$RUN_STDOUT"

    run_cmd "$tmp_dir/host/sandbox" name --mount-root "$tmp_dir/b/project" --workdir "$tmp_dir/b/project"
    assert_exit_code 0 "$RUN_CODE"
    local name2="$RUN_STDOUT"

    if [[ "$name1" == "$name2" ]]; then
        echo "Expected different names for different full paths" >&2
        return 1
    fi

    run_cmd "$tmp_dir/host/sandbox" name --mount-root "$tmp_dir/a/project" --workdir "$tmp_dir/a/project"
    assert_exit_code 0 "$RUN_CODE"
    if [[ "$name1" != "$RUN_STDOUT" ]]; then
        echo "Expected deterministic name for same inputs" >&2
        return 1
    fi

    assert_no_files_created "$tmp_dir"
    assert_no_stub_calls "$tmp_dir"
}

slug_normalization() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_stub_bins "$tmp_dir"

    local mount_root="$tmp_dir/Project Name!!"
    mkdir -p "$mount_root"

    run_cmd "$tmp_dir/host/sandbox" name --mount-root "$mount_root" --workdir "$mount_root"
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "sandbox-Project-Name-" "$RUN_STDOUT"

    assert_no_files_created "$tmp_dir"
    assert_no_stub_calls "$tmp_dir"
}

slug_fallback_when_empty() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_stub_bins "$tmp_dir"

    local mount_root="$tmp_dir/###"
    mkdir -p "$mount_root"

    run_cmd "$tmp_dir/host/sandbox" name --mount-root "$mount_root" --workdir "$mount_root"
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "sandbox-dir-" "$RUN_STDOUT"

    assert_no_files_created "$tmp_dir"
    assert_no_stub_calls "$tmp_dir"
}

container_name_length_limit() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_stub_bins "$tmp_dir"

    local long_name
    long_name="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    local mount_root="$tmp_dir/$long_name"
    mkdir -p "$mount_root"

    run_cmd "$tmp_dir/host/sandbox" name --mount-root "$mount_root" --workdir "$mount_root"
    assert_exit_code 0 "$RUN_CODE"

    local name="$RUN_STDOUT"
    if (( ${#name} > 63 )); then
        echo "Expected container name length <= 63, got ${#name}" >&2
        return 1
    fi

    local hash_part="${name##*-}"
    local slug_part="${name#sandbox-}"
    slug_part="${slug_part%-${hash_part}}"

    if (( ${#slug_part} > 42 )); then
        echo "Expected slug length <= 42, got ${#slug_part}" >&2
        return 1
    fi

    assert_no_files_created "$tmp_dir"
    assert_no_stub_calls "$tmp_dir"
}

sha_fallback_to_shasum() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_stub_bins "$tmp_dir"

    local stub_dir="$tmp_dir/hash-stubs"
    mkdir -p "$stub_dir"

    cat > "$stub_dir/sha256sum" <<'STUB'
#!/bin/bash
exit 1
STUB
    chmod +x "$stub_dir/sha256sum"

    cat > "$stub_dir/shasum" <<'STUB'
#!/bin/bash
# Always return a fixed hash
printf '%s  -\n' "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
STUB
    chmod +x "$stub_dir/shasum"

    export PATH="$stub_dir:$PATH"

    mkdir -p "$tmp_dir/fallback"
    run_cmd "$tmp_dir/host/sandbox" name --mount-root "$tmp_dir/fallback" --workdir "$tmp_dir/fallback"
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "-bbbbbbbbbbbb" "$RUN_STDOUT"

    assert_no_files_created "$tmp_dir"
    assert_no_stub_calls "$tmp_dir"
}

run_test "hash_deterministic_full_paths" hash_deterministic_full_paths
run_test "slug_normalization" slug_normalization
run_test "slug_fallback_when_empty" slug_fallback_when_empty
run_test "container_name_length_limit" container_name_length_limit
run_test "sha_fallback_to_shasum" sha_fallback_to_shasum
