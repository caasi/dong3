# dataflow

A Claude Code skill to explore an unfamiliar codebase together with you, one step at a time. The agent follows one value through the code and reads the types along its path.

## What it does

You read the code in your editor and ask one question. The agent answers that question, then stops, so that you choose the next step.

- **One value at a time.** The agent finds where the value is created, changed and read, and which code owns it.
- **Types on the path.** If the code has a type system, the agent also reads what each type allows and forbids, what each signature promises, and where outside data becomes a typed value. A question about types starts there.
- **Evidence for each finding.** A finding has one of two marks:
  - `[read]` with `file:line`: the agent read it in the code.
  - `[spike]` with the command and its output: the agent ran code and saw the result.
- **Spikes on a copy.** Before an answer, the agent runs at least one small spike on the most important finding about behavior. A spike calls the code from outside, on a copy of the files. Before the first install or build in the copy, the agent asks you once.
- **Next steps.** Each answer ends with two lists:
  - **Read next:** two or three `vim +<line> <path>` lines that you can paste, each with one reason.
  - **Spike next:** one or two facts that the agent will check next.

The answer uses the language of your question.

## Usage

Ask about a value or a type, in your own words:

```
How does input become the [a, b, c] on the screen?
How does the type of useSpace stop me from passing a plain string?
```

Claude starts the skill when the question matches. You can also start it yourself:

- Type `/dataflow` at the start of a message.
- Write `/dataflow` or `/types` inside a sentence, for example `How do these /types stop me from calling useSpace wrongly?`

Note: `/types` at the start of a message is not a command. Use it inside a sentence.

The skill also works after an answer from the `how` or `why` skills of [pstack](https://github.com/cursor/plugins/tree/main/pstack). It starts from what that answer found.

## Test results

The skill was tested with 30 headless `claude -p` runs on a copy of a React + ReScript + TypeScript site. Each question had 5 runs: 2 with Opus, 2 with Sonnet and 1 with Haiku. The control runs used `--disallowed-tools Skill`.

| Question | Skill started |
|---|---|
| A type question, plain words | 4 of 5 |
| A data-flow question, plain words | 4 of 5 |
| A question with `/types` inside the sentence | 5 of 5 |
| An unrelated question about the README | 0 of 5 (correct) |

- In each run that started the skill, the answer had `[read]` or `[spike]` marks and both lists at the end. No control run had them.
- All `Read next` paths were relative to the repository root.
- Opus and Sonnet ran a spike, or said that a spike needed an install, in 12 of 12 runs.
- Haiku did not start the skill from a plain-words question in any run. With Haiku, write `/dataflow` or `/types` in the message.
- With the skill, answers were longer than in the control runs, because of the spike output and the two lists.

The design record is [issue #91](https://github.com/caasi/dong3/issues/91).

## Install

```bash
claude plugin marketplace add caasi/dong3
claude plugin install dataflow@caasi-dong3
```

If you have a personal skill named `dataflow` in `~/.claude/skills/`, remove it first. Two skills with the same name compete for `/dataflow`.
