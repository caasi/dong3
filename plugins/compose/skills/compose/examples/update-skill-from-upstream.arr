-- Workflow: check upstream binary repo and align compose skill to match
-- Triggers: new release of ocaml-compose-dsl, grammar changes, new features
-- Covers: docs, examples, metadata (marketplace.json), review cycle
-- Demonstrates: let/lambda abstraction, semicolons, unit

let fetch_release = \repo ->
  fetch(repo: repo)                      -- ref: Bash("gh api repos/.../releases/latest")
  >>> extract(fields: [tag_name, body, assets])
in

let fetch_readme = \repo ->
  fetch(repo: repo)                      -- ref: Bash("gh api repos/.../contents/README.md")
  >>> extract(fields: [grammar, examples, usage])
in

let gather =
  (fetch_release("caasi/ocaml-compose-dsl")
    &&&
    fetch_readme("caasi/ocaml-compose-dsl")
    &&&
    fetch_prs(repo: "caasi/ocaml-compose-dsl")  -- ref: Bash("gh pr view N --json body")
    &&&
    read(source: "skills/compose/SKILL.md")
    &&&
    read(source: "skills/compose/references/dsl-grammar.md")
    &&&
    read(source: "skills/compose/README.md"))
in

let analyze =
  diff(upstream: release_info, local: skill_files)
  >>> plan(changes: required_updates)
in

let update_docs =
  update(target: "references/dsl-grammar.md", source: upstream_ebnf)
  *** update(target: "SKILL.md", sections: [version, combinators, abstraction, statements, unit, workflow, patterns])
  *** update(target: "README.md", sections: [features, combinators, examples])
  *** update(target: "CLAUDE.md", sections: [compose_description, version])
in

let update_examples =
  (update_examples(dir: "examples/", action: introduce_let_lambda)
    *** add_examples(dir: "examples/", for: [lambda, let_binding, unit_type, multi_statement]))
  >>> update(target: "SKILL.md", section: examples_list)
in

let validate =
  collect_arr_files(from: "skills/compose/examples/")
  >>> validate_all(checker: "ocaml-compose-dsl")
  >>> validate_literate(files: ["SKILL.md", "references/dsl-grammar.md", "README.md"])
in

let bump_version =
  update(target: ".claude-plugin/marketplace.json", fields: [version, description])
in

let verify =
  check_version(binary: "ocaml-compose-dsl", minimum: "0.10.0")
in

-- Main pipeline
gather >>> analyze >>> update_docs >>> update_examples >>> validate >>> bump_version >>> verify

-- Separate statement: signal completion with unit trigger
; () >>> notify(channel: "compose-updates", status: done)
