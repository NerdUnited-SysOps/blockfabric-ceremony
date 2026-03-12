#!/usr/bin/env zsh
# Shared helpers for ansible-playbook invocations.
# Source this file; do not execute directly.

# Run ansible-playbook with output to both log and console.
#
# Usage: run_ansible_logged <log_file> [ansible-playbook args...]
run_ansible_logged() {
    local log_file="$1"
    shift

    ansible-playbook -v --forks 5 "$@" 2>&1 | stdbuf -oL tee -a "${log_file}"
    return ${pipestatus[1]}
}
