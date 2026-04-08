# OWASP Security Review

Security review skill using OWASP frameworks with offline reference data.

Inspired by [agamm/claude-code-owasp](https://github.com/agamm/claude-code-owasp).

## Usage

Invoke explicitly with `/owasp` or ask for "OWASP review", "OWASP security review", "OWASP 安全審查".

Default: reviews against **Web Top 10:2025**. Specify a different project or year as needed.

## Coverage

| Project | Version | Reference Files |
|---------|---------|-----------------|
| Web Top 10 | 2017 (outline), 2021, 2025 | 20 files (2021+2025); 2017 outline only (no files) |
| API Security Top 10 | 2023 | 10 files |
| LLM Top 10 | v2.0 | 10 files |
| MCP Top 10 | 2025 | 10 files |
| Agentic Skills Top 10 | v1.0 | 10 files |
| Mobile Top 10 | 2023 | 10 files |
| CI/CD Security Top 10 | v1.0 | 10 files |
| Kubernetes Top 10 | 2025 | 10 files |
| CheatSheetSeries | current | Index only (113 entries, fetched on demand) |

## License

- Skill files (`SKILL.md`, `README.md`): MIT
- Original index files (`references/INDEX.md`, `references/cheatsheets-index.md`): MIT
- OWASP reference files in `references/top10-*/`: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), sourced from [OWASP GitHub repositories](https://github.com/OWASP)
- Mobile Top 10 (2023) references: assumed CC BY-SA 4.0 per OWASP convention (upstream repo has no explicit license file)
