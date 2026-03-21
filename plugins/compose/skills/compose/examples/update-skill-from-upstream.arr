-- Workflow: check upstream binary repo and update compose skill to match
-- Triggers: new release of ocaml-compose-dsl, grammar changes, new features

-- Phase 1: gather current state from upstream and local skill
-- Note: >>> binds looser than &&&, so each seq chain needs explicit grouping
(
  (fetch_release(repo: "caasi/ocaml-compose-dsl") -- ref: Bash("gh api repos/.../releases/latest")
    >>> extract(fields: [tag_name, body, assets])) -- release version, changelog, binary assets
  &&&
  (fetch_readme(repo: "caasi/ocaml-compose-dsl")  -- ref: Bash("gh api repos/.../contents/README.md")
    >>> extract(fields: [grammar, examples, usage])) -- new EBNF, examples, CLI flags
  &&&
  read(source: "skills/compose/SKILL.md")          -- ref: Read
  &&&
  read(source: "skills/compose/references/dsl-grammar.md") -- ref: Read
)
  -- Phase 2: diff upstream vs local, produce change list
  >>> diff(upstream: release_info, local: skill_files) -- ref: Agent("compare grammar, combinators, CLI flags, examples")
  >>> plan(changes: required_updates)                  -- ref: Agent("list what needs updating")

  -- Phase 3: apply updates
  >>> (
    update(target: "SKILL.md", sections: [prerequisites, combinators, workflow, patterns])  -- ref: Edit
    ***
    update(target: "references/dsl-grammar.md", sections: [ebnf, combinators, examples])    -- ref: Edit
    ***
    update(target: "examples/", action: add_new_examples)  -- ref: Write
  )

  -- Phase 4: validate updated DSL examples still parse
  >>> collect_arr_files(from: "skills/compose/examples/")  -- ref: Glob("**/*.arr")
  >>> validate_all(checker: "ocaml-compose-dsl")           -- ref: Bash("ocaml-compose-dsl *.arr")

  -- Phase 5: verify binary version requirement
  >>> check_version(binary: "ocaml-compose-dsl", minimum: "0.4.0") -- ref: Bash("ocaml-compose-dsl --version")
