-- Workflow: iteratively fix code until tests pass
-- Parameterized with lambda so the loop can be reused for different targets/suites

let test_fix = \target, suite ->
  loop(
    edit(target: target, change: fix)     -- ref: Edit
      >>> test(suite: suite)              -- ref: Bash("npm test")
      >>> "all tests pass"?
      >>> (done ||| retry)               -- exit loop on pass, retry on fail
  )
in
test_fix(code, relevant)
