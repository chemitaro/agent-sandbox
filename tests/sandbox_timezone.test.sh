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

detect_timezone_failures_fallback() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    load_sandbox_functions "$tmp_dir"

    local stub_dir="$tmp_dir/tz-stubs"
    mkdir -p "$stub_dir"

    cat > "$stub_dir/readlink" <<'STUB'
#!/bin/bash
exit 1
STUB

    cat > "$stub_dir/systemsetup" <<'STUB'
#!/bin/bash
exit 1
STUB

    cat > "$stub_dir/timedatectl" <<'STUB'
#!/bin/bash
exit 1
STUB

    cat > "$stub_dir/cat" <<'STUB'
#!/bin/bash
exit 1
STUB

    chmod +x "$stub_dir/readlink" "$stub_dir/systemsetup" "$stub_dir/timedatectl" "$stub_dir/cat"

    PATH="$stub_dir:$PATH"
    local tz
    tz="$(detect_timezone)"
    if [[ "$tz" != "Asia/Tokyo" ]]; then
        echo "Expected fallback timezone, got: $tz" >&2
        return 1
    fi
}

run_test "detect_timezone_failures_fallback" detect_timezone_failures_fallback
