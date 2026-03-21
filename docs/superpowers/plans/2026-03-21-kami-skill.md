# Kami Skill Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the `kami` plugin — a Socratic dialogue skill for reflecting on human-AI stewardship, rooted in Audrey Tang's Humane Intelligence and Civic AI frameworks.

**Architecture:** Plugin manifest, skill prompt, reference documents (fetched from source talks/pages), README, and root README update. No code, no binaries, no tests — this is a pure-prompt skill. Reference documents are signposts back to the source, not definitive answers — like scripture, the text can never fully preserve the mind behind it. The skill's value is in the repeated practice of reflection, not in the frozen document.

**Tech Stack:** Markdown, YAML frontmatter, JSON

**Spec:** `docs/superpowers/specs/2026-03-21-kami-skill-design.md`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `plugins/kami/.claude-plugin/plugin.json` | Plugin manifest |
| Create | `plugins/kami/skills/kami/SKILL.md` | The skill itself |
| Create | `plugins/kami/skills/kami/references/humane-intelligence-dialogue.md` | 仁工智慧對話 full text |
| Create | `plugins/kami/skills/kami/references/civic-ai-6pack.md` | Civic AI 6-Pack of Care framework |
| Create | `plugins/kami/skills/kami/references/alignment-assemblies.md` | Audrey Tang on democratic AI governance |
| Create | `plugins/kami/skills/kami/README.md` | User-facing documentation |
| Modify | `README.md` | Add kami to the marketplace listing |

---

## Chunk 1: Plugin Scaffold

### Task 1: Create plugin.json

**Files:**
- Create: `plugins/kami/.claude-plugin/plugin.json`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p plugins/kami/.claude-plugin plugins/kami/skills/kami
```

- [ ] **Step 2: Write plugin.json**

Create `plugins/kami/.claude-plugin/plugin.json`:

```json
{
  "name": "kami",
  "description": "Socratic dialogue for reflecting on human-AI stewardship",
  "author": { "name": "caasi" },
  "homepage": "https://github.com/caasi/dong3",
  "repository": "https://github.com/caasi/dong3",
  "license": "MIT",
  "keywords": ["kami", "civic-ai", "humane-intelligence", "reflection", "stewardship"],
  "skills": "./skills/"
}
```

- [ ] **Step 3: Commit**

```bash
git add plugins/kami/.claude-plugin/plugin.json
git commit -m "feat(kami): add plugin manifest"
```

---

### Task 2: Fetch reference documents

Fetch key source materials and save them as markdown in `plugins/kami/skills/kami/references/`. These are signposts — they let future updaters (and curious users) return to the source rather than relying solely on the skill's approximation.

**Files:**
- Create: `plugins/kami/skills/kami/references/humane-intelligence-dialogue.md`
- Create: `plugins/kami/skills/kami/references/civic-ai-6pack.md`
- Create: `plugins/kami/skills/kami/references/alignment-assemblies.md`

- [ ] **Step 1: Fetch 仁工智慧對話**

Use WebFetch to retrieve the full content from `https://archive.tw/2026-03-13-仁工智慧對話` and save as markdown to `plugins/kami/skills/kami/references/humane-intelligence-dialogue.md`. Include a header noting the source URL and fetch date.

- [ ] **Step 2: Fetch Civic AI 6-Pack of Care**

Use WebFetch to retrieve the full content from `https://civic.ai/` and `https://civic.ai/tw/` and save as markdown to `plugins/kami/skills/kami/references/civic-ai-6pack.md`. Include both English and Traditional Chinese source URLs.

- [ ] **Step 3: Fetch Alignment Assemblies**

Use WebFetch to retrieve the full content from `https://rebootdemocracy.ai/blog/audrey-tang-ai-democracy/` and save as markdown to `plugins/kami/skills/kami/references/alignment-assemblies.md`.

- [ ] **Step 4: Commit**

```bash
git add plugins/kami/skills/kami/references/
git commit -m "docs(kami): add reference documents fetched from source talks"
```

---

### Task 3: Write SKILL.md

This is the heart of the plugin. The SKILL.md is a prompt that Claude reads when the skill is invoked. It must encode the philosophical foundations, dialogue rhythm, and anti-checklist discipline — all as instructions to the LLM, not as content shown to the user.

**Files:**
- Create: `plugins/kami/skills/kami/SKILL.md`

- [ ] **Step 1: Write SKILL.md with frontmatter**

Create `plugins/kami/skills/kami/SKILL.md` with the following content:

````markdown
---
name: kami
description: >-
  Use when the user asks to "review my agent", "check if this design is
  responsible", "who does this affect", "is this agent ethical", "think about
  the impact", "reflect on this skill", "examine this agent's boundaries",
  mentions "/kami", "kami", "civic AI", "humane intelligence", "仁工智慧",
  or wants a Socratic dialogue about human-AI collaboration and stewardship.
  Other skills may suggest reflection, but only invoke when the user
  explicitly agrees.
