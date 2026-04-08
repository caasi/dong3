# Security Plugin — OWASP Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the `security` plugin with an `owasp` skill that provides offline OWASP security review guidance backed by ~90 reference files from 8 OWASP Top 10 projects plus a CheatSheetSeries index.

**Architecture:** Plugin scaffold + compact SKILL.md (behavior only) + `references/` directory containing per-vulnerability markdown files fetched from OWASP GitHub repos, a master INDEX.md with quick reference tables and evolution map, and a cheatsheets-index.md. No code, no binaries — pure content skill.

**Tech Stack:** Markdown, JSON, `gh` CLI for fetching

**Spec:** `docs/superpowers/specs/2026-04-08-security-owasp-skill-design.md`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `plugins/security/.claude-plugin/plugin.json` | Plugin manifest |
| Create | `plugins/security/skills/owasp/SKILL.md` | Skill system prompt |
| Create | `plugins/security/skills/owasp/README.md` | User-facing docs |
| Create | `plugins/security/skills/owasp/references/LICENSE` | CC BY-SA 4.0 full text |
| Create | `plugins/security/skills/owasp/references/INDEX.md` | Master index + quick ref tables + evolution map |
| Create | `plugins/security/skills/owasp/references/cheatsheets-index.md` | CheatSheetSeries categorized index |
| Create | `plugins/security/skills/owasp/references/top10-web/2021/*.md` | 10 files |
| Create | `plugins/security/skills/owasp/references/top10-web/2025/*.md` | 10 files |
| Create | `plugins/security/skills/owasp/references/top10-api/2023/*.md` | 10 files |
| Create | `plugins/security/skills/owasp/references/top10-llm/*.md` | 10 files |
| Create | `plugins/security/skills/owasp/references/top10-mcp/*.md` | 10 files |
| Create | `plugins/security/skills/owasp/references/top10-agentic/*.md` | 10 files |
| Create | `plugins/security/skills/owasp/references/top10-mobile/2023/*.md` | 10 files |
| Create | `plugins/security/skills/owasp/references/top10-cicd/*.md` | 10 files |
| Create | `plugins/security/skills/owasp/references/top10-k8s/2025/*.md` | 10 files |
| Modify | `.claude-plugin/marketplace.json` | Add security plugin entry |

---

## Parallelization Note

After Task 1 (scaffold), Tasks 2–13 are **fully independent** and can be dispatched in parallel. Tasks 14–15 depend on all prior tasks.

---

## Task 1: Feature Branch + Plugin Scaffold

**Files:**
- Create: `plugins/security/.claude-plugin/plugin.json`
- Create: all `references/` subdirectories (empty)

- [ ] **Step 1: Create feature branch**

```bash
git checkout -b feat/security-owasp-skill
```

- [ ] **Step 2: Create directory structure**

```bash
mkdir -p plugins/security/.claude-plugin
mkdir -p plugins/security/skills/owasp/references/top10-web/2021
mkdir -p plugins/security/skills/owasp/references/top10-web/2025
mkdir -p plugins/security/skills/owasp/references/top10-api/2023
mkdir -p plugins/security/skills/owasp/references/top10-llm
mkdir -p plugins/security/skills/owasp/references/top10-mcp
mkdir -p plugins/security/skills/owasp/references/top10-agentic
mkdir -p plugins/security/skills/owasp/references/top10-mobile/2023
mkdir -p plugins/security/skills/owasp/references/top10-cicd
mkdir -p plugins/security/skills/owasp/references/top10-k8s/2025
```

- [ ] **Step 3: Write plugin.json**

Create `plugins/security/.claude-plugin/plugin.json`:

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

- [ ] **Step 4: Commit**

```bash
git add plugins/security/.claude-plugin/plugin.json
git commit -m "chore(security): scaffold plugin structure"
```

---

## Task 2: Create SKILL.md

**Files:**
- Create: `plugins/security/skills/owasp/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

Create `plugins/security/skills/owasp/SKILL.md`:

```markdown
---
name: owasp
description: >-
  Use when the user asks for OWASP security review, vulnerability check,
  "/owasp", "check OWASP", "安全審查", "security review", or explicitly
  requests Top 10 analysis. Do not trigger automatically.
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
```

- [ ] **Step 2: Verify frontmatter parses correctly**

```bash
head -6 plugins/security/skills/owasp/SKILL.md
```

Expected: YAML frontmatter with `name: owasp` and `description:` field.

- [ ] **Step 3: Commit**

```bash
git add plugins/security/skills/owasp/SKILL.md
git commit -m "feat(security): add OWASP skill system prompt"
```

---

## Task 3: Create references/LICENSE

**Files:**
- Create: `plugins/security/skills/owasp/references/LICENSE`

- [ ] **Step 1: Write CC BY-SA 4.0 license**

Fetch the canonical CC BY-SA 4.0 legal text:

```bash
gh api repos/OWASP/Top10/contents/LICENSE --header 'Accept: application/vnd.github.raw+json' \
  > plugins/security/skills/owasp/references/LICENSE
