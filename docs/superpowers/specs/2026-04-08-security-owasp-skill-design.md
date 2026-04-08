# Security Plugin — OWASP Skill Design

**Date:** 2026-04-08
**Plugin:** `security` (new, v0.1.0)
**Skill:** `owasp`

Inspired by [agamm/claude-code-owasp](https://github.com/agamm/claude-code-owasp). Reference data sourced from multiple OWASP GitHub repositories under CC BY-SA 4.0.

## Scope

A single skill (`owasp`) under a new `security` plugin. The skill provides OWASP security review guidance with offline reference data — no web search required for covered resources.

### In Scope

- **OWASP Web Top 10** — 2017 (outline only, no reference files), 2021, 2025
- **OWASP API Security Top 10** — 2023
- **OWASP LLM Top 10** — v2.0
- **OWASP MCP Top 10** — 2025
- **OWASP Agentic Skills Top 10** — current
- **OWASP Mobile Top 10** — 2023
- **OWASP CI/CD Security Top 10** — current
- **OWASP Kubernetes Top 10** — 2025
- **OWASP CheatSheetSeries** — index + upstream links only (113 cheat sheets, too large to embed)

### Out of Scope (future skills under same plugin)

- OWASP ASVS (Application Security Verification Standard)
- OWASP WSTG (Web Security Testing Guide)
- Language-specific secure coding patterns

## Trigger Conditions

Explicit invocation only:
- `/owasp`
- "OWASP review", "check OWASP", "安全審查", "security review"

No contextual/automatic triggering.

## Architecture

### SKILL.md (compact, ~30-40 lines)

Defines:
- Role: security reviewer using OWASP frameworks
- Behavior: read `INDEX.md` first → identify relevant projects/categories → read specific reference files
- Default to Web Top 10:2025 unless user specifies otherwise
- For pre-2017 Web Top 10 or full CheatSheet content, consult upstream repos
- Attribution block (agamm/claude-code-owasp inspiration + OWASP sources)

SKILL.md does NOT contain quick reference tables, indexes, or evolution maps. All of that lives in references.

### References Structure

```
references/
  LICENSE                              # CC BY-SA 4.0 full text
  INDEX.md                             # Master index: all projects, quick reference tables, evolution map
  cheatsheets-index.md                 # CheatSheetSeries categorized index + upstream links
  top10-web/                           # No 2017/ folder — 2017 lives only in INDEX.md as outline
    2021/
      A01-broken-access-control.md
      A02-cryptographic-failures.md
      A03-injection.md
      A04-insecure-design.md
      A05-security-misconfiguration.md
      A06-vulnerable-and-outdated-components.md
      A07-identification-and-authentication-failures.md
      A08-software-and-data-integrity-failures.md
      A09-security-logging-and-monitoring-failures.md
      A10-server-side-request-forgery.md
    2025/
      A01-broken-access-control.md
      A02-security-misconfiguration.md
      A03-software-supply-chain-failures.md
      A04-cryptographic-failures.md
      A05-injection.md
      A06-insecure-design.md
      A07-authentication-failures.md
      A08-software-or-data-integrity-failures.md
      A09-security-logging-and-alerting-failures.md
      A10-mishandling-of-exceptional-conditions.md
  top10-api/
    2023/
      0xa1-broken-object-level-authorization.md
      0xa2-broken-authentication.md
      0xa3-broken-object-property-level-authorization.md
      0xa4-unrestricted-resource-consumption.md
      0xa5-broken-function-level-authorization.md
      0xa6-unrestricted-access-to-sensitive-business-flows.md
      0xa7-server-side-request-forgery.md
      0xa8-security-misconfiguration.md
      0xa9-improper-inventory-management.md
      0xaa-unsafe-consumption-of-apis.md
  top10-llm/
    LLM01-prompt-injection.md
    LLM02-sensitive-information-disclosure.md
    LLM03-supply-chain.md
    LLM04-data-model-poisoning.md
    LLM05-improper-output-handling.md
    LLM06-excessive-agency.md
    LLM07-system-prompt-leakage.md
    LLM08-vector-and-embedding-weaknesses.md
    LLM09-misinformation.md
    LLM10-unbounded-consumption.md
  top10-mcp/
    MCP01-token-mismanagement-and-secret-exposure.md
    MCP02-privilege-escalation-via-scope-creep.md
    MCP03-tool-poisoning.md
    MCP04-software-supply-chain-attacks.md
    MCP05-command-injection-and-execution.md
    MCP06-intent-flow-subversion.md
    MCP07-insufficient-authentication-and-authorization.md
    MCP08-lack-of-audit-and-telemetry.md
    MCP09-shadow-mcp-servers.md
    MCP10-context-injection-and-oversharing.md
  top10-agentic/
    ast01.md
    ast02.md
    ast03.md
    ast04.md
    ast05.md
    ast06.md
    ast07.md
    ast08.md
    ast09.md
    ast10.md
  top10-mobile/
    2023/
      m1-improper-credential-usage.md
      m2-inadequate-supply-chain-security.md
      m3-insecure-authentication-authorization.md
      m4-insufficient-input-output-validation.md
      m5-insecure-communication.md
      m6-inadequate-privacy-controls.md
      m7-insufficient-binary-protection.md
      m8-security-misconfiguration.md
      m9-insecure-data-storage.md
      m10-insufficient-cryptography.md
  top10-cicd/
    CICD-SEC-01-insufficient-flow-control.md
    CICD-SEC-02-inadequate-identity-and-access-management.md
    CICD-SEC-03-dependency-chain-abuse.md
    CICD-SEC-04-poisoned-pipeline-execution.md
    CICD-SEC-05-insufficient-pbac.md
    CICD-SEC-06-insufficient-credential-hygiene.md
    CICD-SEC-07-insecure-system-configuration.md
    CICD-SEC-08-ungoverned-usage-of-3rd-party-services.md
    CICD-SEC-09-improper-artifact-integrity-validation.md
    CICD-SEC-10-insufficient-logging-and-visibility.md
  top10-k8s/
    2025/
      K01-insecure-workload-configurations.md
      K02-overly-permissive-authorization-configurations.md
      K03-secrets-management-failures.md
      K04-lack-of-cluster-level-policy-enforcement.md
      K05-missing-network-segmentation-controls.md
      K06-overly-exposed-kubernetes-components.md
      K07-misconfigured-and-vulnerable-cluster-components.md
      K08-cluster-to-cloud-lateral-movement.md
      K09-broken-authentication-mechanisms.md
      K10-inadequate-logging-and-monitoring.md
```

Total: ~80 reference files + 2 index files.

### INDEX.md Contents

1. **Project directory** — lists all 8 OWASP projects with version, reference path, and upstream repo URL
2. **Quick reference tables** — one per project, each item has rank + name + one-sentence summary
3. **Web Top 10 evolution map** — 2017 → 2021 → 2025 mapping table with notes on merges/splits/new entries
4. **Web Top 10:2017 outline** — quick reference table only (no reference files; agent should consult upstream for details)
5. **Older versions note** — for pre-2017, point agent to `https://github.com/OWASP/Top10`

### cheatsheets-index.md Contents

Categorized index of the 113 OWASP Cheat Sheets, grouped by security domain (auth, crypto, input validation, etc.). Each entry: name + one-line description + upstream URL. Agent uses this to find relevant cheat sheets and fetches from upstream when needed.

### Agent Workflow

```
User requests OWASP review
  → SKILL.md loaded (compact: role + behavior + attribution)
  → Agent reads INDEX.md
  → Agent identifies relevant projects & categories
  → Agent reads specific reference files
  → Agent produces findings with severity, location, remediation
  → For CheatSheetSeries details: agent fetches from upstream via URL in cheatsheets-index.md
  → For pre-2017 Web Top 10: agent consults https://github.com/OWASP/Top10
```

## Reference File Format

Each reference file sourced from OWASP repos includes:

```markdown
<!-- Source: https://github.com/OWASP/<repo>/blob/<branch>/<path> -->
<!-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/) -->
<!-- Modified: added attribution header -->

(original content from upstream)
```

Exception — Mobile Top 10 files use:

```markdown
<!-- Source: https://github.com/OWASP/www-project-mobile-top-10/blob/master/2023-risks/<file> -->
<!-- License: assumed CC BY-SA 4.0 per OWASP convention (not explicitly stated in repo) -->
<!-- Modified: added attribution header -->
```

## Licensing

- `references/LICENSE` — CC BY-SA 4.0 full text (covers all reference files in this directory)
- SKILL.md, README.md, INDEX.md, cheatsheets-index.md — original content, MIT (repo license)
- Reference markdown files — CC BY-SA 4.0 (derivative of OWASP sources)

## Plugin Registration

**`plugins/security/.claude-plugin/plugin.json`:**
```json
{
  "name": "security",
  "description": "Security review skills — OWASP Top 10 and more",
  "author": {
    "name": "caasi"
  },
  "homepage": "https://github.com/caasi/dong3",
  "repository": "https://github.com/caasi/dong3",
  "license": "MIT",
  "keywords": ["security", "owasp", "top10", "vulnerability"],
  "skills": "./skills/"
}
```

**marketplace.json addition:**
```json
{
  "name": "security",
  "source": "./plugins/security",
  "description": "Security review skills — OWASP vulnerability analysis with offline reference data from 8 Top 10 projects and CheatSheetSeries index",
  "version": "0.1.0"
}
```

## Source Repos

| Project | Repo | Path | License |
|---------|------|------|---------|
| Web Top 10 2021 | `OWASP/Top10` | `2021/docs/en/A*` | CC BY-SA 4.0 |
| Web Top 10 2025 | `OWASP/Top10` | `2025/docs/en/A*` | CC BY-SA 4.0 |
| API Security 2023 | `OWASP/API-Security` | `editions/2023/en/0xa*` | CC BY-SA 4.0 |
| LLM Top 10 v2.0 | `OWASP/www-project-top-10-for-large-language-model-applications` | `2_0_vulns/LLM*` | CC BY-SA 4.0 |
| MCP Top 10 2025 | `OWASP/www-project-mcp-top-10` | `2025/MCP*` | CC BY-SA 4.0 |
| Agentic Skills Top 10 | `OWASP/www-project-agentic-skills-top-10` | `ast*.md` | CC BY-SA 4.0 |
| Mobile Top 10 2023 | `OWASP/www-project-mobile-top-10` | `2023-risks/m*` | Assumed CC BY-SA 4.0 |
| CI/CD Top 10 | `OWASP/www-project-top-10-ci-cd-security-risks` | `CICD-SEC-*` | CC BY-SA 4.0 |
| K8s Top 10 2025 | `OWASP/www-project-kubernetes-top-ten` | `2025/en/src/K*` | CC BY-SA 4.0 |
| CheatSheetSeries | `OWASP/CheatSheetSeries` | `cheatsheets/*.md` | CC BY-SA 4.0 |
