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

realpath_fallback_without_python() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    load_sandbox_functions "$tmp_dir"

    local stub_dir="$tmp_dir/realpath-stub"
    mkdir -p "$stub_dir"

    cat > "$stub_dir/realpath" <<'STUB'
#!/bin/bash
exit 1
STUB

    chmod +x "$stub_dir/realpath"

    local link="$tmp_dir/sandbox-link"
    ln -s "$tmp_dir/host/sandbox" "$link"

    PATH="$stub_dir:$PATH"

    local resolved
    resolved="$(realpath_safe "$link")"
    local expected
    expected="$(realpath_safe "$tmp_dir/host/sandbox")"
    if [[ "$resolved" != "$expected" ]]; then
        echo "Expected resolved path to be symlink target" >&2
        echo "Expected: $expected" >&2
        echo "Actual:   $resolved" >&2
        return 1
    fi
}

run_test "realpath_fallback_without_python" realpath_fallback_without_python
