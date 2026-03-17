#!/usr/bin/env bash
# Minimal helper to call an OpenAI-compatible chat endpoint.
# Dependencies: curl only.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: chat.sh <endpoint> <prompt> [-s system] [-m model] [-k api_key] [-t timeout] [-T]

  endpoint   Base URL, e.g. http://localhost:1234/v1
  prompt     User message (use quotes for multi-word)
  -s         System prompt (default: "You are a helpful assistant.")
  -m         Model name (default: "any")
  -k         Bearer token (optional)
  -t         Timeout in seconds (default: 120)
  -T         Filter out thinking/reasoning output from response (requires jq)
EOF
  exit 1
}

[[ $# -lt 2 ]] && usage

ENDPOINT="${1%/}"; shift
PROMPT="$1"; shift

SYSTEM="You are a helpful assistant."
MODEL="any"
API_KEY=""
TIMEOUT=120
FILTER_THINKING=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) SYSTEM="$2"; shift 2 ;;
    -m) MODEL="$2"; shift 2 ;;
    -k) API_KEY="$2"; shift 2 ;;
    -t) TIMEOUT="$2"; shift 2 ;;
    -T) FILTER_THINKING=1; shift ;;
    *)  echo "Unknown option: $1" >&2; usage ;;
  esac
done

# Auto-append /chat/completions if needed
[[ "$ENDPOINT" != */chat/completions ]] && ENDPOINT="${ENDPOINT%/}/chat/completions"

# Escape strings for JSON embedding and wrap in quotes (pure sed/awk)
json_escape() {
  local escaped
  escaped=$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g' | awk '{printf "%s\\n", $0}' | sed '$ s/\\n$//')
  printf '"%s"' "$escaped"
}

BODY=$(cat <<ENDJSON
{"model":$(json_escape "$MODEL"),"messages":[{"role":"system","content":$(json_escape "$SYSTEM")},{"role":"user","content":$(json_escape "$PROMPT")}]}
ENDJSON
)

# Build curl args
CURL_ARGS=(-s -X POST "$ENDPOINT" -H "Content-Type: application/json" --max-time "$TIMEOUT" -d "$BODY")
[[ -n "$API_KEY" ]] && CURL_ARGS+=(-H "Authorization: Bearer $API_KEY")

RESPONSE=$(curl "${CURL_ARGS[@]}")

if [[ "$FILTER_THINKING" -eq 1 ]]; then
  if ! command -v jq &>/dev/null; then
    echo "Error: -T flag requires jq but it's not installed." >&2
    exit 1
  fi
  # Filter out thinking/reasoning fields from all providers:
  #   - reasoning_content (DeepSeek)
  #   - reasoning, reasoning_details (OpenRouter / OpenAI)
  #   - thinking_blocks (Anthropic via litellm)
  # Also strip <think>...</think> blocks from content (Qwen3)
  echo "$RESPONSE" | jq '
    if .choices then
      .choices |= map(
        if .message then
          .message |= (
            del(.reasoning_content, .reasoning, .reasoning_details, .thinking_blocks)
            | if .content then
                .content |= gsub("<think>(.|\n)*?</think>\n*"; "")
              else . end
          )
        else . end
      )
    else . end
  '
else
  echo "$RESPONSE"
fi
