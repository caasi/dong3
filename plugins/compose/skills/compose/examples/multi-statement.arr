-- Semicolon statement separator: independent pipelines in one file

-- Planning and implementation as separate concerns
planning :: Doc -> Commit
  >>> commit(branch: main);

implementation :: Code -> Commit
  >>> git_branch(pattern: "feature/*") :: Code -> Branch
  >>> commit :: Branch -> Commit;

-- Trailing semicolon is optional on the last statement
deploy(env: staging) >>> verify >>> promote(env: production)
