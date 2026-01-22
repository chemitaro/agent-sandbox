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

assert_eq() {
    local expected="$1"
    local actual="$2"
    if [[ "$expected" != "$actual" ]]; then
        echo "Expected: $expected" >&2
        echo "Actual:   $actual" >&2
        return 1
    fi
}

mount_root_only_sets_workdir() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    load_sandbox_functions "$tmp_dir"

    local root="$tmp_dir/root"
    mkdir -p "$root"

    CALLER_PWD="$tmp_dir"
    parse_common_args --mount-root "$root"
    determine_paths

    local expected_root
    expected_root="$(resolve_path "$root")"
    assert_eq "$expected_root" "$ABS_MOUNT_ROOT"
    assert_eq "$expected_root" "$ABS_WORKDIR"

    local container_workdir
    container_workdir="$(compute_container_workdir "$ABS_MOUNT_ROOT" "$ABS_WORKDIR")"
    assert_eq "/srv/mount" "$container_workdir"
}

mount_root_and_workdir_maps_container_path() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    load_sandbox_functions "$tmp_dir"

    local root="$tmp_dir/root"
    local workdir="$tmp_dir/root/sub/dir"
    mkdir -p "$workdir"

    CALLER_PWD="$tmp_dir"
    parse_common_args --mount-root "$root" --workdir "$workdir"
    determine_paths

    local container_workdir
    container_workdir="$(compute_container_workdir "$ABS_MOUNT_ROOT" "$ABS_WORKDIR")"
    assert_eq "/srv/mount/sub/dir" "$container_workdir"
}

workdir_outside_mount_root_fails() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    load_sandbox_functions "$tmp_dir"

    local root="$tmp_dir/root"
    local workdir="$tmp_dir/other"
    mkdir -p "$root" "$workdir"

    CALLER_PWD="$tmp_dir"
    parse_common_args --mount-root "$root" --workdir "$workdir"

    if determine_paths; then
        echo "Expected determine_paths to fail for workdir outside mount-root" >&2
        return 1
    fi
}

boundary_prefix_is_not_within() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    load_sandbox_functions "$tmp_dir"

    local root="$tmp_dir/root"
    local workdir="$tmp_dir/root2"
    mkdir -p "$root" "$workdir"

    CALLER_PWD="$tmp_dir"
    parse_common_args --mount-root "$root" --workdir "$workdir"

    if determine_paths; then
        echo "Expected boundary check to fail for /root vs /root2" >&2
        return 1
    fi
}

relative_paths_resolve_from_caller_pwd() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    load_sandbox_functions "$tmp_dir"

    local base="$tmp_dir/base"
    mkdir -p "$base/root/sub"

    CALLER_PWD="$base"
    parse_common_args --mount-root "./root" --workdir "./root/sub"
    determine_paths

    local expected_root
    local expected_workdir
    expected_root="$(resolve_path "$base/root")"
    expected_workdir="$(resolve_path "$base/root/sub")"
    assert_eq "$expected_root" "$ABS_MOUNT_ROOT"
    assert_eq "$expected_workdir" "$ABS_WORKDIR"

    local container_workdir
    container_workdir="$(compute_container_workdir "$ABS_MOUNT_ROOT" "$ABS_WORKDIR")"
    assert_eq "/srv/mount/sub" "$container_workdir"
}

paths_with_spaces_are_handled() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    load_sandbox_functions "$tmp_dir"

    local root="$tmp_dir/root space"
    local workdir="$tmp_dir/root space/sub dir"
    mkdir -p "$workdir"

    CALLER_PWD="$tmp_dir"
    parse_common_args --mount-root "$root" --workdir "$workdir"
    determine_paths

    local container_workdir
    container_workdir="$(compute_container_workdir "$ABS_MOUNT_ROOT" "$ABS_WORKDIR")"
    assert_eq "/srv/mount/sub dir" "$container_workdir"
}

run_test "mount_root_only_sets_workdir" mount_root_only_sets_workdir
run_test "mount_root_and_workdir_maps_container_path" mount_root_and_workdir_maps_container_path
run_test "workdir_outside_mount_root_fails" workdir_outside_mount_root_fails
run_test "boundary_prefix_is_not_within" boundary_prefix_is_not_within
run_test "relative_paths_resolve_from_caller_pwd" relative_paths_resolve_from_caller_pwd
run_test "paths_with_spaces_are_handled" paths_with_spaces_are_handled
