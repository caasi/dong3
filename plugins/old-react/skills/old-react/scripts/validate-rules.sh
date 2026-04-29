#!/usr/bin/env bash
set -euo pipefail

# validate-rules.sh — verifies a rule file (or all rule files in rules/) has:
#   - YAML frontmatter with required keys: title, slug, category, impact, tags
#   - category in the closed set; impact in the closed set
#   - slug starts with category prefix and matches the filename basename
#   - body has the "## <title>" heading
#   - body has both **Incorrect** and **Correct** markers
#   - body has at least one balanced (open + close) fenced code block under
#     each of the **Incorrect** and **Correct** markers
#
# Usage:
#   validate-rules.sh <file.md>           # validate a single file
#   validate-rules.sh --all <rules-dir>   # validate every non-underscore file under rules/

ALLOWED_CATEGORIES="purity immutable model message effect hooks compose"
ALLOWED_IMPACTS="CRITICAL HIGH MEDIUM LOW"

die() { echo "FAIL: $1: $2" >&2; exit 1; }

# Extract a single YAML scalar (e.g. `slug: foo`) from a file's leading frontmatter.
# Prints the value to stdout (empty if the key is absent). Trailing YAML inline
# comments (whitespace then `#` to end of line) are stripped, matching the YAML
# 1.2 rule that `#` introduces a comment only when preceded by whitespace.
# Limitation: does not understand quoted strings — a `#` after whitespace inside
# `"foo # bar"` would still be treated as a comment.
extract_frontmatter_value() {
  local file="$1" key="$2"
  awk -v k="$key" '
    BEGIN { in_fm = 0 }
    NR == 1 && /^---$/ { in_fm = 1; next }
    in_fm && /^---$/ { in_fm = 0; exit }
    in_fm && $1 == k":" {
      sub(/^[^:]+:[[:space:]]*/, "")
      sub(/[[:space:]]+#.*$/, "")
      print; exit
    }
  ' "$file"
}

validate_file() {
  local file="$1"
  local base
  base="$(basename "$file" .md)"

  # 0. File exists and is readable. Without this, head/awk would fail under
  #    `set -e` with a generic system message instead of a structured FAIL.
  [ -f "$file" ] || die "$file" "file not found"

  # 1. Has frontmatter — opens with `---` on line 1 and closes with another
  #    `---` later. Without the close, extract_frontmatter_value would scan
  #    body lines as candidate keys and produce false passes.
  head -1 "$file" | grep -q '^---$' || die "$file" "missing frontmatter (no leading ---)"
  awk 'NR == 1 && /^---$/ { next } /^---$/ { found = 1; exit } END { exit !found }' "$file" \
    || die "$file" "missing frontmatter close (no second '---')"

  # 2. Required keys — extract each once; absent values fail fast.
  local title slug category impact tags
  title="$(extract_frontmatter_value "$file" title)"
  slug="$(extract_frontmatter_value "$file" slug)"
  category="$(extract_frontmatter_value "$file" category)"
  impact="$(extract_frontmatter_value "$file" impact)"
  tags="$(extract_frontmatter_value "$file" tags)"
  for key_value in "title:$title" "slug:$slug" "category:$category" "impact:$impact" "tags:$tags"; do
    [ -n "${key_value#*:}" ] || die "$file" "missing frontmatter key '${key_value%%:*}'"
  done

  # 3. category in allowed set
  echo "$ALLOWED_CATEGORIES" | tr ' ' '\n' | grep -qx "$category" \
    || die "$file" "category '$category' not in allowed set: $ALLOWED_CATEGORIES"

  # 4. impact in allowed set
  echo "$ALLOWED_IMPACTS" | tr ' ' '\n' | grep -qx "$impact" \
    || die "$file" "impact '$impact' not in allowed set: $ALLOWED_IMPACTS"

  # 5. slug starts with category prefix
  case "$slug" in
    "$category"-*) ;;
    *) die "$file" "slug '$slug' does not start with category prefix '$category-'" ;;
  esac

  # 6. slug matches filename basename
  [ "$slug" = "$base" ] || die "$file" "slug '$slug' does not match filename basename '$base'"

  # 7. Body has a real "## $title" H2 heading. Must be a heading line in
  #    body (not in frontmatter, not inside a code fence).
  awk -v t="## $title" '
    NR == 1 && /^---$/ { in_fm = 1; next }
    in_fm && /^---$/ { in_fm = 0; next }
    in_fm { next }
    /^```/ { in_fence = !in_fence; next }
    !in_fence && $0 == t { found = 1 }
    END { exit !found }
  ' "$file" || die "$file" "missing '## $title' heading in body (must be a real H2 outside fences)"

  # 8 + 9. Markers + per-section fence balance, in a single awk pass.
  #    Marker detection must skip both frontmatter and fenced code blocks,
  #    otherwise a code block containing the literal string **Incorrect**
  #    would be mistaken for a section marker. Fence balance must count
  #    completed open/close pairs (mere opener counting accepts unclosed
  #    fences and mis-attributes when a missing close happens to align with
  #    the next section's opener).
  local marker_check mi mc inc_fences cor_fences
  marker_check="$(awk '
    BEGIN { state = "pre"; opener_state = ""; in_fm = 0; in_fence = 0;
            mi = 0; mc = 0; inc = 0; cor = 0 }
    NR == 1 && /^---$/ { in_fm = 1; next }
    in_fm && /^---$/ { in_fm = 0; next }
    in_fm { next }
    /^```/ {
      if (in_fence) {
        if (opener_state == "inc") inc++
        else if (opener_state == "cor") cor++
        in_fence = 0; opener_state = ""
      } else {
        in_fence = 1; opener_state = state
      }
      next
    }
    in_fence { next }
    /\*\*Incorrect\*\*/ { mi = 1; state = "inc"; next }
    /\*\*Correct\*\*/   { mc = 1; state = "cor"; next }
    END {
      if (in_fence) print "unclosed_fence"
      else printf "%d %d %d %d\n", mi, mc, inc, cor
    }
  ' "$file")"
  if [ "$marker_check" = "unclosed_fence" ]; then
    die "$file" "unclosed fenced code block (missing closing \`\`\`)"
  fi
  read -r mi mc inc_fences cor_fences <<< "$marker_check"
  [ "$mi" = "1" ] || die "$file" "missing **Incorrect** marker (must appear in body, outside fences)"
  [ "$mc" = "1" ] || die "$file" "missing **Correct** marker (must appear in body, outside fences)"
  [ "$inc_fences" -ge 1 ] || die "$file" "no fenced code block under **Incorrect** section"
  [ "$cor_fences" -ge 1 ] || die "$file" "no fenced code block under **Correct** section"

  echo "OK: $file"
}

if [ "${1:-}" = "--all" ]; then
  rules_dir="${2:?--all requires a rules directory argument}"
  [ -d "$rules_dir" ] || die "$rules_dir" "rules directory not found (or not a directory)"
  found_any=0
  for f in "$rules_dir"/*.md; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
      _*) continue ;;
    esac
    found_any=1
    validate_file "$f"
  done
  [ "$found_any" -eq 1 ] || die "$rules_dir" "no rule files found"
else
  [ -n "${1:-}" ] || { echo "Usage: $0 <file.md> | --all <rules-dir>" >&2; exit 2; }
  validate_file "$1"
fi
