#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/_helpers.sh
source "$SCRIPT_DIR/_helpers.sh"

path_without_docker() {
    # Minimal PATH without docker on this environment (Darwin).
    echo "/usr/bin:/bin"
}

setup_compose_stubs() {
    local tmp_dir="$1"
    local stub_dir="$tmp_dir/compose-stubs"
    local log_file="$tmp_dir/compose.log"
    mkdir -p "$stub_dir"
    : > "$log_file"

    cat > "$stub_dir/docker" <<'STUB'
#!/bin/bash
set -euo pipefail

if [[ "$1" == "info" ]]; then
    exit "${STUB_DOCKER_INFO_EXIT:-0}"
fi

if [[ "$1" == "inspect" ]]; then
    if [[ "${2:-}" == "--format" || "${2:-}" == "-f" ]]; then
        format="${3:-}"
        if [[ "$format" == *"State.Status"* ]]; then
            printf '%s\n' "${STUB_DOCKER_INSPECT_STATUS:-}"
        elif [[ "$format" == *".Id"* ]]; then
            printf '%s\n' "${STUB_DOCKER_INSPECT_ID:-}"
        fi
        exit "${STUB_DOCKER_INSPECT_EXIT:-1}"
    fi
    if [[ -n "${STUB_DOCKER_INSPECT_OUTPUT:-}" ]]; then
        printf '%s\n' "$STUB_DOCKER_INSPECT_OUTPUT"
    fi
    exit "${STUB_DOCKER_INSPECT_EXIT:-1}"
fi

if [[ "$1" == "compose" ]]; then
    shift
    if [[ "${1:-}" == "version" ]]; then
        if [[ -n "${STUB_DOCKER_COMPOSE_VERSION:-}" ]]; then
            printf '%s\n' "$STUB_DOCKER_COMPOSE_VERSION"
            exit 0
        fi
        exit "${STUB_DOCKER_COMPOSE_VERSION_EXIT:-1}"
    fi

    {
        echo "PWD=$(pwd)"
        printf 'CMD='
        printf '%q ' docker compose "$@"
        printf '\n'
        echo "CONTAINER_NAME=${CONTAINER_NAME-}"
        echo "COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME-}"
        echo "SOURCE_PATH=${SOURCE_PATH-}"
        echo "PRODUCT_WORK_DIR=${PRODUCT_WORK_DIR-}"
        echo "HOST_SANDBOX_PATH=${HOST_SANDBOX_PATH-}"
        echo "HOST_USERNAME=${HOST_USERNAME-}"
        echo "PRODUCT_NAME=${PRODUCT_NAME-}"
        if [[ -n "${TZ+x}" ]]; then
            echo "TZ=${TZ-}"
        fi
    } >> "${STUB_DOCKER_LOG}"
    exit 0
fi

exit 1
STUB

    cat > "$stub_dir/docker-compose" <<'STUB'
#!/bin/bash
set -euo pipefail

if [[ "${1:-}" == "version" ]]; then
    printf '%s\n' "${STUB_DOCKER_COMPOSE_LEGACY_VERSION}"
    exit 0
fi

{
    echo "PWD=$(pwd)"
    printf 'CMD='
    printf '%q ' docker-compose "$@"
    printf '\n'
} >> "${STUB_DOCKER_LOG}"
exit 0
STUB

    chmod +x "$stub_dir/docker" "$stub_dir/docker-compose"

    export STUB_DOCKER_LOG="$log_file"
    export COMPOSE_STUB_DIR="$stub_dir"
    export PATH="$stub_dir:$(path_without_docker)"
    hash -r
    COMPOSE_LOG_FILE="$log_file"
}

setup_tmux_stubs() {
    local tmp_dir="$1"
    local stub_dir="${COMPOSE_STUB_DIR:-$tmp_dir/compose-stubs}"
    local log_file="$tmp_dir/tmux.log"
    mkdir -p "$stub_dir"
    : > "$log_file"

    cat > "$stub_dir/tmux" <<'STUB'
#!/bin/bash
set -euo pipefail

log_file="${STUB_TMUX_LOG:-}"
if [[ -n "$log_file" ]]; then
    printf 'CMD=' >> "$log_file"
    printf '%q ' "$0" "$@" >> "$log_file"
    printf '\n' >> "$log_file"
fi

case "${1:-}" in
    has-session)
        if [[ "${STUB_TMUX_HAS_SESSION:-0}" == "1" ]]; then
            exit 0
        fi
        exit 1
        ;;
    new-session|attach-session|switch-client)
        exit 0
        ;;
