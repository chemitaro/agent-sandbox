#!/bin/bash
#
# Generate Docker Compose override with read-only Git metadata mounts.
# Intended to run on the host before starting the sandbox container.
#
# Usage: generate-git-ro-overrides.sh <source_path> <product_work_dir> <output_file>
# Environment variables:
#   SANDBOX_MAX_GIT_DEPTH (optional) - max depth for Git discovery (default 10)
#   SANDBOX_INCLUDE_ABSOLUTE_GIT (optional) - if 1, mount absolute Git dirs outside SOURCE_PATH
#
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <source_path> <product_work_dir> <output_file>" >&2
  exit 1
fi

SOURCE_PATH="$1"
PRODUCT_WORK_DIR="$2"
OUTPUT_FILE="$3"
MAX_DEPTH="${SANDBOX_MAX_GIT_DEPTH:-10}"
INCLUDE_ABS_GIT="${SANDBOX_INCLUDE_ABSOLUTE_GIT:-1}"

if [ ! -d "$SOURCE_PATH" ]; then
  echo "[generate-git-ro] INFO: source path '$SOURCE_PATH' does not exist. Writing empty override." >&2
  cat >"$OUTPUT_FILE" <<'YAML'
version: "3.8"
services:
  agent-sandbox:
    volumes: []
YAML
  exit 0
fi

TMP_MOUNTS=$(mktemp)
trap 'rm -f "$TMP_MOUNTS" "$TMP_MOUNTS.sorted"' EXIT

echo "[generate-git-ro] Scanning for Git metadata under $SOURCE_PATH (max depth $MAX_DEPTH)" >&2

find "$SOURCE_PATH" -maxdepth "$MAX_DEPTH" -type d -name .git 2>/dev/null | while IFS= read -r git_path; do
  repo_dir=$(dirname "$git_path")

  if ! git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    continue
  fi

  abs_git_dir=$(git -C "$repo_dir" rev-parse --absolute-git-dir 2>/dev/null || true)
  git_common_dir=$(git -C "$repo_dir" rev-parse --git-common-dir 2>/dev/null || true)

  for dir in "$git_path" "$abs_git_dir" "$git_common_dir"; do
    [ -n "$dir" ] || continue

    if [ -d "$dir" ] || [ -f "$dir" ]; then
      if [[ "$dir" == /* ]]; then
        real_dir="$dir"
      else
        real_dir=$(python3 - "$repo_dir" "$dir" <<'PY_ABS'
import os, sys
repo = sys.argv[1]
path = sys.argv[2]
if os.path.isabs(path):
    print(os.path.abspath(path))
else:
    print(os.path.abspath(os.path.join(repo, path)))
PY_ABS
)
      fi
    else
      continue
    fi

    if [[ "$real_dir" == "$SOURCE_PATH"* ]]; then
      target="${real_dir/$SOURCE_PATH/$PRODUCT_WORK_DIR}"
      source="$real_dir"
    else
      [ "$INCLUDE_ABS_GIT" = "1" ] || continue
      target="$real_dir"
      source="$real_dir"
    fi

    printf '%s	%s\n' "$source" "$target" >>"$TMP_MOUNTS"
  done
done

if [ ! -s "$TMP_MOUNTS" ]; then
  echo "[generate-git-ro] INFO: no Git metadata found. Writing empty override." >&2
  cat >"$OUTPUT_FILE" <<'YAML'
version: "3.8"
services:
  agent-sandbox:
    volumes: []
YAML
  exit 0
fi

sort -u "$TMP_MOUNTS" >"$TMP_MOUNTS.sorted"

{
  echo 'version: "3.8"'
  echo 'services:'
  echo '  agent-sandbox:'
  echo '    volumes:'
  while IFS=$'\t' read -r src tgt; do
    printf '      - type: bind\n        source: %s\n        target: %s\n        read_only: true\n' "$src" "$tgt"
  done <"$TMP_MOUNTS.sorted"
} >"$OUTPUT_FILE"

echo "[generate-git-ro] Wrote $(wc -l <"$TMP_MOUNTS.sorted") read-only mount(s) to $OUTPUT_FILE" >&2
