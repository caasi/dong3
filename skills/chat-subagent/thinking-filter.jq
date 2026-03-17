# Filter out thinking/reasoning fields from all providers:
#   - reasoning_content (DeepSeek)
#   - reasoning, reasoning_details (OpenRouter / OpenAI)
#   - thinking_blocks (Anthropic via litellm)
# Also strip <think>...</think> blocks from content (Qwen3)
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
