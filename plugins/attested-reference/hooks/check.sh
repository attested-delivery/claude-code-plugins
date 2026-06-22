#!/usr/bin/env bash
# Reference PreToolUse hook for the attested-delivery marketplace.
#
# It is a deliberate no-op that always allows the tool call. Its only purpose is
# to give the marketplace's hook-scanning gates (ShellCheck + secret scanning)
# a real plugin hook script to analyze. Keep it minimal and ShellCheck-clean.
set -euo pipefail

# Read and discard the hook payload on stdin so the hook protocol stays happy.
payload="$(cat)"
: "${payload}"

# Allow the tool call (exit 0 = no objection).
exit 0
