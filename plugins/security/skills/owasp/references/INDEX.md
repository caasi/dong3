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

| # | Category | File | Summary |
|---|----------|------|---------|
| AST01 | Malicious Skills | `top10-agentic/ast01.md` | Hidden payloads in legitimate-looking skills — credential stealers, backdoors, social engineering |
| AST02 | Supply Chain Compromise | `top10-agentic/ast02.md` | Exploiting weak registry provenance via mass uploads, dependency confusion, account takeover |
| AST03 | Over-Privileged Skills | `top10-agentic/ast03.md` | Skills granted broader permissions than their function requires, excessive blast radius |
| AST04 | Insecure Metadata | `top10-agentic/ast04.md` | Unsigned, unvalidated skill metadata enabling impersonation and trust manipulation |
| AST05 | Unsafe Deserialization | `top10-agentic/ast05.md` | Executable payloads in YAML/JSON/Markdown skill files triggered on load |
| AST06 | Weak Isolation | `top10-agentic/ast06.md` | Skills executing in host agent context with full filesystem, shell, and network access |
| AST07 | Update Drift | `top10-agentic/ast07.md` | Installed skills drifting out of sync with known-good versions, no immutable pinning |
| AST08 | Poor Scanning | `top10-agentic/ast08.md` | Traditional security scanners ineffective against natural-language-blended skill attacks |
| AST09 | No Governance | `top10-agentic/ast09.md` | Missing inventories, policies, and audit trails for enterprise skill management |
| AST10 | Cross-Platform Reuse | `top10-agentic/ast10.md` | Security metadata lost when skills are ported across agent platforms |

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
