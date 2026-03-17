# Filter out thinking/reasoning fields from all providers:
#   - reasoning_content (DeepSeek)
#   - reasoning, reasoning_details (OpenRouter / OpenAI)
#   - thinking_blocks (Anthropic via litellm)
# Also strip thinking blocks from content:
#   - <think>...</think> (Qwen3)
#   - <analysis>...</analysis> (some distilled models)
if .choices then
  .choices |= map(
    if .message then
      .message |= (
        del(.reasoning_content, .reasoning, .reasoning_details, .thinking_blocks)
        | if .content then
            .content |= gsub("<think>(.|\n)*?</think>\n*"; "")
            | .content |= gsub("<analysis>(.|\n)*?</analysis>\n*"; "")
          else . end
      )
    else . end
  )
else . end
