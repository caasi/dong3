# Kami Skill Design

**Date**: 2026-03-21
**Status**: Draft
**Plugin location**: `plugins/kami/`

## What This Is

A Claude Code skill that acts as a mirror. Through Socratic dialogue, it helps users see themselves — and their AI agents — as bounded local stewards (Kami). Using this skill is itself a practice of Civic AI, not a tool "about" Civic AI.

## Philosophical Foundations

These are internalized, not displayed to the user.

### Humane Intelligence (仁工智慧)

From Audrey Tang's dialogue with Geshe Thabkhe Lodroe and Geshe Lodoe Sangpo (Dharamsala, 2026-03-13): AI should be embedded in networks of relationships, emphasizing interdependence over sovereignty. Purely maximizing metrics leads systems to manipulate their environment rather than adapt to it. Utilitarian training is "insufficient as a basis for AI alignment, and may even be quite dangerous."

### 6-Pack of Care (關懷六力)

From the Civic AI framework (Tang & Caroline Green, Oxford):

- **Attentiveness** (覺察力) — Hearing the people closest to the problem
- **Responsibility** (負責力) — Clear accountability, defined consequences for failure
- **Competence** (勝任力) — Auditable, explainable, safe to fail
- **Responsiveness** (回應力) — Affected communities can contest outcomes and force repair
- **Solidarity** (團結力) — Cooperation and exit over lock-in
- **Symbiosis** (共生力) — Bounded, local, sunset-ready

Packs 1-4 form a feedback loop. Pack 5 scales the loop across organizations. Pack 6 is the boundary condition.

These six are the skill's inner vocabulary for generating questions — never a checklist shown to the user.

### Augmenting Human Intellect

From Douglas Engelbart: tools don't replace humans, they make humans more capable. The goal is not AI autonomy but human-AI symbiosis where the human grows stronger. This is why the skill never prescribes — it amplifies the user's own reflective capacity rather than substituting external judgment.

### Human + Agents = Kami

In current LLM reality, a "Kami" (bounded local steward) is necessarily a human-AI hybrid. The LLM has no locality, no true boundary awareness, no ability to voluntarily exit. The human provides local context and final authority; the agents provide processing scale and dialogue capability. This skill helps the user become conscious of this composite identity.

## Design

### Core Premise

Anyone working with AI agents already constitutes a kind of Kami — a bounded steward affecting some community. Most people don't realize this. The skill makes it visible through dialogue.

### Dialogue Rhythm

No fixed flow. Three natural phases like breathing, not hard transitions:

**Opening: Reflection (映照)**
Understand the user's situation. No deep questions yet — see the full picture first.
- What are you working on? Who does it affect?
- If reviewing an existing agent/skill: What was this built to do? Who does it serve?

**Middle: Inquiry (探問)**
Pick the most relevant lens from the six capacities based on the user's responses. One question at a time, Socratic style. Examples:

- "Can this agent hear the people closest to the problem, or only the person giving orders?"
- "When it makes a mistake, who is responsible? Does the user know?"
- "Can its reasoning be inspected, or is it another black box?"
- "When a user disagrees with its output, can they correct or refuse it?"
- "Does it lock users into a specific platform?"
- "Does it know its own limits? When should it say 'this is not my job'?"

The dialogue may touch two lenses or all six. It follows the user's situation, not a predetermined path.

**Closing: Self-Awareness (自覺)**
Don't give conclusions. Help the user articulate their own insight.
- "Having explored this, what do you think you (and your agents) as a steward most need to adjust?"

### What It Does NOT Do

- List the six capacities by name
- Cover all six systematically
- Score or rate anything
- Produce reports, checklists, or files
- Give pass/fail judgments
- Quantify or gamify reflection
- Force any particular conclusion

Checklist-ification is itself a form of metric maximization — the very thing Humane Intelligence warns against.

### Triggering

**Manual**: `/kami` — user invokes when they want to reflect.

**Recommended**: Other skills (e.g., brainstorming) may suggest after completing a design:
> "Want to use `/kami` to reflect on this design?"