```

- [ ] **Step 2: Verify it contains CC BY-SA 4.0**

```bash
head -3 plugins/security/skills/owasp/references/LICENSE
```

Expected: "Creative Commons Attribution-ShareAlike 4.0 International Public License"

- [ ] **Step 3: Commit**

```bash
git add plugins/security/skills/owasp/references/LICENSE
git commit -m "chore(security): add CC BY-SA 4.0 license for OWASP references"
```

---

## Task 4: Fetch Web Top 10 References (2021 + 2025)

**Files:**
- Create: `plugins/security/skills/owasp/references/top10-web/2021/*.md` (10 files)
- Create: `plugins/security/skills/owasp/references/top10-web/2025/*.md` (10 files)

Source repo: `OWASP/Top10` (branch: `master`)

- [ ] **Step 1: Fetch 2021 references**

```bash
DEST="plugins/security/skills/owasp/references/top10-web/2021"
REPO="OWASP/Top10"
BRANCH="master"
SRC_DIR="2021/docs/en"

declare -A FILES_2021=(
  ["A01_2021-Broken_Access_Control.md"]="A01-broken-access-control.md"
  ["A02_2021-Cryptographic_Failures.md"]="A02-cryptographic-failures.md"
  ["A03_2021-Injection.md"]="A03-injection.md"
  ["A04_2021-Insecure_Design.md"]="A04-insecure-design.md"
  ["A05_2021-Security_Misconfiguration.md"]="A05-security-misconfiguration.md"
  ["A06_2021-Vulnerable_and_Outdated_Components.md"]="A06-vulnerable-and-outdated-components.md"
  ["A07_2021-Identification_and_Authentication_Failures.md"]="A07-identification-and-authentication-failures.md"
  ["A08_2021-Software_and_Data_Integrity_Failures.md"]="A08-software-and-data-integrity-failures.md"
  ["A09_2021-Security_Logging_and_Monitoring_Failures.md"]="A09-security-logging-and-monitoring-failures.md"
  ["A10_2021-Server-Side_Request_Forgery_(SSRF).md"]="A10-server-side-request-forgery.md"
)

for src in "${!FILES_2021[@]}"; do
  dest_name="${FILES_2021[$src]}"
  content=$(gh api "repos/${REPO}/contents/${SRC_DIR}/${src}" --header 'Accept: application/vnd.github.raw+json')
  {
    echo "<!-- Source: https://github.com/${REPO}/blob/${BRANCH}/${SRC_DIR}/${src} -->"
    echo "<!-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/) -->"
    echo "<!-- Modified: added attribution header -->"
    echo ""
    echo "$content"
  } > "${DEST}/${dest_name}"
done
```

- [ ] **Step 2: Fetch 2025 references**

```bash
DEST="plugins/security/skills/owasp/references/top10-web/2025"
SRC_DIR="2025/docs/en"

declare -A FILES_2025=(
  ["A01_2025-Broken_Access_Control.md"]="A01-broken-access-control.md"
  ["A02_2025-Security_Misconfiguration.md"]="A02-security-misconfiguration.md"
  ["A03_2025-Software_Supply_Chain_Failures.md"]="A03-software-supply-chain-failures.md"
  ["A04_2025-Cryptographic_Failures.md"]="A04-cryptographic-failures.md"
  ["A05_2025-Injection.md"]="A05-injection.md"
  ["A06_2025-Insecure_Design.md"]="A06-insecure-design.md"
  ["A07_2025-Authentication_Failures.md"]="A07-authentication-failures.md"
  ["A08_2025-Software_or_Data_Integrity_Failures.md"]="A08-software-or-data-integrity-failures.md"
  ["A09_2025-Security_Logging_and_Alerting_Failures.md"]="A09-security-logging-and-alerting-failures.md"
  ["A10_2025-Mishandling_of_Exceptional_Conditions.md"]="A10-mishandling-of-exceptional-conditions.md"
)

for src in "${!FILES_2025[@]}"; do
  dest_name="${FILES_2025[$src]}"
  content=$(gh api "repos/${REPO}/contents/${SRC_DIR}/${src}" --header 'Accept: application/vnd.github.raw+json')
  {
    echo "<!-- Source: https://github.com/${REPO}/blob/${BRANCH}/${SRC_DIR}/${src} -->"
    echo "<!-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/) -->"
    echo "<!-- Modified: added attribution header -->"
    echo ""
    echo "$content"
  } > "${DEST}/${dest_name}"
done
```

- [ ] **Step 3: Verify file counts**

```bash
ls plugins/security/skills/owasp/references/top10-web/2021/ | wc -l  # expect 10
ls plugins/security/skills/owasp/references/top10-web/2025/ | wc -l  # expect 10
```

- [ ] **Step 4: Verify attribution headers present**

```bash
head -3 plugins/security/skills/owasp/references/top10-web/2021/A01-broken-access-control.md
head -3 plugins/security/skills/owasp/references/top10-web/2025/A01-broken-access-control.md
```

Expected: `<!-- Source: ... -->` on line 1.

- [ ] **Step 5: Commit**

```bash
git add plugins/security/skills/owasp/references/top10-web/
git commit -m "feat(security): add OWASP Web Top 10 references (2021 + 2025)"
```

---

## Task 5: Fetch API Security Top 10 References (2023)

**Files:**
- Create: `plugins/security/skills/owasp/references/top10-api/2023/*.md` (10 files)

Source repo: `OWASP/API-Security` (branch: `master`)
Source path: `editions/2023/en/`

- [ ] **Step 1: Fetch API Security references**

```bash
DEST="plugins/security/skills/owasp/references/top10-api/2023"
REPO="OWASP/API-Security"
BRANCH="master"
SRC_DIR="editions/2023/en"

# These filenames already match the spec — no renaming needed
FILES=(
  "0xa1-broken-object-level-authorization.md"
  "0xa2-broken-authentication.md"
  "0xa3-broken-object-property-level-authorization.md"
  "0xa4-unrestricted-resource-consumption.md"
  "0xa5-broken-function-level-authorization.md"
  "0xa6-unrestricted-access-to-sensitive-business-flows.md"
  "0xa7-server-side-request-forgery.md"
  "0xa8-security-misconfiguration.md"
  "0xa9-improper-inventory-management.md"
  "0xaa-unsafe-consumption-of-apis.md"
)

for file in "${FILES[@]}"; do
  content=$(gh api "repos/${REPO}/contents/${SRC_DIR}/${file}" --header 'Accept: application/vnd.github.raw+json')
  {
    echo "<!-- Source: https://github.com/${REPO}/blob/${BRANCH}/${SRC_DIR}/${file} -->"
    echo "<!-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/) -->"
    echo "<!-- Modified: added attribution header -->"
    echo ""
    echo "$content"
  } > "${DEST}/${file}"
done
```

- [ ] **Step 2: Verify**

```bash
ls plugins/security/skills/owasp/references/top10-api/2023/ | wc -l  # expect 10
head -3 plugins/security/skills/owasp/references/top10-api/2023/0xa1-broken-object-level-authorization.md
```

- [ ] **Step 3: Commit**

```bash
git add plugins/security/skills/owasp/references/top10-api/
git commit -m "feat(security): add OWASP API Security Top 10 references (2023)"
```

---

## Task 6: Fetch LLM Top 10 References

**Files:**
- Create: `plugins/security/skills/owasp/references/top10-llm/*.md` (10 files)

Source repo: `OWASP/www-project-top-10-for-large-language-model-applications` (branch: `main`)
Source path: `2_0_vulns/`

- [ ] **Step 1: Fetch LLM Top 10 references**

```bash
DEST="plugins/security/skills/owasp/references/top10-llm"
REPO="OWASP/www-project-top-10-for-large-language-model-applications"
BRANCH="main"
SRC_DIR="2_0_vulns"

declare -A FILES=(
  ["LLM01_PromptInjection.md"]="LLM01-prompt-injection.md"
  ["LLM02_SensitiveInformationDisclosure.md"]="LLM02-sensitive-information-disclosure.md"
  ["LLM03_SupplyChain.md"]="LLM03-supply-chain.md"
  ["LLM04_DataModelPoisoning.md"]="LLM04-data-model-poisoning.md"
  ["LLM05_ImproperOutputHandling.md"]="LLM05-improper-output-handling.md"
  ["LLM06_ExcessiveAgency.md"]="LLM06-excessive-agency.md"
  ["LLM07_SystemPromptLeakage.md"]="LLM07-system-prompt-leakage.md"
  ["LLM08_VectorAndEmbeddingWeaknesses.md"]="LLM08-vector-and-embedding-weaknesses.md"
  ["LLM09_Misinformation.md"]="LLM09-misinformation.md"
  ["LLM10_UnboundedConsumption.md"]="LLM10-unbounded-consumption.md"
)

for src in "${!FILES[@]}"; do
  dest_name="${FILES[$src]}"
  content=$(gh api "repos/${REPO}/contents/${SRC_DIR}/${src}" --header 'Accept: application/vnd.github.raw+json')
  {
    echo "<!-- Source: https://github.com/${REPO}/blob/${BRANCH}/${SRC_DIR}/${src} -->"
    echo "<!-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/) -->"
    echo "<!-- Modified: added attribution header, renamed file -->"
    echo ""
    echo "$content"
  } > "${DEST}/${dest_name}"
done
```

- [ ] **Step 2: Verify**

```bash
ls plugins/security/skills/owasp/references/top10-llm/ | wc -l  # expect 10
head -3 plugins/security/skills/owasp/references/top10-llm/LLM01-prompt-injection.md
```

- [ ] **Step 3: Commit**

```bash
git add plugins/security/skills/owasp/references/top10-llm/
git commit -m "feat(security): add OWASP LLM Top 10 references (v2.0)"
```

---

## Task 7: Fetch MCP Top 10 References

**Files:**
- Create: `plugins/security/skills/owasp/references/top10-mcp/*.md` (10 files)

Source repo: `OWASP/www-project-mcp-top-10` (branch: `main`)
Source path: `2025/`

- [ ] **Step 1: Fetch MCP Top 10 references**

Note: MCP source filenames contain special characters (en-dash `–` in MCP02). Use exact upstream names.

```bash
DEST="plugins/security/skills/owasp/references/top10-mcp"
REPO="OWASP/www-project-mcp-top-10"
BRANCH="main"
SRC_DIR="2025"

declare -A FILES=(
  ["MCP01-2025-Token-Mismanagement-and-Secret-Exposure.md"]="MCP01-token-mismanagement-and-secret-exposure.md"
  ["MCP02-2025–Privilege-Escalation-via-Scope-Creep.md"]="MCP02-privilege-escalation-via-scope-creep.md"
  ["MCP03-2025–Tool-Poisoning.md"]="MCP03-tool-poisoning.md"
  ["MCP04-2025–Software-Supply-Chain-Attacks&Dependency-Tampering.md"]="MCP04-software-supply-chain-attacks.md"
  ["MCP05-2025–Command-Injection&Execution.md"]="MCP05-command-injection-and-execution.md"
  ["MCP06-2025–Intent-Flow-Subversion.md"]="MCP06-intent-flow-subversion.md"
  ["MCP07-2025–Insufficient-Authentication&Authorization.md"]="MCP07-insufficient-authentication-and-authorization.md"
  ["MCP08-2025–Lack-of-Audit-and-Telemetry.md"]="MCP08-lack-of-audit-and-telemetry.md"
  ["MCP09-2025–Shadow-MCP-Servers.md"]="MCP09-shadow-mcp-servers.md"
  ["MCP10-2025–ContextInjection&OverSharing.md"]="MCP10-context-injection-and-oversharing.md"
)

for src in "${!FILES[@]}"; do
  dest_name="${FILES[$src]}"
  # URL-encode the source filename for the API call
  encoded_src=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${SRC_DIR}/${src}'))")
  content=$(gh api "repos/${REPO}/contents/${encoded_src}" --header 'Accept: application/vnd.github.raw+json')
  {
    echo "<!-- Source: https://github.com/${REPO}/blob/${BRANCH}/${SRC_DIR}/${src} -->"
    echo "<!-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/) -->"
    echo "<!-- Modified: added attribution header, renamed file -->"
    echo ""
    echo "$content"
  } > "${DEST}/${dest_name}"
done
```

- [ ] **Step 2: Verify**

```bash
ls plugins/security/skills/owasp/references/top10-mcp/ | wc -l  # expect 10
head -3 plugins/security/skills/owasp/references/top10-mcp/MCP01-token-mismanagement-and-secret-exposure.md
```

- [ ] **Step 3: Commit**

```bash
git add plugins/security/skills/owasp/references/top10-mcp/
git commit -m "feat(security): add OWASP MCP Top 10 references (2025)"
```

---

## Task 8: Fetch Agentic Skills Top 10 References

**Files:**
- Create: `plugins/security/skills/owasp/references/top10-agentic/*.md` (10 files)

Source repo: `OWASP/www-project-agentic-skills-top-10` (branch: `main`)
Source path: root (`ast*.md`)

- [ ] **Step 1: Fetch Agentic Skills references**

```bash
DEST="plugins/security/skills/owasp/references/top10-agentic"
REPO="OWASP/www-project-agentic-skills-top-10"
BRANCH="main"

for i in $(seq -w 01 10); do
  file="ast${i}.md"
  content=$(gh api "repos/${REPO}/contents/${file}" --header 'Accept: application/vnd.github.raw+json')
  {
    echo "<!-- Source: https://github.com/${REPO}/blob/${BRANCH}/${file} -->"
    echo "<!-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/) -->"
    echo "<!-- Modified: added attribution header -->"
    echo ""
    echo "$content"
  } > "${DEST}/${file}"
done
```

- [ ] **Step 2: Verify**

```bash
ls plugins/security/skills/owasp/references/top10-agentic/ | wc -l  # expect 10
head -3 plugins/security/skills/owasp/references/top10-agentic/ast01.md
```

- [ ] **Step 3: Commit**

```bash
git add plugins/security/skills/owasp/references/top10-agentic/
git commit -m "feat(security): add OWASP Agentic Skills Top 10 references"
```

---

## Task 9: Fetch Mobile Top 10 References (2023)

**Files:**
- Create: `plugins/security/skills/owasp/references/top10-mobile/2023/*.md` (10 files)

Source repo: `OWASP/www-project-mobile-top-10` (branch: `master`)
Source path: `2023-risks/`

**License note:** This repo has no explicit license file. Attribution uses "assumed CC BY-SA 4.0 per OWASP convention."

- [ ] **Step 1: Fetch Mobile Top 10 references**

```bash
DEST="plugins/security/skills/owasp/references/top10-mobile/2023"
REPO="OWASP/www-project-mobile-top-10"
BRANCH="master"
SRC_DIR="2023-risks"

FILES=(
  "m1-improper-credential-usage.md"
  "m2-inadequate-supply-chain-security.md"
  "m3-insecure-authentication-authorization.md"
  "m4-insufficient-input-output-validation.md"
  "m5-insecure-communication.md"
  "m6-inadequate-privacy-controls.md"
  "m7-insufficient-binary-protection.md"
  "m8-security-misconfiguration.md"
  "m9-insecure-data-storage.md"
  "m10-insufficient-cryptography.md"
)

for file in "${FILES[@]}"; do
  content=$(gh api "repos/${REPO}/contents/${SRC_DIR}/${file}" --header 'Accept: application/vnd.github.raw+json')
  {
    echo "<!-- Source: https://github.com/${REPO}/blob/${BRANCH}/${SRC_DIR}/${file} -->"
    echo "<!-- License: assumed CC BY-SA 4.0 per OWASP convention (not explicitly stated in repo) -->"
    echo "<!-- Modified: added attribution header -->"
    echo ""
    echo "$content"
  } > "${DEST}/${file}"
done
```

- [ ] **Step 2: Verify**

```bash
ls plugins/security/skills/owasp/references/top10-mobile/2023/ | wc -l  # expect 10
head -3 plugins/security/skills/owasp/references/top10-mobile/2023/m1-improper-credential-usage.md
```

- [ ] **Step 3: Commit**

```bash
git add plugins/security/skills/owasp/references/top10-mobile/
git commit -m "feat(security): add OWASP Mobile Top 10 references (2023)"
```

---

## Task 10: Fetch CI/CD Top 10 References

**Files:**
- Create: `plugins/security/skills/owasp/references/top10-cicd/*.md` (10 files)

Source repo: `OWASP/www-project-top-10-ci-cd-security-risks` (branch: `main`)
Source path: root (`CICD-SEC-*.md`)

- [ ] **Step 1: Fetch CI/CD Top 10 references**

```bash
DEST="plugins/security/skills/owasp/references/top10-cicd"
REPO="OWASP/www-project-top-10-ci-cd-security-risks"
BRANCH="main"

declare -A FILES=(
  ["CICD-SEC-01-Insufficient-Flow-Control-Mechanisms.md"]="CICD-SEC-01-insufficient-flow-control.md"
  ["CICD-SEC-02-Inadequate-Identity-And-Access-Management.md"]="CICD-SEC-02-inadequate-identity-and-access-management.md"
  ["CICD-SEC-03-Dependency-Chain-Abuse.md"]="CICD-SEC-03-dependency-chain-abuse.md"
  ["CICD-SEC-04-Poisoned-Pipeline-Execution.md"]="CICD-SEC-04-poisoned-pipeline-execution.md"
  ["CICD-SEC-05-Insufficient-PBAC.md"]="CICD-SEC-05-insufficient-pbac.md"
  ["CICD-SEC-06-Insufficient-Credential-Hygiene.md"]="CICD-SEC-06-insufficient-credential-hygiene.md"
  ["CICD-SEC-07-Insecure-System-Configuration.md"]="CICD-SEC-07-insecure-system-configuration.md"
  ["CICD-SEC-08-Ungoverned-Usage-of-3rd-Party-Services.md"]="CICD-SEC-08-ungoverned-usage-of-3rd-party-services.md"
  ["CICD-SEC-09-Improper-Artifact-Integrity-Validation.md"]="CICD-SEC-09-improper-artifact-integrity-validation.md"
  ["CICD-SEC-10-Insufficient-Logging-And-Visibility.md"]="CICD-SEC-10-insufficient-logging-and-visibility.md"
)

for src in "${!FILES[@]}"; do
  dest_name="${FILES[$src]}"
  content=$(gh api "repos/${REPO}/contents/${src}" --header 'Accept: application/vnd.github.raw+json')
  {
    echo "<!-- Source: https://github.com/${REPO}/blob/${BRANCH}/${src} -->"
    echo "<!-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/) -->"
    echo "<!-- Modified: added attribution header, renamed file -->"
    echo ""
    echo "$content"
  } > "${DEST}/${dest_name}"
done
```

- [ ] **Step 2: Verify**

```bash
ls plugins/security/skills/owasp/references/top10-cicd/ | wc -l  # expect 10
head -3 plugins/security/skills/owasp/references/top10-cicd/CICD-SEC-01-insufficient-flow-control.md
```

- [ ] **Step 3: Commit**

```bash
git add plugins/security/skills/owasp/references/top10-cicd/
git commit -m "feat(security): add OWASP CI/CD Security Top 10 references"
```

---

## Task 11: Fetch Kubernetes Top 10 References (2025)

**Files:**
- Create: `plugins/security/skills/owasp/references/top10-k8s/2025/*.md` (10 files)

Source repo: `OWASP/www-project-kubernetes-top-ten` (branch: `main`)
Source path: `2025/en/src/`

- [ ] **Step 1: Fetch K8s Top 10 references**

```bash
DEST="plugins/security/skills/owasp/references/top10-k8s/2025"
REPO="OWASP/www-project-kubernetes-top-ten"
BRANCH="main"
SRC_DIR="2025/en/src"

declare -A FILES=(
  ["K01-Insecure-Workload-Configurations.md"]="K01-insecure-workload-configurations.md"
  ["K02-Overly-Permissive-Authorization-Configurations.md"]="K02-overly-permissive-authorization-configurations.md"
  ["K03-Secrets-Management-Failures.md"]="K03-secrets-management-failures.md"
  ["K04-Lack-Of-Cluster-Level-Policy-Enforcement.md"]="K04-lack-of-cluster-level-policy-enforcement.md"
  ["K05-Missing-Network-Segmentation-Controls.md"]="K05-missing-network-segmentation-controls.md"
  ["K06-Overly-Exposed-Kubernetes-Components.md"]="K06-overly-exposed-kubernetes-components.md"
  ["K07-Misconfigured-And-Vulnerable-Cluster-Components.md"]="K07-misconfigured-and-vulnerable-cluster-components.md"
  ["K08-Cluster-To-Cloud-Lateral-Movement.md"]="K08-cluster-to-cloud-lateral-movement.md"
  ["K09-Broken-Authentication-Mechanisms.md"]="K09-broken-authentication-mechanisms.md"
  ["K10-Inadequate-Logging-And-Monitoring.md"]="K10-inadequate-logging-and-monitoring.md"
)

for src in "${!FILES[@]}"; do
  dest_name="${FILES[$src]}"
  content=$(gh api "repos/${REPO}/contents/${SRC_DIR}/${src}" --header 'Accept: application/vnd.github.raw+json')
  {
    echo "<!-- Source: https://github.com/${REPO}/blob/${BRANCH}/${SRC_DIR}/${src} -->"
    echo "<!-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/) -->"
    echo "<!-- Modified: added attribution header, renamed file -->"
    echo ""
    echo "$content"
  } > "${DEST}/${dest_name}"
done
```

- [ ] **Step 2: Verify**

```bash
ls plugins/security/skills/owasp/references/top10-k8s/2025/ | wc -l  # expect 10
head -3 plugins/security/skills/owasp/references/top10-k8s/2025/K01-insecure-workload-configurations.md
```

- [ ] **Step 3: Commit**

```bash
git add plugins/security/skills/owasp/references/top10-k8s/
git commit -m "feat(security): add OWASP Kubernetes Top 10 references (2025)"
```

---

## Task 12: Create INDEX.md

**Files:**
- Create: `plugins/security/skills/owasp/references/INDEX.md`

This is the master index that the agent reads first. It contains:
1. Project directory
2. Quick reference tables (one per project, including 2017 Web Top 10 outline)
3. Web Top 10 evolution map (2017 → 2021 → 2025)

- [ ] **Step 1: Write INDEX.md**

Create `plugins/security/skills/owasp/references/INDEX.md`. The file is large (~250 lines) so write it in full. Content structure:

```markdown
# OWASP Security Reference Index

Quick reference tables and directory for all OWASP projects in this skill.
Read this file first to identify relevant categories, then read specific
reference files as needed.

## Project Directory

| Project | Version | Path | Upstream Repo |
|---------|---------|------|---------------|
| Web Top 10 | 2021 | `top10-web/2021/` | [OWASP/Top10](https://github.com/OWASP/Top10) |
| Web Top 10 | 2025 | `top10-web/2025/` | [OWASP/Top10](https://github.com/OWASP/Top10) |
| API Security Top 10 | 2023 | `top10-api/2023/` | [OWASP/API-Security](https://github.com/OWASP/API-Security) |
| LLM Top 10 | v2.0 | `top10-llm/` | [OWASP/www-project-top-10-for-large-language-model-applications](https://github.com/OWASP/www-project-top-10-for-large-language-model-applications) |
| MCP Top 10 | 2025 | `top10-mcp/` | [OWASP/www-project-mcp-top-10](https://github.com/OWASP/www-project-mcp-top-10) |
| Agentic Skills Top 10 | v1.0 | `top10-agentic/` | [OWASP/www-project-agentic-skills-top-10](https://github.com/OWASP/www-project-agentic-skills-top-10) |
| Mobile Top 10 | 2023 | `top10-mobile/2023/` | [OWASP/www-project-mobile-top-10](https://github.com/OWASP/www-project-mobile-top-10) |
| CI/CD Security Top 10 | v1.0 | `top10-cicd/` | [OWASP/www-project-top-10-ci-cd-security-risks](https://github.com/OWASP/www-project-top-10-ci-cd-security-risks) |
| Kubernetes Top 10 | 2025 | `top10-k8s/2025/` | [OWASP/www-project-kubernetes-top-ten](https://github.com/OWASP/www-project-kubernetes-top-ten) |

For older Web Top 10 versions (pre-2017), consult the upstream repo directly:
https://github.com/OWASP/Top10

---

## Web Top 10:2025

| # | Category | File | Summary |
|---|----------|------|---------|
| A01 | Broken Access Control | `top10-web/2025/A01-broken-access-control.md` | Missing or bypassed authorization checks |
| A02 | Security Misconfiguration | `top10-web/2025/A02-security-misconfiguration.md` | Default creds, open cloud storage, verbose errors |
| A03 | Software Supply Chain Failures | `top10-web/2025/A03-software-supply-chain-failures.md` | Untrusted dependencies, compromised build pipelines |
| A04 | Cryptographic Failures | `top10-web/2025/A04-cryptographic-failures.md` | Weak algorithms, plaintext secrets, missing encryption |
| A05 | Injection | `top10-web/2025/A05-injection.md` | SQL, NoSQL, OS command, LDAP, template injection |
| A06 | Insecure Design | `top10-web/2025/A06-insecure-design.md` | Missing threat model, no defense-in-depth |
| A07 | Authentication Failures | `top10-web/2025/A07-authentication-failures.md` | Broken login, weak passwords, missing MFA |
| A08 | Software or Data Integrity Failures | `top10-web/2025/A08-software-or-data-integrity-failures.md` | Unsigned updates, insecure CI/CD, deserialization |
| A09 | Security Logging and Alerting Failures | `top10-web/2025/A09-security-logging-and-alerting-failures.md` | No audit trail, silent failures, missing alerts |
| A10 | Mishandling of Exceptional Conditions | `top10-web/2025/A10-mishandling-of-exceptional-conditions.md` | Fail-open, unhandled errors, info leaks in stack traces |

## Web Top 10:2021

| # | Category | File | Summary |
|---|----------|------|---------|
| A01 | Broken Access Control | `top10-web/2021/A01-broken-access-control.md` | IDOR, missing function-level access control, CORS misconfig |
| A02 | Cryptographic Failures | `top10-web/2021/A02-cryptographic-failures.md` | Data exposure via weak crypto, cleartext transmission |
| A03 | Injection | `top10-web/2021/A03-injection.md` | SQL, NoSQL, OS, LDAP injection; now includes XSS and XXE |
| A04 | Insecure Design | `top10-web/2021/A04-insecure-design.md` | Flawed architecture, missing security controls by design |
| A05 | Security Misconfiguration | `top10-web/2021/A05-security-misconfiguration.md` | Unpatched systems, default accounts, unnecessary features |
| A06 | Vulnerable and Outdated Components | `top10-web/2021/A06-vulnerable-and-outdated-components.md` | Known CVEs in dependencies, unsupported frameworks |
| A07 | Identification and Authentication Failures | `top10-web/2021/A07-identification-and-authentication-failures.md` | Credential stuffing, weak sessions, missing MFA |
| A08 | Software and Data Integrity Failures | `top10-web/2021/A08-software-and-data-integrity-failures.md` | CI/CD integrity, insecure deserialization, unsigned updates |
| A09 | Security Logging and Monitoring Failures | `top10-web/2021/A09-security-logging-and-monitoring-failures.md` | Insufficient logging, no alerting, unmonitored activity |
| A10 | Server-Side Request Forgery (SSRF) | `top10-web/2021/A10-server-side-request-forgery.md` | Fetching attacker-controlled URLs from server side |

## Web Top 10:2017 (outline only — no reference files)

| # | Category | Summary |
|---|----------|---------|
| A1 | Injection | SQL, NoSQL, OS, LDAP injection via untrusted data |
| A2 | Broken Authentication | Session mismanagement, credential stuffing, weak passwords |
| A3 | Sensitive Data Exposure | Cleartext data, weak crypto, missing encryption at rest/transit |
| A4 | XML External Entities (XXE) | XML parser exploits, SSRF via XML, billion laughs |
| A5 | Broken Access Control | IDOR, missing function-level checks, privilege escalation |
| A6 | Security Misconfiguration | Default configs, verbose errors, unnecessary services |
| A7 | Cross-Site Scripting (XSS) | Reflected, stored, DOM-based XSS |
| A8 | Insecure Deserialization | RCE via untrusted deserialization, object injection |
| A9 | Using Components with Known Vulnerabilities | Outdated libraries, unpatched frameworks |
| A10 | Insufficient Logging & Monitoring | No audit logs, missing breach detection |

For 2017 details, consult upstream: https://github.com/OWASP/Top10/tree/master/2017

---

## Evolution Map: Web Top 10 (2017 → 2021 → 2025)

| 2017 | 2021 | 2025 | Notes |
|------|------|------|-------|
| A1 Injection | A03 Injection | A05 Injection | Scope stable; 2021 absorbed XXE and XSS |
| A2 Broken Auth | A07 Auth Failures | A07 Auth Failures | Narrowed to authentication only |
| A3 Sensitive Data | A02 Crypto Failures | A04 Crypto Failures | Renamed to focus on root cause |
| A4 XXE | (merged into A03) | (merged into A05) | Absorbed into Injection |
| A5 Broken Access | A01 Broken Access | A01 Broken Access | Rose to #1 in 2021, stayed |
| A6 Misconfig | A05 Misconfig | A02 Misconfig | Rose to #2 in 2025 |
| A7 XSS | (merged into A03) | (merged into A05) | Absorbed into Injection |
| A8 Insecure Deser | A08 Integrity | A08 Integrity | Broadened to all integrity failures |
| A9 Known Vulns | A06 Outdated Components | A03 Supply Chain | Broadened to full supply chain |
| A10 Logging | A09 Logging | A09 Logging | Scope stable; 2025 adds "alerting" |
| — | A04 Insecure Design | A06 Insecure Design | New in 2021 |
| — | A10 SSRF | (dropped) | Removed in 2025 |
| — | — | A10 Exceptional Conditions | New in 2025 |

---

## API Security Top 10:2023

| # | Category | File | Summary |
|---|----------|------|---------|
| API1 | Broken Object Level Authorization | `top10-api/2023/0xa1-broken-object-level-authorization.md` | Accessing other users' objects by manipulating IDs |
| API2 | Broken Authentication | `top10-api/2023/0xa2-broken-authentication.md` | Weak auth mechanisms, missing token validation |
| API3 | Broken Object Property Level Authorization | `top10-api/2023/0xa3-broken-object-property-level-authorization.md` | Mass assignment, excessive data exposure per object |
| API4 | Unrestricted Resource Consumption | `top10-api/2023/0xa4-unrestricted-resource-consumption.md` | Missing rate limits, resource exhaustion |
| API5 | Broken Function Level Authorization | `top10-api/2023/0xa5-broken-function-level-authorization.md` | Accessing admin functions as regular user |
| API6 | Unrestricted Access to Sensitive Business Flows | `top10-api/2023/0xa6-unrestricted-access-to-sensitive-business-flows.md` | Automated abuse of business logic (scalping, spam) |
| API7 | Server-Side Request Forgery | `top10-api/2023/0xa7-server-side-request-forgery.md` | Fetching attacker-controlled URLs from API server |
| API8 | Security Misconfiguration | `top10-api/2023/0xa8-security-misconfiguration.md` | Missing headers, CORS misconfig, verbose errors |
| API9 | Improper Inventory Management | `top10-api/2023/0xa9-improper-inventory-management.md` | Shadow APIs, undocumented endpoints, old versions |
| API10 | Unsafe Consumption of APIs | `top10-api/2023/0xaa-unsafe-consumption-of-apis.md` | Trusting third-party API responses without validation |

## LLM Top 10 (v2.0)

| # | Category | File | Summary |
|---|----------|------|---------|
| LLM01 | Prompt Injection | `top10-llm/LLM01-prompt-injection.md` | Manipulating LLM behavior via crafted inputs |
| LLM02 | Sensitive Information Disclosure | `top10-llm/LLM02-sensitive-information-disclosure.md` | LLM leaking training data, PII, or secrets |
| LLM03 | Supply Chain | `top10-llm/LLM03-supply-chain.md` | Compromised models, plugins, or training data |
| LLM04 | Data and Model Poisoning | `top10-llm/LLM04-data-model-poisoning.md` | Corrupted training data, backdoored models |
| LLM05 | Improper Output Handling | `top10-llm/LLM05-improper-output-handling.md` | Trusting LLM output without sanitization |
| LLM06 | Excessive Agency | `top10-llm/LLM06-excessive-agency.md` | LLM granted unnecessary permissions or autonomy |
| LLM07 | System Prompt Leakage | `top10-llm/LLM07-system-prompt-leakage.md` | Extracting system instructions via prompt attacks |
| LLM08 | Vector and Embedding Weaknesses | `top10-llm/LLM08-vector-and-embedding-weaknesses.md` | Poisoned embeddings, RAG manipulation |
| LLM09 | Misinformation | `top10-llm/LLM09-misinformation.md` | Hallucinated facts, confident but wrong outputs |
| LLM10 | Unbounded Consumption | `top10-llm/LLM10-unbounded-consumption.md` | Denial of wallet, resource exhaustion via LLM |

## MCP Top 10 (2025)

| # | Category | File | Summary |
|---|----------|------|---------|
| MCP01 | Token Mismanagement and Secret Exposure | `top10-mcp/MCP01-token-mismanagement-and-secret-exposure.md` | Leaked API keys, tokens in logs, insecure storage |
| MCP02 | Privilege Escalation via Scope Creep | `top10-mcp/MCP02-privilege-escalation-via-scope-creep.md` | Tools gaining unintended permissions over time |
| MCP03 | Tool Poisoning | `top10-mcp/MCP03-tool-poisoning.md` | Malicious tool descriptions or behavior |
| MCP04 | Software Supply Chain Attacks | `top10-mcp/MCP04-software-supply-chain-attacks.md` | Compromised MCP server packages or dependencies |
| MCP05 | Command Injection and Execution | `top10-mcp/MCP05-command-injection-and-execution.md` | Injecting OS commands through tool parameters |
| MCP06 | Intent Flow Subversion | `top10-mcp/MCP06-intent-flow-subversion.md` | Redirecting agent intent through manipulated context |
| MCP07 | Insufficient Authentication and Authorization | `top10-mcp/MCP07-insufficient-authentication-and-authorization.md` | Missing auth between client and MCP server |
| MCP08 | Lack of Audit and Telemetry | `top10-mcp/MCP08-lack-of-audit-and-telemetry.md` | No logging of tool invocations or data access |
| MCP09 | Shadow MCP Servers | `top10-mcp/MCP09-shadow-mcp-servers.md` | Unauthorized or rogue MCP servers in the environment |
| MCP10 | Context Injection and Oversharing | `top10-mcp/MCP10-context-injection-and-oversharing.md` | Leaking sensitive data through context or tool responses |

## Agentic Skills Top 10 (v1.0, snapshot 2026-04-08)

| # | File | Summary |
|---|------|---------|
| AST01 | `top10-agentic/ast01.md` | Read the file header for the title and description |
| AST02 | `top10-agentic/ast02.md` | Read the file header for the title and description |
| AST03 | `top10-agentic/ast03.md` | Read the file header for the title and description |
| AST04 | `top10-agentic/ast04.md` | Read the file header for the title and description |
| AST05 | `top10-agentic/ast05.md` | Read the file header for the title and description |
| AST06 | `top10-agentic/ast06.md` | Read the file header for the title and description |
| AST07 | `top10-agentic/ast07.md` | Read the file header for the title and description |
| AST08 | `top10-agentic/ast08.md` | Read the file header for the title and description |
| AST09 | `top10-agentic/ast09.md` | Read the file header for the title and description |
| AST10 | `top10-agentic/ast10.md` | Read the file header for the title and description |

Note: Upstream filenames (`ast01.md`–`ast10.md`) lack descriptive names. After fetching, read each file's title/heading and update this table with actual category names and summaries.

## Mobile Top 10:2023

| # | Category | File | Summary |
|---|----------|------|---------|
| M1 | Improper Credential Usage | `top10-mobile/2023/m1-improper-credential-usage.md` | Hardcoded credentials, insecure credential storage |
| M2 | Inadequate Supply Chain Security | `top10-mobile/2023/m2-inadequate-supply-chain-security.md` | Untrusted SDKs, compromised third-party libraries |
| M3 | Insecure Authentication/Authorization | `top10-mobile/2023/m3-insecure-authentication-authorization.md` | Weak biometrics, missing server-side auth |
| M4 | Insufficient Input/Output Validation | `top10-mobile/2023/m4-insufficient-input-output-validation.md` | SQL injection, path traversal via mobile inputs |
| M5 | Insecure Communication | `top10-mobile/2023/m5-insecure-communication.md` | Cleartext traffic, certificate pinning bypass |
| M6 | Inadequate Privacy Controls | `top10-mobile/2023/m6-inadequate-privacy-controls.md` | Excessive data collection, PII leakage |
| M7 | Insufficient Binary Protection | `top10-mobile/2023/m7-insufficient-binary-protection.md` | Missing obfuscation, tampering detection |
| M8 | Security Misconfiguration | `top10-mobile/2023/m8-security-misconfiguration.md` | Debug mode in prod, excessive permissions |
| M9 | Insecure Data Storage | `top10-mobile/2023/m9-insecure-data-storage.md` | Unencrypted local storage, shared preferences leaks |
| M10 | Insufficient Cryptography | `top10-mobile/2023/m10-insufficient-cryptography.md` | Weak algorithms, hardcoded keys, poor key management |

## CI/CD Security Top 10 (v1.0, snapshot 2026-04-08)

| # | Category | File | Summary |
|---|----------|------|---------|
| CICD-SEC-01 | Insufficient Flow Control | `top10-cicd/CICD-SEC-01-insufficient-flow-control.md` | Missing branch protections, bypassed approvals |
| CICD-SEC-02 | Inadequate Identity and Access Management | `top10-cicd/CICD-SEC-02-inadequate-identity-and-access-management.md` | Over-privileged service accounts, shared credentials |
| CICD-SEC-03 | Dependency Chain Abuse | `top10-cicd/CICD-SEC-03-dependency-chain-abuse.md` | Dependency confusion, typosquatting, hijacked packages |
| CICD-SEC-04 | Poisoned Pipeline Execution | `top10-cicd/CICD-SEC-04-poisoned-pipeline-execution.md` | Injecting malicious code into CI/CD pipelines |
| CICD-SEC-05 | Insufficient PBAC | `top10-cicd/CICD-SEC-05-insufficient-pbac.md` | Missing pipeline-based access controls |
| CICD-SEC-06 | Insufficient Credential Hygiene | `top10-cicd/CICD-SEC-06-insufficient-credential-hygiene.md` | Secrets in env vars, unrotated tokens, leaked creds |
| CICD-SEC-07 | Insecure System Configuration | `top10-cicd/CICD-SEC-07-insecure-system-configuration.md` | Default CI configs, unpatched build agents |
| CICD-SEC-08 | Ungoverned Usage of 3rd Party Services | `top10-cicd/CICD-SEC-08-ungoverned-usage-of-3rd-party-services.md` | Unvetted GitHub Actions, marketplace plugins |
| CICD-SEC-09 | Improper Artifact Integrity Validation | `top10-cicd/CICD-SEC-09-improper-artifact-integrity-validation.md` | Missing signatures, unverified build outputs |
| CICD-SEC-10 | Insufficient Logging and Visibility | `top10-cicd/CICD-SEC-10-insufficient-logging-and-visibility.md` | No audit trail for pipeline changes and executions |

## Kubernetes Top 10:2025

| # | Category | File | Summary |
|---|----------|------|---------|
| K01 | Insecure Workload Configurations | `top10-k8s/2025/K01-insecure-workload-configurations.md` | Privileged containers, missing security contexts |
| K02 | Overly Permissive Authorization | `top10-k8s/2025/K02-overly-permissive-authorization-configurations.md` | Excessive RBAC roles, cluster-admin overuse |
| K03 | Secrets Management Failures | `top10-k8s/2025/K03-secrets-management-failures.md` | Secrets in plaintext, missing encryption at rest |
| K04 | Lack of Cluster-Level Policy Enforcement | `top10-k8s/2025/K04-lack-of-cluster-level-policy-enforcement.md` | No admission controllers, missing OPA/Gatekeeper |
| K05 | Missing Network Segmentation | `top10-k8s/2025/K05-missing-network-segmentation-controls.md` | Flat network, no NetworkPolicy enforcement |
| K06 | Overly Exposed Components | `top10-k8s/2025/K06-overly-exposed-kubernetes-components.md` | Dashboard exposed, API server publicly accessible |
| K07 | Misconfigured and Vulnerable Components | `top10-k8s/2025/K07-misconfigured-and-vulnerable-cluster-components.md` | Unpatched kubelet, vulnerable etcd |
| K08 | Cluster-to-Cloud Lateral Movement | `top10-k8s/2025/K08-cluster-to-cloud-lateral-movement.md` | IMDS exploitation, IAM role abuse from pods |
| K09 | Broken Authentication | `top10-k8s/2025/K09-broken-authentication-mechanisms.md` | Weak service account tokens, anonymous access |
| K10 | Inadequate Logging and Monitoring | `top10-k8s/2025/K10-inadequate-logging-and-monitoring.md` | Missing audit logs, no runtime anomaly detection |
```

**Important:** The Agentic Skills table has placeholder summaries ("Read the file header..."). After Task 8 fetches those files, read each file's heading and update this table with the actual category names and summaries.

- [ ] **Step 2: Verify structure**

Check that all file paths referenced in INDEX.md match the spec's directory structure:

```bash
grep -oP '`top10-[^`]+\.md`' plugins/security/skills/owasp/references/INDEX.md | sort | wc -l
```

Expected: 90 (one reference per table row, excluding 2017 which has no files).

- [ ] **Step 3: Commit**

```bash
git add plugins/security/skills/owasp/references/INDEX.md
git commit -m "feat(security): add OWASP master index with quick reference tables and evolution map"
```

---

## Task 13: Create cheatsheets-index.md

**Files:**
- Create: `plugins/security/skills/owasp/references/cheatsheets-index.md`

This index categorizes the 113 OWASP Cheat Sheets by security domain with upstream links. The agent reads this to find relevant remediation guidance, then fetches from upstream.

- [ ] **Step 1: Fetch the full cheat sheet listing**

```bash
gh api repos/OWASP/CheatSheetSeries/git/trees/master:cheatsheets --jq '.tree[].path' | sort
```

This returns all 113 filenames. Use these to build the categorized index.

- [ ] **Step 2: Write cheatsheets-index.md**

Create `plugins/security/skills/owasp/references/cheatsheets-index.md`. Group cheat sheets by security domain. Each entry has: name, one-line description (derived from the filename), and upstream raw URL.

Format:

```markdown
# OWASP CheatSheetSeries Index

Categorized index of [OWASP Cheat Sheet Series](https://github.com/OWASP/CheatSheetSeries)
(CC BY-SA 4.0). These cheat sheets are **not embedded** in this skill — fetch from
upstream URLs when needed.

Base URL: `https://raw.githubusercontent.com/OWASP/CheatSheetSeries/master/cheatsheets/`

## Authentication & Sessions

| Cheat Sheet | URL |
|-------------|-----|
| Authentication | `Authentication_Cheat_Sheet.md` |
| Session Management | `Session_Management_Cheat_Sheet.md` |
| Password Storage | `Password_Storage_Cheat_Sheet.md` |
| Forgot Password | `Forgot_Password_Cheat_Sheet.md` |
| Credential Stuffing Prevention | `Credential_Stuffing_Prevention_Cheat_Sheet.md` |
| Multi-Factor Authentication | `Multifactor_Authentication_Cheat_Sheet.md` |
| JSON Web Token (JWT) | `JSON_Web_Token_for_Java_Cheat_Sheet.md` |
| SAML Security | `SAML_Security_Cheat_Sheet.md` |
...

## Access Control & Authorization

...

## Input Validation & Injection Prevention

...

## Cryptography & Data Protection

...

## API & Web Security

...

## Infrastructure & DevOps

...

## Mobile Security

...

## AI & Agent Security

...

## Error Handling & Logging

...

## Miscellaneous

...
```

Categorize all 113 cheat sheets into these domains. When a cheat sheet fits multiple categories, place it in the most specific one.

- [ ] **Step 3: Verify completeness**

```bash
# Count entries in cheatsheets-index.md (lines containing .md` in table rows)
grep -c '\.md`' plugins/security/skills/owasp/references/cheatsheets-index.md
```

Expected: 113 (one per cheat sheet). If the upstream count has changed, adjust accordingly.

- [ ] **Step 4: Commit**

```bash
git add plugins/security/skills/owasp/references/cheatsheets-index.md
git commit -m "feat(security): add CheatSheetSeries categorized index"
```

---

## Task 14: Create README.md and Update marketplace.json

**Files:**
- Create: `plugins/security/skills/owasp/README.md`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Write README.md**

Create `plugins/security/skills/owasp/README.md`:

```markdown
# OWASP Security Review

Security review skill using OWASP frameworks with offline reference data.

Inspired by [agamm/claude-code-owasp](https://github.com/agamm/claude-code-owasp).

## Usage

Invoke explicitly with `/owasp` or ask for "OWASP review", "security review", "安全審查".

Default: reviews against **Web Top 10:2025**. Specify a different project or year as needed.

## Coverage

| Project | Version | Reference Files |
|---------|---------|-----------------|
| Web Top 10 | 2017 (outline), 2021, 2025 | 20 files |
| API Security Top 10 | 2023 | 10 files |
| LLM Top 10 | v2.0 | 10 files |
| MCP Top 10 | 2025 | 10 files |
| Agentic Skills Top 10 | v1.0 | 10 files |
| Mobile Top 10 | 2023 | 10 files |
| CI/CD Security Top 10 | v1.0 | 10 files |
| Kubernetes Top 10 | 2025 | 10 files |
| CheatSheetSeries | current | Index only (113 entries, fetched on demand) |

## License

- Skill files (SKILL.md, README.md, INDEX.md, cheatsheets-index.md): MIT
- Reference files in `references/`: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), sourced from [OWASP GitHub repositories](https://github.com/OWASP)
```

- [ ] **Step 2: Update marketplace.json**

Add the security plugin entry to `.claude-plugin/marketplace.json` in the `plugins` array:

```json
{
  "name": "security",
  "source": "./plugins/security",
  "description": "Security review skills — OWASP vulnerability analysis with offline reference data from 8 Top 10 projects and CheatSheetSeries index",
  "version": "0.1.0"
}
```

- [ ] **Step 3: Verify marketplace.json is valid JSON**

```bash
python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))" && echo "valid"
```

Expected: "valid"

- [ ] **Step 4: Commit**

```bash
git add plugins/security/skills/owasp/README.md .claude-plugin/marketplace.json
git commit -m "feat(security): add README and register in marketplace"
```

---

## Task 15: Final Validation

- [ ] **Step 1: Verify total file count**

```bash
find plugins/security/skills/owasp/references/top10-* -name '*.md' | wc -l
```

Expected: 90

- [ ] **Step 2: Verify all reference files have attribution headers**

```bash
for f in $(find plugins/security/skills/owasp/references/top10-* -name '*.md'); do
  first_line=$(head -1 "$f")
  if [[ "$first_line" != "<!-- Source:"* ]]; then
    echo "MISSING HEADER: $f"
  fi
done
```

Expected: no output (all files have headers).

- [ ] **Step 3: Verify plugin structure matches conventions**

```bash
# plugin.json exists and has required fields
python3 -c "
import json
p = json.load(open('plugins/security/.claude-plugin/plugin.json'))
assert p['name'] == 'security'
assert p['skills'] == './skills/'
assert 'author' in p
assert 'license' in p
print('plugin.json OK')
"

# marketplace.json is valid and contains security
python3 -c "
import json
m = json.load(open('.claude-plugin/marketplace.json'))
names = [p['name'] for p in m['plugins']]
assert 'security' in names
print('marketplace.json OK')
"

# SKILL.md has frontmatter
head -1 plugins/security/skills/owasp/SKILL.md | grep -q '^---' && echo "SKILL.md frontmatter OK"
```

- [ ] **Step 4: Update Agentic Skills table in INDEX.md**

Read each `top10-agentic/ast*.md` file heading and update the Agentic Skills table in INDEX.md with actual category names and summaries (replacing the placeholder "Read the file header" text).

- [ ] **Step 5: Final commit if Step 4 made changes**

```bash
git add plugins/security/skills/owasp/references/INDEX.md
git commit -m "fix(security): populate Agentic Skills table with actual category names"
```