esac

exit 0
STUB

    chmod +x "$stub_dir/tmux"
    export STUB_TMUX_LOG="$log_file"
    hash -r
}

compute_expected_compose_name() {
    local tmp_dir="$1"
    local mount_root="$2"
    local workdir="$3"
    # shellcheck source=/dev/null
    source "$tmp_dir/host/sandbox"
    CALLER_PWD="$tmp_dir"
    local abs_root
    local abs_workdir
    abs_root="$(resolve_path "$mount_root")"
    abs_workdir="$(resolve_path "$workdir")"
    compute_compose_project_name "$abs_root" "$abs_workdir"
}

assert_log_contains() {
    local log_file="$1"
    local expected="$2"
    if ! grep -Fq -- "$expected" "$log_file"; then
        echo "Expected log to contain: $expected" >&2
        echo "--- log ---" >&2
        cat "$log_file" >&2
        return 1
    fi
}

assert_log_not_contains() {
    local log_file="$1"
    local expected="$2"
    if grep -Fq -- "$expected" "$log_file"; then
        echo "Expected log to NOT contain: $expected" >&2
        echo "--- log ---" >&2
        cat "$log_file" >&2
        return 1
    fi
}

assert_log_contains_after() {
    local log_file="$1"
    local anchor="$2"
    local expected="$3"
    if ! awk -v anchor="$anchor" -v expected="$expected" '
        $0 ~ anchor { found=1; next }
        found && $0 ~ expected { ok=1; exit }
        END { exit ok ? 0 : 1 }
    ' "$log_file"; then
        echo "Expected log to contain after anchor: $expected" >&2
        echo "Anchor: $anchor" >&2
        echo "--- log ---" >&2
        cat "$log_file" >&2
        return 1
    fi
}

help_top_level() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_stub_bins "$tmp_dir"

    run_cmd "$tmp_dir/host/sandbox" --help
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "Usage:" "$RUN_STDOUT"

    run_cmd "$tmp_dir/host/sandbox" -h
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "Usage:" "$RUN_STDOUT"

    assert_no_files_created "$tmp_dir"
    assert_no_stub_calls "$tmp_dir"
}

help_subcommand() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_stub_bins "$tmp_dir"

    run_cmd "$tmp_dir/host/sandbox" shell --help
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "Usage: sandbox shell" "$RUN_STDOUT"

    run_cmd "$tmp_dir/host/sandbox" shell -h
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "Usage: sandbox shell" "$RUN_STDOUT"

    assert_no_files_created "$tmp_dir"
    assert_no_stub_calls "$tmp_dir"
}

help_any_position() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_stub_bins "$tmp_dir"

    run_cmd "$tmp_dir/host/sandbox" shell --workdir /nope --help
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "Usage: sandbox shell" "$RUN_STDOUT"

    assert_no_files_created "$tmp_dir"
    assert_no_stub_calls "$tmp_dir"
}

help_has_no_side_effects() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_stub_bins "$tmp_dir"

    run_cmd "$tmp_dir/host/sandbox" help --workdir /nope
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "Usage:" "$RUN_STDOUT"

    assert_no_files_created "$tmp_dir"
    assert_no_stub_calls "$tmp_dir"
}

name_one_line_stdout() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_stub_bins "$tmp_dir"

    mkdir -p "$tmp_dir/project"
    run_cmd "$tmp_dir/host/sandbox" name --mount-root "$tmp_dir/project" --workdir "$tmp_dir/project"
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "sandbox-" "$RUN_STDOUT"
    if [[ "$RUN_STDOUT" == *$'\n'* ]]; then
        echo "Expected stdout to be a single line" >&2
        return 1
    fi

    assert_no_files_created "$tmp_dir"
    assert_no_stub_calls "$tmp_dir"
}

docker_cmd_missing_errors() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"

    mkdir -p "$tmp_dir/project"
    local no_docker_path
    no_docker_path="$(path_without_docker)"

    PATH="$no_docker_path" hash -r
    PATH="$no_docker_path" run_cmd "$tmp_dir/host/sandbox" status --mount-root "$tmp_dir/project" --workdir "$tmp_dir/project"
    if [[ "$RUN_CODE" -eq 0 ]]; then
        echo "Expected docker missing error" >&2
        return 1
    fi
}

docker_daemon_unreachable_errors() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"

    local stub_dir="$tmp_dir/docker-stub"
    mkdir -p "$stub_dir"

    cat > "$stub_dir/docker" <<'STUB'
