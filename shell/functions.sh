# shellcheck shell=bash
# agent-pairing-kit shell helpers. Source from ~/.bashrc:
#   [ -f ~/agent-pairing-kit/shell/functions.sh ] && . ~/agent-pairing-kit/shell/functions.sh
#
#   newproj <name> [profile]  create ~/code/<name> with the kit and open it in Cursor.
#                             profile: go (default), python, web, fullstack, fullstack python, expo
#   setreviewer cursor [model]  review with Cursor's CLI agent on your Cursor plan
#   setreviewer openai          review with the OpenAI API key saved by setkey
#   setkey [model]        prompt for an OpenAI key (hidden), verify it, save it for reviews
#   keystatus             show the active reviewer and verify it, without printing any key
#   kitaudit              check tool versions, review models and Cursor flags for drift
#   kitsync               refresh ~/agent-pairing-kit from the Windows copy on E:

PAIRING_KIT_HOME="${PAIRING_KIT_HOME:-$HOME/agent-pairing-kit}"
PAIRING_KIT_SOURCE="${PAIRING_KIT_SOURCE:-/mnt/e/Code/agent-pairing-kit}"
PAIRING_KIT_ENV="${PAIRING_KIT_ENV:-$HOME/.config/pairing-kit.env}"
PAIRING_CODE_DIR="${PAIRING_CODE_DIR:-$HOME/code}"

kitsync() {
  if [ ! -d "$PAIRING_KIT_SOURCE" ]; then
    echo "kitsync: $PAIRING_KIT_SOURCE not found; using existing $PAIRING_KIT_HOME" >&2
    return 0
  fi
  # When the source is a git clone, pull first so changes pushed to GitHub arrive. A failed pull
  # (offline, local edits) only warns; the copy still uses what is on disk.
  if [ -d "$PAIRING_KIT_SOURCE/.git" ]; then
    if ! timeout 30 git -C "$PAIRING_KIT_SOURCE" pull -q --ff-only </dev/null 2>/dev/null; then
      echo "kitsync: couldn't pull from GitHub (offline or local changes); using the copy on disk" >&2
    fi
  fi
  local tmp="${PAIRING_KIT_HOME}.new"
  rm -rf "$tmp" && cp -r "$PAIRING_KIT_SOURCE" "$tmp" && rm -rf "$PAIRING_KIT_HOME" && mv "$tmp" "$PAIRING_KIT_HOME" \
    && echo "kitsync: refreshed $PAIRING_KIT_HOME"
}

# Public entry point: sync the kit, reload these helpers from the fresh copy, then run the
# newest implementation. This way an already-open shell never runs stale logic.
newproj() {
  kitsync || return 1
  if [ -f "$PAIRING_KIT_HOME/shell/functions.sh" ]; then
    # shellcheck source=/dev/null
    . "$PAIRING_KIT_HOME/shell/functions.sh"
  fi
  _newproj_main "$@"
}

_newproj_main() {
  local usage="usage: newproj <name> [go|python|web|fullstack [python]|expo]   (default: go)"
  local name="${1:-}"
  case "$name" in
    ""|-h|--help) echo "$usage" >&2; return 1 ;;
    go|python|web|fullstack|expo)
      echo "newproj: the first argument is the project name, e.g. newproj my-app $name" >&2
      return 1 ;;
  esac
  if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "newproj: name must be lowercase letters, digits and dashes" >&2
    echo "$usage" >&2
    return 1
  fi
  shift
  local path="$PAIRING_CODE_DIR/$name"
  if [ -e "$path" ]; then
    echo "newproj: $path already exists" >&2
    return 1
  fi
  mkdir -p "$PAIRING_CODE_DIR"
  _kitaudit_weekly
  bash "$PAIRING_KIT_HOME/new-project.sh" "$path" "$@" || return 1
  cd "$path" || return 1
  if command -v cursor >/dev/null 2>&1; then
    cursor .
  else
    echo "newproj: 'cursor' not on PATH; open $path in Cursor manually" >&2
  fi
  echo "Next, in Cursor's terminal: claude  ->  /ide  ->  /mcp (only IDE on)  ->  /status"
}

kitaudit() {
  bash "$PAIRING_KIT_HOME/kit-audit.sh" "$@"
}

# Internal: run kitaudit quietly (warnings only) at most once a week, from newproj.
_kitaudit_weekly() {
  local stamp="${XDG_CACHE_HOME:-$HOME/.cache}/pairing-kit-audit.stamp"
  if [ -f "$stamp" ] && [ -z "$(find "$stamp" -mtime +6 2>/dev/null)" ]; then return 0; fi
  mkdir -p "$(dirname "$stamp")" && touch "$stamp"
  local out
  out=$(bash "$PAIRING_KIT_HOME/kit-audit.sh" --quiet 2>/dev/null)
  if [ -n "$out" ]; then
    echo "kitaudit: the weekly check found drift (full report: kitaudit)"
    printf '%s\n' "$out"
  fi
}

