#!/usr/bin/env python3
"""Exit 0 if the session still has background work pending, else exit 1.

Used by notify-claude-ready.sh to suppress "Claude ready" notifications on turns
where Claude is only waiting on background commands / agents / monitors / wakeups.

Usage: has_pending_background_work.py <transcript_path>
"""
import json
import re
import sys
import time
from datetime import datetime

# Ignore launches older than this — the task probably died with a previous process
# and will never send a completion notification.
MAX_TASK_AGE_SECONDS = 4 * 60 * 60

LAUNCH_MARKERS = (
    "Command running in background with ID",
    "Async agent launched successfully",
    "Monitor started",
)
NOTIFICATION_RE = re.compile(
    r"<task-notification>.*?<tool-use-id>(?P<id>[^<]+)</tool-use-id>.*?<status>(?P<status>\w+)</status>",
    re.S,
)
TERMINAL_STATUSES = {"completed", "failed", "stopped", "killed", "error", "cancelled"}


def parse_timestamp(entry):
    ts = entry.get("timestamp")
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def tool_result_blocks(entry):
    message = entry.get("message")
    if not isinstance(message, dict) or not isinstance(message.get("content"), list):
        return []
    return [b for b in message["content"] if isinstance(b, dict) and b.get("type") == "tool_result"]


def result_text(block):
    content = block.get("content")
    if isinstance(content, list):
        content = " ".join(c.get("text", "") for c in content if isinstance(c, dict))
    return (content or "").lstrip() if isinstance(content, str) else ""


def scheduled_wakeup_ids(entry):
    message = entry.get("message")
    if entry.get("type") != "assistant" or not isinstance(message, dict) or not isinstance(message.get("content"), list):
        return set()
    return {
        b.get("id") for b in message["content"]
        if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") == "ScheduleWakeup"
    }


def scan(transcript_path):
    launched = {}  # tool_use_id -> launch time
    finished = set()
    wakeup_ids = set()
    wakeup_at = None  # epoch seconds of the latest pending ScheduleWakeup

    with open(transcript_path) as f:
        for line in f:
            if "background" not in line and "notification" not in line and "wakeup" not in line.lower() \
                    and "Monitor" not in line and "ScheduleWakeup" not in line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            for m in NOTIFICATION_RE.finditer(line.replace("\\n", "\n")):
                if m.group("status").lower() in TERMINAL_STATUSES:
                    finished.add(m.group("id"))

            if entry.get("isSidechain"):
                continue

            for block in tool_result_blocks(entry):
                if result_text(block).startswith(LAUNCH_MARKERS):
                    launched[block.get("tool_use_id")] = parse_timestamp(entry) or time.time()

            wakeup_ids.update(scheduled_wakeup_ids(entry))
            if any(b.get("tool_use_id") in wakeup_ids for b in tool_result_blocks(entry)):
                tool_use_result = entry.get("toolUseResult")
                scheduled_for = tool_use_result.get("scheduledFor") if isinstance(tool_use_result, dict) else None
                wakeup_at = scheduled_for / 1000 if scheduled_for else None  # stop:true cancels

    return launched, finished, wakeup_at


def main():
    if len(sys.argv) < 2:
        sys.exit(1)
    try:
        launched, finished, wakeup_at = scan(sys.argv[1])
    except OSError:
        sys.exit(1)

    now = time.time()
    pending_tasks = [
        tid for tid, started in launched.items()
        if tid not in finished and now - started < MAX_TASK_AGE_SECONDS
    ]
    wakeup_pending = wakeup_at is not None and wakeup_at > now
    sys.exit(0 if pending_tasks or wakeup_pending else 1)


if __name__ == "__main__":
    main()