#!/bin/bash
exit 1
STUB
    chmod +x "$stub_dir/docker"

    mkdir -p "$tmp_dir/project"
    PATH="$stub_dir:$(path_without_docker)" hash -r
    PATH="$stub_dir:$(path_without_docker)" run_cmd "$tmp_dir/host/sandbox" status --mount-root "$tmp_dir/project" --workdir "$tmp_dir/project"
    if [[ "$RUN_CODE" -eq 0 ]]; then
        echo "Expected docker daemon error" >&2
        return 1
    fi
}

help_and_name_work_without_docker() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"

    mkdir -p "$tmp_dir/project"
    local no_docker_path
    no_docker_path="$(path_without_docker)"

    PATH="$no_docker_path" hash -r
    PATH="$no_docker_path" run_cmd "$tmp_dir/host/sandbox" help --workdir "$tmp_dir/project"
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "Usage:" "$RUN_STDOUT"

    PATH="$no_docker_path" hash -r
    PATH="$no_docker_path" run_cmd "$tmp_dir/host/sandbox" name --mount-root "$tmp_dir/project" --workdir "$tmp_dir/project"
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "sandbox-" "$RUN_STDOUT"
}
setup_env_for_up() {
    local tmp_dir="$1"
    local mount_root="$2"
    local workdir="$3"
    mkdir -p "$mount_root" "$workdir"
}

up_runs_compose_from_sandbox_root() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    run_cmd "$tmp_dir/host/sandbox" up --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "PWD=$(realpath "$tmp_dir")"
    assert_log_contains "$log_file" "CMD=docker compose up -d --build"
}

up_injects_required_env() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    run_cmd "$tmp_dir/host/sandbox" name --mount-root "$root" --workdir "$root"
    local expected_name="$RUN_STDOUT"
    local expected_compose_name
    expected_compose_name="$(compute_expected_compose_name "$tmp_dir" "$root" "$root")"

    run_cmd "$tmp_dir/host/sandbox" up --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "CONTAINER_NAME=$expected_name"
    assert_log_contains "$log_file" "COMPOSE_PROJECT_NAME=$expected_compose_name"
    assert_log_contains "$log_file" "SOURCE_PATH=$(realpath "$root")"
    assert_log_contains "$log_file" "PRODUCT_WORK_DIR=/srv/mount"
    assert_log_contains "$log_file" "HOST_SANDBOX_PATH=$(realpath "$tmp_dir")"
    assert_log_contains "$log_file" "HOST_USERNAME=$(whoami)"
    assert_log_contains "$log_file" "PRODUCT_NAME=mount"
}

up_creates_empty_env_if_missing() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"
    rm -f "$tmp_dir/.env"

    run_cmd "$tmp_dir/host/sandbox" up --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    if [[ ! -f "$tmp_dir/.env" ]]; then
        echo ".env should be created" >&2
        return 1
    fi
    if [[ -s "$tmp_dir/.env" ]]; then
        echo ".env should be empty" >&2
        return 1
    fi
}

up_does_not_overwrite_existing_env() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"
    echo "SECRET=keep" > "$tmp_dir/.env"

    run_cmd "$tmp_dir/host/sandbox" up --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    if [[ "$(cat "$tmp_dir/.env")" != "SECRET=keep" ]]; then
        echo ".env should not be overwritten" >&2
        return 1
    fi
}

up_creates_agent_home_dirs() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"
    rm -rf "$tmp_dir/.agent-home"

    run_cmd "$tmp_dir/host/sandbox" up --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    if [[ ! -d "$tmp_dir/.agent-home/.claude" || ! -d "$tmp_dir/.agent-home/.codex" || ! -d "$tmp_dir/.agent-home/commandhistory" ]]; then
        echo "agent-home directories should be created" >&2
        return 1
    fi
}

compose_command_selection_v2() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"
    export STUB_DOCKER_COMPOSE_VERSION_EXIT=0
    export STUB_DOCKER_COMPOSE_LEGACY_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    run_cmd "$tmp_dir/host/sandbox" up --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "CMD=docker compose up -d --build"
    assert_log_not_contains "$log_file" "docker-compose"
}

compose_v1_is_rejected() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    unset STUB_DOCKER_COMPOSE_VERSION
    export STUB_DOCKER_COMPOSE_VERSION_EXIT=1
    export STUB_DOCKER_COMPOSE_LEGACY_VERSION="Docker Compose version v1.29.2"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    run_cmd "$tmp_dir/host/sandbox" up --mount-root "$root" --workdir "$root"
    if [[ "$RUN_CODE" -eq 0 ]]; then
        echo "Expected docker-compose v1 rejection" >&2
        return 1
    fi
}