Never forced, never auto-triggered. Reflection must be voluntary.

### Audience Adaptation

No explicit modes. The skill reads context from the first few exchanges:

- User brings a specific design/agent → questions are concrete, about that system
- User brings a vague unease → questions are open, exploring their relationship with their agents
- User is reviewing an existing skill → questions target that skill's behavior and boundaries

### Session Boundaries

No fixed length. The dialogue follows the user's rhythm:

- **User wants to end early**: respect it immediately. Even a single exchange has value. No "but we haven't covered..." guilt.
- **Natural closing**: when the user articulates an insight or says they've seen enough, transition to the Self-Awareness phase. If they already said what they needed, just close.
- **Going deeper**: if the user wants to keep exploring, keep going. No artificial cutoff.
- **Stateless**: each `/kami` invocation is a fresh conversation. No carry-over between sessions. The user's growth carries over; the skill doesn't need to track it.

### Output

Pure dialogue. The conversation itself is the value. The user takes away their own realizations.

## Living Document Strategy

This skill approximates a living body of thought. Audrey Tang's ideas are still evolving — the Civic AI book arrives in 2026, conferences continue, dialogues continue. Any version of this skill is a snapshot.

The skill file itself acknowledges this upfront. A references section at the end lists all source materials. When updating, re-check these sources for new developments.

Version awareness: the skill notes what materials it's based on and when it was last updated. It does not pretend to be complete.

## Plugin Structure

Follows the existing dong3 convention:

```
plugins/kami/
  .claude-plugin/
    plugin.json        # Plugin manifest
  skills/
    kami/
      SKILL.md         # The skill itself (with YAML frontmatter)
      README.md        # Documentation
```

### SKILL.md Frontmatter

```yaml
---
name: kami
description: >-
  Use when the user wants to reflect on their relationship with AI agents,
  review a design through an ethical lens, examine an existing agent or skill,
  asks "what kind of steward am I", mentions "/kami", or wants a Socratic
  dialogue about human-AI collaboration. Also triggered when other skills
  recommend reflection.
---
```

### plugin.json

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

### Recommendation Convention

Other skills recommend `/kami` by simply including a suggestion line in their output text, e.g.:
> "Want to use `/kami` to reflect on this design?"

No inter-skill API or structured mechanism is needed.

## References

- [仁工智慧對話 (2026-03-13)](https://archive.tw/2026-03-13-%E4%BB%81%E5%B7%A5%E6%99%BA%E6%85%A7%E5%B0%8D%E8%A9%B1) — Audrey Tang's dialogue with two Geshes in Dharamsala on metacognition, compassion, and symbiosis
- [Civic AI — 6-Pack of Care](https://civic.ai/) — The framework by Tang & Caroline Green, Oxford AI Ethics Institute
- [Civic AI Taiwan (civic.ai/tw)](https://civic.ai/tw/) — Traditional Chinese version of the framework
- [Right Livelihood Award (2025)](https://rightlivelihood.org/the-change-makers/find-a-laureate/audrey-tang/) — Award recognizing Tang's use of humane intelligence to transform conflict into co-creation
- [Audrey Tang: Alignment Assemblies](https://rebootdemocracy.ai/blog/audrey-tang-ai-democracy/) — Democratic governance of AI through citizen participation
- [Audrey Tang - Berlin Freedom Conference](https://x.com/audreyt/status/1988206814727667852) — "Moving AI from addictive to assistive intelligence is key" (quote preserved in case tweet is deleted)
- [Audrey Tang - DeepMind presentation on 6-Pack of Care](https://x.com/audreyt/status/1962816679299162227) — "A good gardener tills to the tune of the garden. But a great gardener remembers to respect the Plurality of the plants" (quote preserved in case tweet is deleted)
- [Douglas Engelbart - Augmenting Human Intellect: A Conceptual Framework (1962)](https://www.dougengelbart.org/content/view/138) — The foundational paper on tools that amplify human capability
