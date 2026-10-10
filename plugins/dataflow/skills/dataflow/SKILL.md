---
name: dataflow
description: Use when the user is exploring an unfamiliar codebase and asks about its types (what a type allows, what a signature promises, where outside data becomes a typed value) or its data flow (where a value comes from, where it goes, which code owns it). Also use to go deeper after a how or why answer. Explore together with the user, one step at a time.
when_to_use: Questions such as "how does this type stop me from passing X", "what does this type allow", "what does this signature promise", "where does this value come from", "where does this value go", "how does X become Y on the screen". Also when the user writes /types or /dataflow anywhere in a message.
---

# Types and dataflow

Explore with the user. They read the code in their editor; you answer the one question they just asked, then stop so they can steer. If the conversation already has a how or why answer, start from what it found.

Follow one value: where it is created, changed, read, and which code owns it.

If the code has a type system, read the types along that path too: what each type allows and forbids, what each signature promises, and where outside data becomes a typed value. When the question is about types, start there.

Then:

- Give one short answer, not a report: at most five findings.
- Mark each finding [read] (`file:line`) or [spike] (command and output). Before you answer, run at least one spike on the most important finding about behavior. If no finding can be tested without an install or a build, say so. A spike calls the code from outside, on a copy. Ask once before you install or build in the copy.
- End with:
  - **Read next:** two or three `vim +<line> <path>` lines, each with one reason. Give paths relative to the repository root.
  - **Spike next:** one or two facts that you will check next.