tz_injection_rules() {
    # Case A: TZ env set (should be respected)
    local tmp_dir_a
    tmp_dir_a="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir_a"
    local log_file_a="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"
    local root_a="$tmp_dir_a/project"
    setup_env_for_up "$tmp_dir_a" "$root_a" "$root_a"
    TZ="Europe/Paris" run_cmd "$tmp_dir_a/host/sandbox" up --mount-root "$root_a" --workdir "$root_a"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file_a" "TZ=Europe/Paris"

    # Case B: .env has TZ=America/New_York (should not inject)
    local tmp_dir_b
    tmp_dir_b="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir_b"
    local log_file_b="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"
    local root_b="$tmp_dir_b/project"
    setup_env_for_up "$tmp_dir_b" "$root_b" "$root_b"
    echo "TZ=America/New_York" > "$tmp_dir_b/.env"
    run_cmd "$tmp_dir_b/host/sandbox" up --mount-root "$root_b" --workdir "$root_b"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_not_contains "$log_file_b" "TZ="

    # Case C: .env has TZ= (empty) => inject non-empty TZ
    local tmp_dir_c
    tmp_dir_c="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir_c"
    local log_file_c="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"
    local root_c="$tmp_dir_c/project"
    setup_env_for_up "$tmp_dir_c" "$root_c" "$root_c"
    echo "TZ=" > "$tmp_dir_c/.env"
    run_cmd "$tmp_dir_c/host/sandbox" up --mount-root "$root_c" --workdir "$root_c"
    assert_exit_code 0 "$RUN_CODE"
    local tz_line
    tz_line="$(grep -F "TZ=" "$log_file_c" | tail -n1)"
    if [[ "$tz_line" == "TZ=" || -z "$tz_line" ]]; then
        echo "Expected non-empty TZ injection" >&2
        return 1
    fi
}

config_env_var_noise_is_not_present() {
    local dockerfile="$REPO_ROOT/Dockerfile"
    local compose_file="$REPO_ROOT/docker-compose.yml"

    local failures=0

    local dockerfile_tokens=(
        "ENV CODEX_CONFIG_DIR="
        "ENV GEMINI_CONFIG_DIR="
        "ENV OPENCODE_CONFIG_DIR="
        "ENV OPENCODE_DATA_DIR="
        "ENV OPENCODE_CACHE_DIR="
        "ENV DEVCONTAINER="
        "ENV TMUX_SESSION_NAME="
        "ENV DOCKER_CONFIG="
        "ENV DOCKER_HOST="
    )

    local compose_tokens=(
        "CLAUDE_CONFIG_DIR="
        "CODEX_CONFIG_DIR="
        "GEMINI_CONFIG_DIR="
        "OPENCODE_CONFIG_DIR="
        "OPENCODE_DATA_DIR="
        "OPENCODE_CACHE_DIR="
        "HOST_SANDBOX_PATH="
        "HOST_USERNAME="
        "HOST_PRODUCT_PATH="
        "PRODUCT_NAME="
        "PRODUCT_WORK_DIR="
        "DOCKER_HOST="
        "DEVCONTAINER="
    )

    for token in "${dockerfile_tokens[@]}"; do
        if grep -nF "$token" "$dockerfile" >/dev/null 2>&1; then
            echo "Unexpected token in Dockerfile: $token" >&2
            grep -nF "$token" "$dockerfile" >&2 || true
            failures=$((failures + 1))
        fi
    done

    for token in "${compose_tokens[@]}"; do
        if grep -nF "$token" "$compose_file" >/dev/null 2>&1; then
            echo "Unexpected token in docker-compose.yml: $token" >&2
            grep -nF "$token" "$compose_file" >&2 || true
            failures=$((failures + 1))
        fi
    done

    if [[ "$failures" -ne 0 ]]; then
        return 1
    fi
}

shell_exec_w() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    local workdir="$root/subdir"
    setup_env_for_up "$tmp_dir" "$root" "$workdir"

    run_cmd "$tmp_dir/host/sandbox" shell --mount-root "$root" --workdir "$workdir"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "CMD=docker compose up -d --build"
    assert_log_contains "$log_file" "CMD=docker compose exec -w /srv/mount/subdir agent-sandbox /bin/zsh"
}

