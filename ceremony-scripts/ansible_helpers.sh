#!/usr/bin/env zsh
# Shared helpers for ansible-playbook invocations.
# Source this file; do not execute directly.

# Filter ansible output for clean console display.
# Passes: PLAY/TASK headers, status lines, PLAY RECAP + host summaries.
# Suppresses: verbose connection/var/command detail from -vvv.
_ansible_console_filter() {
    awk '
    BEGIN { recap = 0 }
    {
        stripped = $0
        gsub(/\033\[[0-9;]*m/, "", stripped)
        gsub(/^[[:space:]]+/, "", stripped)
    }
    stripped == ""                          { print; fflush(); recap = 0; next }
    stripped ~ /^PLAY \[/                  { print; fflush(); recap = 0; next }
    stripped ~ /^TASK \[/                  { print; fflush(); recap = 0; next }
    stripped ~ /^(ok|changed|failed|fatal|skipping|included|unreachable|rescued|ignoring):/ {
                                             print; fflush(); next }
    stripped ~ /^PLAY RECAP/               { recap = 1; print; fflush(); next }
    recap                                  { print; fflush(); next }
    '
}

# Run ansible-playbook with split verbosity:
#   Log file  → full -vvv output (appended)
#   Console   → filtered progress lines only
#
# When VERBOSE_FLAG is set (-d mode), skip filter — full verbose on both.
#
# Usage: run_ansible_logged <log_file> [ansible-playbook args...]
run_ansible_logged() {
    local log_file="$1"
    shift

    if [[ -n "${VERBOSE_FLAG:-}" ]]; then
        ansible-playbook -vvv "$@" 2>&1 | tee -a "${log_file}"
        return ${pipestatus[1]}
    else
        ansible-playbook -vvv "$@" 2>&1 \
            | tee -a "${log_file}" \
            | _ansible_console_filter
        return ${pipestatus[1]}
    fi
}
