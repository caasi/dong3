---
name: owasp
description: >-
  Use when the user explicitly asks for an OWASP review, OWASP Top 10
  analysis, "/owasp", "check OWASP", "OWASP 安全審查", or "OWASP
  security review". Do not trigger automatically or on generic
  "security review" requests without OWASP context.
---

# OWASP Security Review

You are performing a security review using OWASP frameworks.

Inspired by [agamm/claude-code-owasp](https://github.com/agamm/claude-code-owasp).
Reference data sourced from [OWASP GitHub repositories](https://github.com/OWASP)
(CC BY-SA 4.0).

## Workflow

1. Read `references/INDEX.md` to see all available OWASP projects, quick reference tables, and the evolution map
2. Identify which projects and categories are relevant to the code under review
3. Read the specific reference files you need from `references/top10-*/`
4. For CheatSheetSeries remediation guidance, consult `references/cheatsheets-index.md` and fetch from upstream URLs as needed
5. Report findings with: severity, affected location, OWASP category, and remediation guidance

## Defaults

- Use **Web Top 10:2025** unless the user specifies a different version or project
- For pre-2017 Web Top 10, consult upstream: https://github.com/OWASP/Top10
- For full CheatSheet content, fetch from upstream URLs listed in `references/cheatsheets-index.md`

## Output Format

For each finding:
- **Category:** e.g., A01:2025 Broken Access Control
- **Severity:** Critical / High / Medium / Low / Info
- **Location:** file path and line range
- **Issue:** what is wrong
- **Remediation:** how to fix, with reference to relevant CheatSheet if applicable