shell_injects_dod_env_vars() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    run_cmd "$tmp_dir/host/sandbox" name --mount-root "$root" --workdir "$root"
    local expected_name="$RUN_STDOUT"
    local expected_compose_name
    expected_compose_name="$(compute_expected_compose_name "$tmp_dir" "$root" "$root")"

    run_cmd "$tmp_dir/host/sandbox" shell --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains_after "$log_file" "CMD=docker compose exec -w /srv/mount" "CONTAINER_NAME=$expected_name"
    assert_log_contains_after "$log_file" "CMD=docker compose exec -w /srv/mount" "COMPOSE_PROJECT_NAME=$expected_compose_name"
    assert_log_contains_after "$log_file" "CMD=docker compose exec -w /srv/mount" "SOURCE_PATH=$(realpath "$root")"
    assert_log_contains_after "$log_file" "CMD=docker compose exec -w /srv/mount" "PRODUCT_WORK_DIR=/srv/mount"
    assert_log_contains_after "$log_file" "CMD=docker compose exec -w /srv/mount" "HOST_SANDBOX_PATH=$(realpath "$tmp_dir")"
    assert_log_contains_after "$log_file" "CMD=docker compose exec -w /srv/mount" "HOST_USERNAME=$(whoami)"
    assert_log_contains_after "$log_file" "CMD=docker compose exec -w /srv/mount" "PRODUCT_NAME=mount"
}

shell_trusts_git_repo_root_for_codex() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/mount-root"
    local repo_root="$root/repo"
    local workdir="$repo_root/subdir"
    setup_env_for_up "$tmp_dir" "$root" "$workdir"

    cat > "$COMPOSE_STUB_DIR/git" <<'STUB'
#!/bin/bash
set -euo pipefail

if [[ "${1:-}" == "-C" && "${3:-}" == "rev-parse" && "${4:-}" == "--show-toplevel" ]]; then
    printf '%s\n' "${STUB_GIT_TOPLEVEL:?}"
    exit 0
fi

exit 1
STUB
    chmod +x "$COMPOSE_STUB_DIR/git"
    export STUB_GIT_TOPLEVEL="$repo_root"
    hash -r

    run_cmd "$tmp_dir/host/sandbox" shell --mount-root "$root" --workdir "$workdir"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "CMD=docker compose exec -w /srv/mount/repo/subdir agent-sandbox /bin/zsh"

    local codex_config="$tmp_dir/.agent-home/.codex/config.toml"
    if [[ ! -f "$codex_config" ]]; then
        echo "Expected Codex config.toml to be created: $codex_config" >&2
        return 1
    fi
    if ! grep -Fq '"/srv/mount/repo"' "$codex_config"; then
        echo "Expected Codex config.toml to trust repo root: /srv/mount/repo" >&2
        echo "--- config.toml ---" >&2
        cat "$codex_config" >&2
        return 1
    fi
}

default_shell_ignores_option_value() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    local workdir="$root/up"
    setup_env_for_up "$tmp_dir" "$root" "$workdir"

    run_cmd "$tmp_dir/host/sandbox" --mount-root "$root" --workdir "$workdir"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "CMD=docker compose exec -w /srv/mount/up agent-sandbox /bin/zsh"
}

compose_project_name_is_safe() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/My.Project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    local expected_compose_name
    expected_compose_name="$(compute_expected_compose_name "$tmp_dir" "$root" "$root")"

    run_cmd "$tmp_dir/host/sandbox" up --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "COMPOSE_PROJECT_NAME=$expected_compose_name"
    if ! echo "$expected_compose_name" | grep -Eq '^sandbox-[a-z0-9_-]+-[0-9a-f]{12}$'; then
        echo "Expected compose project name to be lowercase and safe: $expected_compose_name" >&2
        return 1
    fi
}

build_only() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"
    rm -f "$tmp_dir/.env"
    rm -rf "$tmp_dir/.agent-home"

    run_cmd "$tmp_dir/host/sandbox" build --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "CMD=docker compose build --no-cache"
    assert_log_not_contains "$log_file" "CMD=docker compose up"
    assert_log_not_contains "$log_file" "CMD=docker compose exec"
    if [[ ! -f "$tmp_dir/.env" ]]; then
        echo ".env should be created for build" >&2
        return 1
    fi
    if [[ ! -d "$tmp_dir/.agent-home/.claude" ]]; then
        echo ".agent-home should be created for build" >&2
        return 1
    fi
}

build_no_cache() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    run_cmd "$tmp_dir/host/sandbox" build --no-cache --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "CMD=docker compose build --no-cache"
}

build_cache() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    run_cmd "$tmp_dir/host/sandbox" build --cache --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "CMD=docker compose build"
    assert_log_not_contains "$log_file" "CMD=docker compose build --no-cache"
}

