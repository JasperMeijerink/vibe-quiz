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
check "guard: background task" no "$(fired stop '{"session_id":"s4","stop_hook_active":false,"background_tasks":[{"id":"t1","type":"shell"}]}')"
check "guard: fires once background is done" yes "$(fired stop "$(stop_json s4)")"
check "guard: escaped text in message" yes "$(fired stop "$(stop_json s5 ',"last_assistant_message":"see \"stop_hook_active\": true"')")"

# background work defers a due quiz, but at most until 2x the interval
export CLAUDE_PLUGIN_OPTION_INTERVAL=2
busy='{"session_id":"s11","stop_hook_active":false,"background_tasks":[{"id":"t1","type":"shell"}]}'
check "busy: 1 of 2" no "$(fired stop "$busy")"
check "busy: due but deferred" no "$(fired stop "$busy")"
check "busy: still deferred" no "$(fired stop "$busy")"
check "busy: fires at 2x interval" yes "$(fired stop "$busy")"
export CLAUDE_PLUGIN_OPTION_INTERVAL=1

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
sh "$script" pause "$data" s12 007 >/dev/null
check "pause 007 means 7" "pause=7" "$(grep pause= "$data/sessions/s12.state")"
check "pause huge number caps at 99" "Skipping the next 99 automatic quiz(zes)." "$(sh "$script" pause "$data" s12 99999999999999999999)"
check "pause: bad argument" "Usage: /vibe-quiz:pause [n|off]" "$(sh "$script" pause "$data" s9 abc)"

# robustness
mkdir -p "$data/sessions" && printf 'turns=08\ncommits=x\npause=007\n' >"$data/sessions/s13.state"
out=$(run stop "$(stop_json s13)" 2>&1 >/dev/null); code=$?
check "corrupt state: exit 0" 0 "$code"
if printf '%s' "$out" | grep -q .; then r=no; else r=yes; fi
check "corrupt state: nothing on stderr" yes "$r"
check "huge interval: no error" "" "$(CLAUDE_PLUGIN_OPTION_INTERVAL=99999999999999999999 run stop "$(stop_json s14)" 2>&1 >/dev/null)"
run stop '{"session_id":"s15","background_tasks":[],"x":{"session_id":"other"}}' >/dev/null
if [ -f "$data/sessions/s15.state" ] && [ ! -f "$data/sessions/other.state" ]; then r=yes; else r=no; fi
check "first session_id wins" yes "$r"
check "no data dir: silent" "" "$(CLAUDE_PLUGIN_DATA='' run stop "$(stop_json s10)")"
check "unsafe session id is cleaned" yes "$(fired stop "$(stop_json '../../x')")"
if [ -f "$data/sessions/x.state" ]; then r=yes; else r=no; fi
check "state stays inside data dir" yes "$r"

echo
if [ "$fails" -ne 0 ]; then echo "$fails failed"; exit 1; fi
echo "all passed"