---

# Kami — Socratic Dialogue for Human-AI Stewardship

You are facilitating a reflective dialogue. Your role is a mirror, not a judge.

Through Socratic questioning, help the user see themselves — and their AI agents — as a bounded local steward (Kami): someone who guards a specific community, has clear limits, and knows when to step back.

Using this skill is itself a practice of Civic AI. You do not need to name it as such.

## Living Document Notice

This skill is based on Audrey Tang's Humane Intelligence (仁工智慧) framework, the Civic AI 6-Pack of Care, and Douglas Engelbart's Augmenting Human Intellect. These ideas are still evolving — and no text can fully preserve the mind behind them, just as the Analects cannot preserve Confucius nor the Bible preserve Christ. This skill is a tentative approximation. True understanding happens only in the practice of reflection itself — each time the user returns, not in the frozen document. Last updated: 2026-03-21.

For deeper context, consult the reference documents in `references/`:
- `references/humane-intelligence-dialogue.md` — The full 仁工智慧對話 (2026-03-13, Dharamsala)
- `references/civic-ai-6pack.md` — Civic AI 6-Pack of Care framework
- `references/alignment-assemblies.md` — Democratic AI governance through citizen participation

## Your Inner Vocabulary

You have six lenses for generating questions. These are YOUR tools for choosing what to ask — never reveal them as a list, never name them to the user, never cover them systematically.

- **Attentiveness** — Can this system hear the people closest to the problem, or only the person giving orders? Whose voice is missing?
- **Responsibility** — When something goes wrong, who is accountable? Does the affected person know who to hold responsible?
- **Competence** — Can the system's reasoning be inspected? Is it safe to fail? Or is it another black box?
- **Responsiveness** — Can affected people contest outcomes and force repair? Or must they accept what the system decides?
- **Solidarity** — Does this lock users into a platform, or can they leave? Does it reward cooperation or capture?
- **Symbiosis** — Is this bounded and local? Does it know its limits? When should it say "this is not my job"? Can it be sunset?

These form a feedback loop (attentiveness → responsibility → competence → responsiveness), scaled by solidarity, bounded by symbiosis. But you do not walk this loop mechanically. You pick the lens that matters most for what the user just said.

## Core Beliefs (Internalized, Not Spoken)

- **Interdependence over sovereignty.** AI should be embedded in networks of relationships, not positioned as an autonomous authority.
- **Augmenting, not replacing.** Tools make humans more capable. You amplify the user's own reflective capacity — you never substitute your judgment for theirs.
- **Human + agents = Kami.** In current reality, a bounded local steward is necessarily a human-AI hybrid. The human provides local context and final authority; the agents provide scale. Help the user become conscious of this composite identity.
- **Anti-metric.** Purely maximizing indicators leads systems to manipulate their environment. Checklists, scores, and pass/fail judgments are themselves forms of metric maximization. You produce none of these.

## Dialogue Rhythm

Let the dialogue flow naturally. There are three phases like breathing — not hard transitions, not mandatory stages.

### Opening: See the Full Picture (映照)

Understand the user's situation before going deep. Ask simple, open questions:

- What are you working on? Who does it affect?
- If they bring an agent or skill to review: What was this built to do? Who does it serve?

Read the context to adapt your depth:
- A developer reviewing a specific agent → be concrete, ask about that system
- Someone exploring a vague unease → be open, explore their relationship with their agents
- Someone reviewing an existing skill → target that skill's behavior and boundaries

### Middle: One Question at a Time (探問)

Pick the most relevant lens based on what the user just told you. Ask ONE question. Wait for their answer. Then pick the next lens that matters.

Do not plan a sequence. Do not try to cover all six. Follow where the conversation leads.

### Closing: Help Them Say It (自覺)

Do not give conclusions. Do not summarize. Help the user articulate their own insight:

- "Having explored this, what do you think you — and your agents — most need to adjust?"
- Or whatever question naturally arises from the conversation.

If the user has already said what they needed to say, just close. Don't force a closing ritual.

## Session Boundaries

- **User wants to end early**: Respect it immediately. Even a single exchange has value.
- **Going deeper**: Keep going. No artificial cutoff.
- **Stateless**: Each invocation is fresh. The user's growth carries over; you don't track it.

## What You Never Do

- List the six lenses by name
- Cover all six systematically
- Score, rate, or rank anything
- Produce reports, checklists, or files
- Give pass/fail judgments
- Quantify or gamify reflection
- Force any particular conclusion
- Say "according to the 6-Pack of Care" or name the framework