tools_update_runs_compose() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    run_cmd "$tmp_dir/host/sandbox" name --mount-root "$root" --workdir "$root"
    local expected_name="$RUN_STDOUT"
    local expected_compose_name
    expected_compose_name="$(compute_expected_compose_name "$tmp_dir" "$root" "$root")"

    local lock_dir="$tmp_dir/tools-update.lock"
    PATH="$PATH" run_cmd env SANDBOX_TOOLS_UPDATE_LOCK_DIR="$lock_dir" \
        "$tmp_dir/host/sandbox" tools update --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "CMD=docker compose run"
    assert_log_contains "$log_file" "install-global"
    assert_log_contains "$log_file" "CONTAINER_NAME=${expected_name}-tools-update"
    assert_log_contains "$log_file" "COMPOSE_PROJECT_NAME=$expected_compose_name"
    assert_log_not_contains "$log_file" "CMD=docker compose build"
    assert_log_not_contains "$log_file" "CMD=docker compose up"
    assert_log_not_contains "$log_file" "CMD=docker compose exec"
}

tools_update_locking() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    local lock_dir="$tmp_dir/tools-update.lock"
    mkdir -p "$lock_dir"

    PATH="$PATH" run_cmd env SANDBOX_TOOLS_UPDATE_LOCK_DIR="$lock_dir" \
        "$tmp_dir/host/sandbox" tools update --mount-root "$root" --workdir "$root"

    if [[ "$RUN_CODE" -eq 0 ]]; then
        echo "Expected tools update to fail when lock exists" >&2
        return 1
    fi
    assert_stderr_contains "Another tools update is in progress" "$RUN_STDERR"
    assert_log_not_contains "$log_file" "CMD="
}

stop_down_idempotent() {
    # Case A: target not found => no-op
    local tmp_dir_a
    tmp_dir_a="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir_a"
    local log_file_a="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"
    export STUB_DOCKER_INSPECT_EXIT=1

    local root_a="$tmp_dir_a/project"
    setup_env_for_up "$tmp_dir_a" "$root_a" "$root_a"

    run_cmd "$tmp_dir_a/host/sandbox" stop --mount-root "$root_a" --workdir "$root_a"
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "No matching sandbox container" "$RUN_STDOUT"
    assert_log_not_contains "$log_file_a" "CMD="
    assert_no_files_created "$tmp_dir_a"

    : > "$log_file_a"
    run_cmd "$tmp_dir_a/host/sandbox" down --mount-root "$root_a" --workdir "$root_a"
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "No matching sandbox container" "$RUN_STDOUT"
    assert_log_not_contains "$log_file_a" "CMD="
    assert_no_files_created "$tmp_dir_a"

    # Case B: target exists => compose stop/down with env injection
    local tmp_dir_b
    tmp_dir_b="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir_b"
    local log_file_b="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"
    export STUB_DOCKER_INSPECT_EXIT=0

    local root_b="$tmp_dir_b/project"
    setup_env_for_up "$tmp_dir_b" "$root_b" "$root_b"

    run_cmd "$tmp_dir_b/host/sandbox" name --mount-root "$root_b" --workdir "$root_b"
    local expected_name="$RUN_STDOUT"
    local expected_compose_name
    expected_compose_name="$(compute_expected_compose_name "$tmp_dir_b" "$root_b" "$root_b")"

    run_cmd "$tmp_dir_b/host/sandbox" stop --mount-root "$root_b" --workdir "$root_b"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file_b" "CMD=docker compose stop"
    assert_log_contains "$log_file_b" "CONTAINER_NAME=$expected_name"
    assert_log_contains "$log_file_b" "COMPOSE_PROJECT_NAME=$expected_compose_name"
    if [[ ! -f "$tmp_dir_b/.env" || ! -d "$tmp_dir_b/.agent-home/.claude" ]]; then
        echo "Expected .env and .agent-home to be created for stop" >&2
        return 1
    fi

    : > "$log_file_b"
    run_cmd "$tmp_dir_b/host/sandbox" down --mount-root "$root_b" --workdir "$root_b"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file_b" "CMD=docker compose down"
    assert_log_contains "$log_file_b" "CONTAINER_NAME=$expected_name"
    assert_log_contains "$log_file_b" "COMPOSE_PROJECT_NAME=$expected_compose_name"
}

