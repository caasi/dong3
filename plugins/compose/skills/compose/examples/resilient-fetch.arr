-- Workflow: fetch from primary source, fall back to mirror on failure
-- Uses ? upstream to produce Either, then ||| branches on success/failure.
-- Avoids placing ? as operand of ||| (which triggers a checker warning).
-- Note: ||| (prec 2) binds tighter than >>> (prec 1), so group fallback chains.
fetch(url: primary)?                              -- ref: WebFetch
  >>> (transform(mapping: schema_v2)
         >>> write(dest: "output.json")           -- ref: Write
       ||| (fetch(url: mirror)                    -- ref: WebFetch
             >>> transform(mapping: schema_v2)
             >>> write(dest: "output.json")))      -- ref: Write
