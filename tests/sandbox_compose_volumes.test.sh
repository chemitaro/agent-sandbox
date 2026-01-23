#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$REPO_ROOT/docker-compose.yml"

assert_file_contains() {
    local file="$1"
    local expected="$2"
    if ! grep -Fq -- "$expected" "$file"; then
        echo "Expected $file to contain: $expected" >&2
        return 1
    fi
}

run_test() {
    local name="$1"
    shift
    echo "==> $name"
    "$@"
}

compose_has_shared_npm_volumes() {
    assert_file_contains "$COMPOSE_FILE" "sandbox-npm-global:/usr/local/share/npm-global"
    assert_file_contains "$COMPOSE_FILE" "sandbox-npm-cache:/home/node/.npm/_cache"

    assert_file_contains "$COMPOSE_FILE" "volumes:"
    assert_file_contains "$COMPOSE_FILE" "sandbox-npm-global:"
    assert_file_contains "$COMPOSE_FILE" "name: sandbox-npm-global"
    assert_file_contains "$COMPOSE_FILE" "sandbox-npm-cache:"
    assert_file_contains "$COMPOSE_FILE" "name: sandbox-npm-cache"
}

run_test "compose_has_shared_npm_volumes" compose_has_shared_npm_volumes