status_output_keys() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_INSPECT_EXIT=0
    export STUB_DOCKER_INSPECT_STATUS="running"
    export STUB_DOCKER_INSPECT_ID="1234567890abcdef"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    run_cmd "$tmp_dir/host/sandbox" status --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_not_contains "$log_file" "CMD="
    local status_out="$RUN_STDOUT"

    local expected_name
    run_cmd "$tmp_dir/host/sandbox" name --mount-root "$root" --workdir "$root"
    expected_name="$RUN_STDOUT"

    assert_stdout_contains "container_name: $expected_name" "$status_out"
    assert_stdout_contains "status: running" "$status_out"
    assert_stdout_contains "container_id: 1234567890ab" "$status_out"
    assert_stdout_contains "mount_root: $(realpath "$root")" "$status_out"
    assert_stdout_contains "workdir: $(realpath "$root")" "$status_out"

    local key
    for key in container_name status container_id mount_root workdir; do
        local count
        count="$(printf '%s\n' "$status_out" | grep -c "^${key}: ")"
        if [[ "$count" -ne 1 ]]; then
            echo "Expected exactly one ${key} line" >&2
            return 1
        fi
    done
}

status_not_found_vs_docker_error() {
    # Case A: not found
    local tmp_dir_a
    tmp_dir_a="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir_a"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_INSPECT_EXIT=1

    local root_a="$tmp_dir_a/project"
    setup_env_for_up "$tmp_dir_a" "$root_a" "$root_a"

    run_cmd "$tmp_dir_a/host/sandbox" status --mount-root "$root_a" --workdir "$root_a"
    assert_exit_code 0 "$RUN_CODE"
    assert_stdout_contains "status: not-found" "$RUN_STDOUT"
    assert_stdout_contains "container_id: -" "$RUN_STDOUT"

    # Case B: docker error
    local tmp_dir_b
    tmp_dir_b="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir_b"
    export STUB_DOCKER_INFO_EXIT=1
    export STUB_DOCKER_INSPECT_EXIT=0

    local root_b="$tmp_dir_b/project"
    setup_env_for_up "$tmp_dir_b" "$root_b" "$root_b"

    run_cmd "$tmp_dir_b/host/sandbox" status --mount-root "$root_b" --workdir "$root_b"
    if [[ "$RUN_CODE" -eq 0 ]]; then
        echo "Expected docker error for status" >&2
        return 1
    fi
}

status_has_no_side_effects() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_INSPECT_EXIT=1

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    run_cmd "$tmp_dir/host/sandbox" status --mount-root "$root" --workdir "$root"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_not_contains "$log_file" "CMD="
    assert_no_files_created "$tmp_dir"
}

codex_outer_uses_tmux_and_session_name() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    setup_tmux_stubs "$tmp_dir"
    local tmux_log="$tmp_dir/tmux.log"

    export STUB_TMUX_HAS_SESSION=0

    local base_dir="$tmp_dir/My.Project:One"
    mkdir -p "$base_dir"

    CALLER_PWD="$base_dir" run_cmd "$tmp_dir/host/sandbox" codex
    assert_exit_code 0 "$RUN_CODE"

    local expected_session="My_Project_One-codex-sandbox"
    assert_log_contains "$tmux_log" "has-session"
    assert_log_contains "$tmux_log" "new-session"
    assert_log_contains "$tmux_log" "=$expected_session"
    assert_log_contains "$tmux_log" "SANDBOX_CODEX_NO_TMUX=1"
    assert_log_contains "$tmux_log" "$tmp_dir/host/sandbox"
    assert_log_not_contains "$COMPOSE_LOG_FILE" "CMD="
    assert_no_files_created "$tmp_dir"
}

codex_inner_runs_codex_resume_and_returns_to_zsh() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    local workdir="$root/subdir"
    setup_env_for_up "$tmp_dir" "$root" "$workdir"

    SANDBOX_CODEX_NO_TMUX=1 run_cmd "$tmp_dir/host/sandbox" codex --mount-root "$root" --workdir "$workdir" -- --workdir up
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "CMD=docker compose up -d --build"
    assert_log_contains "$log_file" "CMD=docker compose exec -w /srv/mount/subdir"
    assert_log_contains "$log_file" "codex"
    assert_log_contains "$log_file" "resume"
    assert_log_contains "$log_file" "exec\\ /bin/zsh"
    assert_log_contains "$log_file" "--workdir"
    assert_log_contains "$log_file" "up"
}

