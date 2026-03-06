#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="$REPO_ROOT/Dockerfile"

assert_file_contains() {
    local file="$1"
    local expected="$2"
    if ! grep -Fq -- "$expected" "$file"; then
        echo "Expected $file to contain: $expected" >&2
        return 1
    fi
}

assert_file_not_contains() {
    local file="$1"
    local unexpected="$2"
    if grep -Fq -- "$unexpected" "$file"; then
        echo "Expected $file to NOT contain: $unexpected" >&2
        return 1
    fi
}

run_test() {
    local name="$1"
    shift
    echo "==> $name"
    "$@"
}

dockerfile_uses_nodesource_setup_24() {
    assert_file_contains "$DOCKERFILE" "setup_24.x"
}

dockerfile_does_not_use_nodesource_setup_20() {
    assert_file_not_contains "$DOCKERFILE" "setup_20.x"
}

run_test "dockerfile_uses_nodesource_setup_24" dockerfile_uses_nodesource_setup_24
run_test "dockerfile_does_not_use_nodesource_setup_20" dockerfile_does_not_use_nodesource_setup_20