# Internal: HTTP status for GET /v1/models/<model> with the given key. Never prints the key.
_pairing_probe() {
  local key="$1" model="$2" base="${OPENAI_BASE_URL:-https://api.openai.com}"
  curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
    -H "Authorization: Bearer $key" "$base/v1/models/$model"
}

_pairing_explain() {
  case "$1" in
    200) echo "OK" ;;
    401) echo "key rejected (401): wrong, revoked, or mistyped" ;;
    403) echo "forbidden (403): key lacks Models read permission, or the model is blocked for this project" ;;
    404) echo "model not found (404): check the model name" ;;
    000) echo "no response: network problem" ;;
    *)   echo "unexpected HTTP $1" ;;
  esac
}

# Internal: set NAME VALUE pairs in the env file, keeping every other line. Backs up to .prev.
_pairing_env_set() {
  mkdir -p "$(dirname "$PAIRING_KIT_ENV")"
  local tmp="$PAIRING_KIT_ENV.tmp" names=""
  local args=("$@") i
  for ((i = 0; i < ${#args[@]}; i += 2)); do names="$names|${args[i]}"; done
  names="${names#|}"
  (
    umask 077
    if [ -f "$PAIRING_KIT_ENV" ]; then
      cp -p "$PAIRING_KIT_ENV" "$PAIRING_KIT_ENV.prev"
      grep -vE "^export ($names)=" "$PAIRING_KIT_ENV" > "$tmp" || true
    else
      : > "$tmp"
    fi
    for ((i = 0; i < ${#args[@]}; i += 2)); do
      printf "export %s='%s'\n" "${args[i]}" "${args[i+1]}" >> "$tmp"
    done
    mv "$tmp" "$PAIRING_KIT_ENV"
  )
  chmod 600 "$PAIRING_KIT_ENV"
  # shellcheck source=/dev/null
  . "$PAIRING_KIT_ENV"
}

_pairing_cursor_bin() {
  if [ -n "${CURSOR_AGENT_BIN:-}" ]; then echo "$CURSOR_AGENT_BIN"
  elif command -v agent >/dev/null 2>&1; then echo agent
  elif command -v cursor-agent >/dev/null 2>&1; then echo cursor-agent
  fi
}

# Internal: 0 if the Cursor CLI is installed and signed in. Prints the reason otherwise.
_pairing_cursor_ready() {
  local bin out
  bin=$(_pairing_cursor_bin)
  if [ -z "$bin" ]; then
    echo "Cursor CLI not installed. Install it: curl https://cursor.com/install -fsS | bash"
    return 1
  fi
  if ! out=$(timeout 30 "$bin" status </dev/null 2>&1); then
    echo "'$bin status' failed: ${out:-no output}. Sign in: NO_OPEN_BROWSER=1 $bin login"
    return 1
  fi
  if printf '%s' "$out" | grep -qiE 'not (logged|signed) in|logged out|unauthenticated|not authenticated|login required'; then
    echo "not signed in. Run: NO_OPEN_BROWSER=1 $bin login"
    return 1
  fi
}

# Internal: model IDs from `agent models` output on stdin, one per line. IDs, not display names:
# tokens like grok-4.7-high (lowercase, contain a dash, no spaces).
_pairing_model_ids() {
  tr -s ' \t,()[]*:' '\n' | grep -E '^[a-z0-9][a-z0-9._]*-[a-z0-9._-]*[a-z0-9]$' | awk '!seen[$0]++'
}

setreviewer() {
  local provider="${1:-}" model="${2:-}" bin models reason ans
  case "$provider" in
    cursor)
      if ! reason=$(_pairing_cursor_ready); then echo "setreviewer: $reason" >&2; return 1; fi
      bin=$(_pairing_cursor_bin)
      models=$(timeout 30 "$bin" models </dev/null 2>&1) || { echo "setreviewer: '$bin models' failed: $models" >&2; return 1; }
      local ids=() id i
      while IFS= read -r id; do ids+=("$id"); done < <(printf '%s\n' "$models" | _pairing_model_ids)
      if [ "${#ids[@]}" -eq 0 ]; then
        printf '%s\n' "$models"
        echo "setreviewer: couldn't find any model IDs in the output above. Nothing saved." >&2
        return 1
      fi
      if [ -z "$model" ]; then
        echo "Models on your Cursor account. Pick one from a different provider than Claude:"
        for i in "${!ids[@]}"; do printf '  %2d) %s\n' "$((i + 1))" "${ids[i]}"; done
        read -rp "Number or exact ID: " model
        if [[ "$model" =~ ^[0-9]+$ ]] && [ "$model" -ge 1 ] && [ "$model" -le "${#ids[@]}" ]; then
          model="${ids[model - 1]}"
        fi
      fi
      [ -n "$model" ] || { echo "setreviewer: no model given. Nothing saved." >&2; return 1; }
      if ! printf '%s\n' "${ids[@]}" | grep -qxF -- "$model"; then
        echo "setreviewer: '$model' is not a model ID from '$bin models'. Use the exact ID, for example: ${ids[0]}" >&2
        echo "Nothing saved." >&2
        return 1
      fi
      case "$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')" in
        *claude*|*sonnet*|*opus*|*haiku*)
          read -rp "setreviewer: $model is a Claude model, the same family as your coding agent. Use it anyway? [y/N] " ans
          [[ "$ans" =~ ^[Yy] ]] || { echo "Nothing saved." >&2; return 1; } ;;
      esac
      _pairing_env_set REVIEW_PROVIDER cursor CURSOR_REVIEW_MODEL "$model"
      echo "setreviewer: reviews now use Cursor ($model) on your Cursor plan."
      if [ -n "${OPENAI_API_KEY:-}" ]; then echo "setreviewer: your OpenAI key stays as the fallback if a Cursor review fails."; fi
      ;;
    openai)
      [ -n "${OPENAI_API_KEY:-}" ] || { echo "setreviewer: no OpenAI key saved. Run setkey first." >&2; return 1; }
      _pairing_env_set REVIEW_PROVIDER openai
      echo "setreviewer: reviews now use the OpenAI API (${REVIEW_MODEL:-gpt-6.1-sol})."
      ;;
    *)
      echo "usage: setreviewer cursor [model]   |   setreviewer openai" >&2
      return 1 ;;
  esac
  echo "setreviewer: the next review uses this; no restart needed"
}

setkey() {
  local model="${1:-${REVIEW_MODEL:-gpt-6.1-sol}}" key code
  read -rsp "OpenAI API key (input hidden): " key; echo
  if [[ "$key" != sk-* || ${#key} -lt 40 ]]; then
    echo "setkey: that doesn't look like an OpenAI API key (expected sk-..., 40+ chars). Nothing saved." >&2
    return 1
  fi
  code=$(_pairing_probe "$key" "$model")
  if [ "$code" != "200" ]; then
    echo "setkey: verification failed: $(_pairing_explain "$code"). Nothing saved." >&2
    return 1
  fi
  # Keep a Cursor reviewer if one is set; the key then serves as its fallback.
  if [ "${REVIEW_PROVIDER:-}" = cursor ]; then
    _pairing_env_set OPENAI_API_KEY "$key" REVIEW_MODEL "$model"
  else
    _pairing_env_set OPENAI_API_KEY "$key" REVIEW_MODEL "$model" REVIEW_PROVIDER openai
  fi
  echo "setkey: saved key ending ...${key: -4} with model $model (previous settings in $(basename "$PAIRING_KIT_ENV").prev)"
  echo "setkey: the next review uses this key; no restart needed"
}

keystatus() {
  local active="${REVIEW_PROVIDER:-auto}" cursor_ok=1 openai_ok=1 code reason
  echo "keystatus: reviewer is $active"
  if [ "$active" = cursor ] || [ -n "${CURSOR_REVIEW_MODEL:-}" ]; then
    if ! reason=$(_pairing_cursor_ready); then
      echo "  cursor: $reason"
    elif [ -z "${CURSOR_REVIEW_MODEL:-}" ]; then
      echo "  cursor: signed in, but no review model. Run: setreviewer cursor"
    elif ! timeout 30 "$(_pairing_cursor_bin)" models </dev/null 2>/dev/null | _pairing_model_ids | grep -qxF -- "$CURSOR_REVIEW_MODEL"; then
      echo "  cursor: signed in, but '$CURSOR_REVIEW_MODEL' is not a model ID on your account. Run: setreviewer cursor"
    else
      echo "  cursor: signed in, model $CURSOR_REVIEW_MODEL: OK"
      cursor_ok=0
    fi
  fi
  if [ -n "${OPENAI_API_KEY:-}" ]; then
    code=$(_pairing_probe "$OPENAI_API_KEY" "${REVIEW_MODEL:-gpt-6.1-sol}")
    echo "  openai: key ...${OPENAI_API_KEY: -4}, model ${REVIEW_MODEL:-gpt-6.1-sol}: $(_pairing_explain "$code")"
    [ "$code" = "200" ] && openai_ok=0
  else
    echo "  openai: no key saved (setkey)"
  fi
  case "$active" in
    cursor) return "$cursor_ok" ;;
    openai) return "$openai_ok" ;;
    *) [ "$cursor_ok" = 0 ] || [ "$openai_ok" = 0 ] ;;
  esac
}