codex_inner_without_double_dash_uses_default_args() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    local workdir="$root/subdir"
    setup_env_for_up "$tmp_dir" "$root" "$workdir"

    SANDBOX_CODEX_NO_TMUX=1 run_cmd "$tmp_dir/host/sandbox" codex --mount-root "$root" --workdir "$workdir"
    assert_exit_code 0 "$RUN_CODE"
    assert_log_contains "$log_file" "CMD=docker compose up -d --build"
    assert_log_contains "$log_file" "CMD=docker compose exec -w /srv/mount/subdir"
    assert_log_contains "$log_file" "codex"
    assert_log_contains "$log_file" "resume"
    assert_log_contains "$log_file" "exec\\ /bin/zsh"
}

codex_help_flag_after_double_dash_is_passed_to_codex() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    setup_compose_stubs "$tmp_dir"
    local log_file="$COMPOSE_LOG_FILE"
    export STUB_DOCKER_INFO_EXIT=0
    export STUB_DOCKER_COMPOSE_VERSION="Docker Compose version v2.20.0"

    local root="$tmp_dir/project"
    setup_env_for_up "$tmp_dir" "$root" "$root"

    SANDBOX_CODEX_NO_TMUX=1 run_cmd "$tmp_dir/host/sandbox" codex --mount-root "$root" --workdir "$root" -- --help
    assert_exit_code 0 "$RUN_CODE"
    if [[ "$RUN_STDOUT" == *"Usage: sandbox"* ]]; then
        echo "Sandbox help was printed unexpectedly" >&2
        return 1
    fi
    assert_log_contains "$log_file" "--help"
}

codex_errors_when_tmux_missing() {
    local tmp_dir
    tmp_dir="$(make_fake_sandbox_root)"
    local no_tmux_path
    no_tmux_path="$(path_without_docker)"

    PATH="$no_tmux_path" hash -r
    PATH="$no_tmux_path" run_cmd "$tmp_dir/host/sandbox" codex
    if [[ "$RUN_CODE" -eq 0 ]]; then
        echo "Expected tmux error for codex" >&2
        return 1
    fi
    assert_stderr_contains "tmux command not found" "$RUN_STDERR"
}

run_test "help_top_level" help_top_level
run_test "help_subcommand" help_subcommand
run_test "help_any_position" help_any_position
run_test "help_has_no_side_effects" help_has_no_side_effects
run_test "name_one_line_stdout" name_one_line_stdout
run_test "docker_cmd_missing_errors" docker_cmd_missing_errors
run_test "docker_daemon_unreachable_errors" docker_daemon_unreachable_errors
run_test "help_and_name_work_without_docker" help_and_name_work_without_docker
run_test "up_runs_compose_from_sandbox_root" up_runs_compose_from_sandbox_root
run_test "up_injects_required_env" up_injects_required_env
run_test "up_creates_empty_env_if_missing" up_creates_empty_env_if_missing
run_test "up_does_not_overwrite_existing_env" up_does_not_overwrite_existing_env
run_test "up_creates_agent_home_dirs" up_creates_agent_home_dirs
run_test "compose_command_selection_v2" compose_command_selection_v2
run_test "compose_v1_is_rejected" compose_v1_is_rejected
run_test "tz_injection_rules" tz_injection_rules
run_test "config_env_var_noise_is_not_present" config_env_var_noise_is_not_present
run_test "shell_exec_w" shell_exec_w
run_test "shell_injects_dod_env_vars" shell_injects_dod_env_vars
run_test "shell_trusts_git_repo_root_for_codex" shell_trusts_git_repo_root_for_codex
run_test "default_shell_ignores_option_value" default_shell_ignores_option_value
run_test "compose_project_name_is_safe" compose_project_name_is_safe
run_test "build_only" build_only
run_test "build_no_cache" build_no_cache
run_test "build_cache" build_cache
run_test "tools_update_runs_compose" tools_update_runs_compose
run_test "tools_update_locking" tools_update_locking
run_test "stop_down_idempotent" stop_down_idempotent
run_test "status_output_keys" status_output_keys
run_test "status_not_found_vs_docker_error" status_not_found_vs_docker_error
run_test "status_has_no_side_effects" status_has_no_side_effects
run_test "codex_outer_uses_tmux_and_session_name" codex_outer_uses_tmux_and_session_name
run_test "codex_inner_runs_codex_resume_and_returns_to_zsh" codex_inner_runs_codex_resume_and_returns_to_zsh
run_test "codex_inner_without_double_dash_uses_default_args" codex_inner_without_double_dash_uses_default_args
run_test "codex_help_flag_after_double_dash_is_passed_to_codex" codex_help_flag_after_double_dash_is_passed_to_codex
run_test "codex_errors_when_tmux_missing" codex_errors_when_tmux_missing
