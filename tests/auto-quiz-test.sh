#!/bin/sh
# Tests for scripts/auto-quiz.sh. Run: sh tests/auto-quiz-test.sh
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/scripts/auto-quiz.sh"
data=$(mktemp -d)
trap 'rm -rf "$data"' EXIT
export CLAUDE_PLUGIN_DATA="$data"
fails=0

stop_json() { # session [extra fields]
  printf '{"session_id":"%s","hook_event_name":"Stop","stop_hook_active":false,"background_tasks":[]%s}' "$1" "${2:-}"
}

run() { # event json -> prints hook output
  printf '%s' "$2" | sh "$script" "$1"
}

check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (expected '$2', got '$3')"; fails=$((fails + 1)); fi
}

fired() { # event json -> yes/no
  case $(run "$1" "$2") in *vibe-quiz:quiz*) echo yes ;; *) echo no ;; esac
}

# turns: fires on the 3rd stop, then the counter resets
export CLAUDE_PLUGIN_OPTION_TRIGGER=turns CLAUDE_PLUGIN_OPTION_INTERVAL=3
check "turns: 1st stop" no "$(fired stop "$(stop_json s1)")"
check "turns: 2nd stop" no "$(fired stop "$(stop_json s1)")"
check "turns: 3rd stop fires" yes "$(fired stop "$(stop_json s1)")"
check "turns: counter reset" no "$(fired stop "$(stop_json s1)")"

# guards
export CLAUDE_PLUGIN_OPTION_INTERVAL=1
check "guard: stop_hook_active" no "$(fired stop '{"session_id":"s2","stop_hook_active":true,"background_tasks":[]}')"
check "guard: subagent" no "$(fired stop "$(stop_json s3 ',"agent_id":"a1"')")"
check "guard: background task" no "$(fired stop '{"session_id":"s4","stop_hook_active":false,"background_tasks":[{"id":"t1","type":"shell"}]}')"
check "guard: fires once background is done" yes "$(fired stop "$(stop_json s4)")"
check "guard: escaped text in message" yes "$(fired stop "$(stop_json s5 ',"last_assistant_message":"see \"agent_id\": x"')")"

# manual trigger never fires
export CLAUDE_PLUGIN_OPTION_TRIGGER=manual
check "manual: never fires" no "$(fired stop "$(stop_json s6)")"

# commits: only commits count, quiz still starts from Stop
export CLAUDE_PLUGIN_OPTION_TRIGGER=commits CLAUDE_PLUGIN_OPTION_INTERVAL=2
check "commits: stop without commits" no "$(fired stop "$(stop_json s7)")"
run commit '{"session_id":"s7","hook_event_name":"PostToolUse"}' >/dev/null
check "commits: 1 of 2" no "$(fired stop "$(stop_json s7)")"
run commit '{"session_id":"s7","hook_event_name":"PostToolUse"}' >/dev/null
check "commits: 2 of 2 fires" yes "$(fired stop "$(stop_json s7)")"

# pause
export CLAUDE_PLUGIN_OPTION_TRIGGER=turns CLAUDE_PLUGIN_OPTION_INTERVAL=1
sh "$script" pause "$data" s8 >/dev/null
check "pause: session" no "$(fired stop "$(stop_json s8)")"
sh "$script" pause "$data" s8 off >/dev/null
check "pause off: fires again" yes "$(fired stop "$(stop_json s8)")"
sh "$script" pause "$data" s9 2 >/dev/null
check "pause 2: 1st skipped" no "$(fired stop "$(stop_json s9)")"
check "pause 2: 2nd skipped" no "$(fired stop "$(stop_json s9)")"
check "pause 2: 3rd fires" yes "$(fired stop "$(stop_json s9)")"
check "pause: bad argument" "Usage: /vibe-quiz:pause [n|off]" "$(sh "$script" pause "$data" s9 abc)"

# robustness
check "no data dir: silent" "" "$(CLAUDE_PLUGIN_DATA='' run stop "$(stop_json s10)")"
check "unsafe session id is cleaned" yes "$(fired stop "$(stop_json '../../x')")"
if [ -f "$data/sessions/x.state" ]; then r=yes; else r=no; fi
check "state stays inside data dir" yes "$r"

echo
if [ "$fails" -ne 0 ]; then echo "$fails failed"; exit 1; fi
echo "all passed"
