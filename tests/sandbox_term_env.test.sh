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

run_test() {
    local name="$1"
    shift
    echo "==> $name"
    "$@"
}

dockerfile_sets_term_defaults() {
    assert_file_contains "$DOCKERFILE" "ENV TERM=xterm-256color"
    assert_file_contains "$DOCKERFILE" "ENV COLORTERM=truecolor"
}

dockerfile_has_ncurses_term_package() {
    assert_file_contains "$DOCKERFILE" "ncurses-term"
}

dockerfile_does_not_enable_fzf_plugin() {
    if grep -Fq -- "-p fzf" "$DOCKERFILE"; then
        echo "Did not expect $DOCKERFILE to enable the oh-my-zsh fzf plugin" >&2
        return 1
    fi
}

run_test "dockerfile_sets_term_defaults" dockerfile_sets_term_defaults
run_test "dockerfile_has_ncurses_term_package" dockerfile_has_ncurses_term_package
run_test "dockerfile_does_not_enable_fzf_plugin" dockerfile_does_not_enable_fzf_plugin
