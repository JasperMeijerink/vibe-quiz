#!/bin/sh
# vibe-quiz: decides when an automatic quiz starts.
#
#   auto-quiz.sh stop                       Stop hook (hook JSON on stdin)
#   auto-quiz.sh commit                     PostToolUse hook for `git commit` (hook JSON on stdin)
#   auto-quiz.sh pause DATA_DIR SESSION [n|off]   called by the pause skill
#
# State is one small key=value file per session in DATA_DIR/sessions/, deleted
# after 7 days without activity.
# No dependencies beyond POSIX sh, sed and grep. Never fails loudly: on any
# problem it exits 0 and prints nothing, so a quiz is simply not started.

set -u

event=${1:-}

# --- state helpers -----------------------------------------------------------

state_file() { # data_dir session_id
  printf '%s/sessions/%s.state' "$1" "$2"
}

get() { # key  (reads $file)
  sed -n "s/^$1=//p" "$file" 2>/dev/null | head -n 1
}

is_num() { # small non-negative integer without leading zeros
  case $1 in '' | *[!0-9]* | 0?* | ?????*) return 1 ;; esac
}

save() { # writes $turns $commits $pause to $file
  mkdir -p "$(dirname "$file")" 2>/dev/null || return 1
  tmp="$file.$$"
  printf 'turns=%s\ncommits=%s\npause=%s\n' "$turns" "$commits" "$pause" >"$tmp" 2>/dev/null &&
    mv -f "$tmp" "$file" 2>/dev/null
}

load() {
  turns=$(get turns); commits=$(get commits); pause=$(get pause)
  is_num "$turns" || turns=0
  is_num "$commits" || commits=0
  case $pause in
    session) ;;
    *) { is_num "$pause" && [ "$pause" -ge 1 ] && [ "$pause" -le 99 ]; } || pause= ;;
  esac
}

clean_id() { # keep only safe filename characters
  printf '%s' "$1" | tr -cd 'A-Za-z0-9_-'
}

# --- pause (from the pause skill) ---------------------------------------------

if [ "$event" = pause ]; then
  data=${2:-}; sid=$(clean_id "${3:-}"); arg=${4:-}
  if [ -z "$data" ] || [ -z "$sid" ]; then
    echo "vibe-quiz: couldn't find this session's state, so nothing was paused."
    exit 0
  fi
  file=$(state_file "$data" "$sid")
  load
  case $arg in
    '') pause=session; msg="Automatic quizzes paused for this session. /vibe-quiz:pause off resumes them." ;;
    off) pause=; msg="Automatic quizzes resumed." ;;
    *[!0-9]*) echo "Usage: /vibe-quiz:pause [n|off]"; exit 0 ;;
    *) arg=$(printf '%s' "$arg" | sed 's/^0*//')
       case $arg in
         '') echo "Usage: /vibe-quiz:pause [n|off]"; exit 0 ;;
         ???*) arg=99 ;;
       esac
       pause=$arg; msg="Skipping the next $arg automatic quiz(zes)." ;;
  esac
  if ! save; then
    echo "vibe-quiz: couldn't save the pause setting."
    exit 0
  fi
  echo "$msg"
  exit 0
fi

# --- hooks -------------------------------------------------------------------

input=$(cat)
has() { printf '%s' "$input" | grep -Eq "$1"; }

data=${CLAUDE_PLUGIN_DATA:-}
[ -n "$data" ] || exit 0

sid=$(printf '%s' "$input" |
  grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 |
  sed 's/.*"\([^"]*\)"$/\1/')
sid=$(clean_id "$sid")
[ -n "$sid" ] || exit 0

trigger=${CLAUDE_PLUGIN_OPTION_TRIGGER:-turns}
interval=${CLAUDE_PLUGIN_OPTION_INTERVAL:-8}
interval=${interval%%.*}
is_num "$interval" || interval=8
[ "$interval" -lt 1 ] && interval=1
[ "$interval" -gt 50 ] && interval=50

case $trigger in turns | commits) ;; *) exit 0 ;; esac

file=$(state_file "$data" "$sid")
load

if [ "$event" = commit ]; then
  if [ "$trigger" = commits ]; then
    commits=$((commits + 1))
    save
  fi
  exit 0
fi

[ "$event" = stop ] || exit 0

# Delete the state of sessions untouched for 7 days (168 hours). This runs after
# every finished reply, so old files don't pile up while the plugin is in use.
find "$data/sessions" -type f -name '*.state*' -mmin +10080 -exec rm -f {} + 2>/dev/null

# Claude is already continuing because of a Stop hook (e.g. finishing a quiz).
has '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

if [ "$trigger" = turns ]; then
  turns=$((turns + 1))
  count=$turns
else
  count=$commits
fi

if [ "$count" -lt "$interval" ]; then
  save
  exit 0
fi

# Due. Wait for a calmer moment, but not forever (a dev server can stay listed
# all session): while background work runs, while a /loop is scheduled, or when
# Claude's last reply asked the user something.
busy() {
  has '"background_tasks"[[:space:]]*:[[:space:]]*\[[[:space:]]*\{' ||
    has '"session_crons"[[:space:]]*:[[:space:]]*\[[[:space:]]*\{' ||
    has '"last_assistant_message"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*\?([[:space:]]|\\n)*"'
}
if [ "$count" -lt $((interval * 2)) ] && busy; then
  save
  exit 0
fi

turns=0
commits=0

case $pause in
  session) save; exit 0 ;;
  '') ;;
  *) pause=$((pause - 1)); [ "$pause" -eq 0 ] && pause=; save; exit 0 ;;
esac

save

printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"vibe-quiz: a quiz is due. Run the vibe-quiz:quiz skill with --auto and follow it to the end. If it is denied or unavailable, stop without comment."}}'
exit 0