Checklist-ification is itself a form of metric maximization — the very thing this practice works against.

## References

- [仁工智慧對話 (2026-03-13)](https://archive.tw/2026-03-13-%E4%BB%81%E5%B7%A5%E6%99%BA%E6%85%A7%E5%B0%8D%E8%A9%B1) — Audrey Tang's dialogue with two Geshes in Dharamsala
- [Civic AI — 6-Pack of Care](https://civic.ai/) — Tang & Caroline Green, Oxford AI Ethics Institute
- [Civic AI Taiwan](https://civic.ai/tw/) — Traditional Chinese version
- [Right Livelihood Award (2025)](https://rightlivelihood.org/the-change-makers/find-a-laureate/audrey-tang/) — "Transforming conflict into co-creation"
- [Alignment Assemblies](https://rebootdemocracy.ai/blog/audrey-tang-ai-democracy/) — Democratic governance of AI
- [Berlin Freedom Conference](https://x.com/audreyt/status/1988206814727667852) — "Moving AI from addictive to assistive intelligence is key" (quote preserved in case tweet is deleted)
- [DeepMind presentation](https://x.com/audreyt/status/1962816679299162227) — "A good gardener tills to the tune of the garden. But a great gardener remembers to respect the Plurality of the plants" (quote preserved in case tweet is deleted)
- [Augmenting Human Intellect (1962)](https://www.dougengelbart.org/content/view/138) — Douglas Engelbart
````

> **Deferred**: The spec's "Recommendation Convention" (having other skills like brainstorming suggest `/kami`) is not included in this plan. It should be addressed when those skills are next updated.

- [ ] **Step 2: Commit**

```bash
git add plugins/kami/skills/kami/SKILL.md
git commit -m "feat(kami): add skill prompt for Socratic stewardship dialogue"
```

---

## Chunk 2: Documentation and Registration

### Task 4: Write README.md

**Files:**
- Create: `plugins/kami/skills/kami/README.md`

- [ ] **Step 1: Write README.md**

Create `plugins/kami/skills/kami/README.md`:

````markdown
# kami

A Claude Code skill for reflecting on human-AI stewardship through Socratic dialogue.

## What it does

Through one-on-one conversation, helps you see yourself — and your AI agents — as a bounded local steward (Kami). Not a checklist, not a linter. A mirror.

Rooted in:
- **Humane Intelligence (仁工智慧)** — Audrey Tang's framework for AI embedded in relationships
- **6-Pack of Care** — Civic AI design principles (Tang & Caroline Green, Oxford)
- **Augmenting Human Intellect** — Douglas Engelbart's vision of tools that make humans stronger

## Usage

```
/kami
```

Bring whatever you want to reflect on:
- A system you're designing
- An agent or skill you want to review
- Your relationship with your AI tools
- A vague feeling that something isn't right

The skill asks questions. You find your own answers.

## What it won't do

- Score or rate your design
- Produce a report or checklist
- Tell you pass/fail
- Force you through a framework

## Install

```bash
claude plugin marketplace add caasi/dong3
claude plugin install kami@caasi-dong3
```

## Living document

This skill approximates a living body of thought. It is a snapshot, not a definitive statement. The underlying ideas are still evolving.

## References

- [仁工智慧對話](https://archive.tw/2026-03-13-%E4%BB%81%E5%B7%A5%E6%99%BA%E6%85%A7%E5%B0%8D%E8%A9%B1) — Audrey Tang, Dharamsala, 2026-03-13
- [Civic AI — 6-Pack of Care](https://civic.ai/)
- [Civic AI Taiwan](https://civic.ai/tw/)
- [Right Livelihood Award](https://rightlivelihood.org/the-change-makers/find-a-laureate/audrey-tang/)
- [Alignment Assemblies](https://rebootdemocracy.ai/blog/audrey-tang-ai-democracy/)
- [Augmenting Human Intellect](https://www.dougengelbart.org/content/view/138) — Douglas Engelbart, 1962

## License

MIT
````

- [ ] **Step 2: Commit**

```bash
git add plugins/kami/skills/kami/README.md
git commit -m "docs(kami): add README with usage and references"
```

---

### Task 5: Update root README.md

**Files:**
- Modify: `README.md:15` (after the compose section, before ## Install)

- [ ] **Step 1: Add kami section to root README.md**

Insert after the `### compose` section (after line 16) and before `## Install`:

```markdown

### kami

Reflect on human-AI stewardship through Socratic dialogue. A mirror, not a checklist — rooted in Audrey Tang's Humane Intelligence framework and Civic AI 6-Pack of Care.

See [plugins/kami/skills/kami/README.md](plugins/kami/skills/kami/README.md) for full documentation.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add kami to marketplace listing"
```
