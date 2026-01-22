#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="$REPO_ROOT/host/sandbox"
DEST="/usr/local/bin/sandbox"

if [[ ! -x "$TARGET" ]]; then
    echo "sandbox entrypoint not found or not executable: $TARGET" >&2
    exit 1
fi

if [[ ! -d "/usr/local/bin" ]]; then
    echo "/usr/local/bin does not exist" >&2
    exit 1
fi

if [[ -e "$DEST" ]]; then
    if [[ -L "$DEST" ]]; then
        local_target="$(readlink "$DEST")"
        if [[ "$local_target" == "$TARGET" ]]; then
            echo "sandbox already installed: $DEST -> $TARGET"
            exit 0
        fi
    fi
    echo "$DEST already exists. Remove it first if you want to replace it." >&2
    exit 1
fi

if [[ ! -w "/usr/local/bin" ]]; then
    echo "No permission to write to /usr/local/bin. Try: sudo $0" >&2
    exit 1
fi

ln -s "$TARGET" "$DEST"

echo "Installed sandbox: $DEST -> $TARGET"
