#!/bin/bash
# Notify (Linux, libnotify) when Claude finishes a turn and is ready for input.
# Wire to the `Stop` event. Shows the current project (working-dir basename).
# Stays quiet on turns where Claude is only waiting on background work
# (background commands, async agents, monitors, /loop wakeups) — see
# has_pending_background_work.py, which must sit next to this script.

read -r hook_input
transcript_path=$(echo "$hook_input" | jq -r '.transcript_path // ""' 2>/dev/null)

checker="$(dirname "$0")/has_pending_background_work.py"
if [ -n "$transcript_path" ] && [ -f "$checker" ] && python3 "$checker" "$transcript_path"; then
  exit 0
fi

dir_name=$(basename "$(pwd)")
message="Project: $dir_name"
title="Claude ready"

if command -v notify-send >/dev/null 2>&1; then
  notify-send --app-name="Claude Code" --icon=dialog-information "$title" "$message" 2>/dev/null || true
fi

sound=/usr/share/sounds/freedesktop/stereo/message-new-instant.oga
if command -v paplay >/dev/null 2>&1 && [ -f "$sound" ]; then
  paplay "$sound" 2>/dev/null &
fi

exit 0
