-- The ? operator marks a step as producing Either for ||| branching.
-- Only the "try" side gets ?. The fallback side does not.
-- Do NOT place ? as a direct operand of ||| — that triggers a checker warning.
-- Note: ||| (prec 2) binds tighter than >>> (prec 1), so group fallback chains.

-- Basic: node? feeding into ||| via >>>
-- fetch(url: primary)?
--   >>> (process ||| (fetch(url: mirror) >>> process))

-- String? in a loop with ||| exit condition
-- loop(
--   generate >>> verify >>> "all tests pass"?
--   >>> (done ||| fix_and_retry)
-- )

-- Upstream in a >>> chain feeding |||
validate(schema: config)?
  >>> (apply(target: production) ||| rollback(to: previous))
