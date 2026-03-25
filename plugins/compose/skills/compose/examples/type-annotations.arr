-- Type annotations: optional :: Ident -> Ident on any term
-- Annotations document data flow; the checker does not validate types

-- Sequential with annotations
-- fetch(url: "https://example.com") :: URL -> HTML
--   >>> parse :: HTML -> Data
--   >>> filter(condition: "age > 18") :: Data -> Data
--   >>> format(as: report) :: Data -> Report

-- Parallel with annotations
-- (resize(width: 1920) :: Image -> Image *** compress(quality: 85) :: Audio -> Audio)
--   >>> package :: Assets -> Bundle

-- Fanout with annotations
-- (lint :: Code -> Result &&& test(suite: unit) :: Code -> Result)
--   >>> gate(require: [pass, pass]) :: Results -> Verdict

-- Loop with annotation
-- loop(
--   generate(from: spec) :: Spec -> Code
--     >>> verify(method: tests) :: Code -> Result
--     >>> "all tests pass"?
--     >>> (done :: Result -> Output ||| fix :: Result -> Spec)
-- )

-- Question with annotation
-- fetch(url: primary)? :: URL -> Either
--   >>> (process :: Either -> Response ||| (fetch(url: mirror) :: URL -> Response >>> process :: Response -> Response))

-- Grouped expression with annotation
-- (read(source: "data.csv") >>> parse(format: csv)) :: File -> Data
--   >>> (count :: Data -> Stats &&& collect(fields: [email]) :: Data -> List)
--   >>> format(as: report) :: Pair -> Report

-- Annotations with comments
-- fetch(url: endpoint) :: URL -> JSON  -- ref: WebFetch
--   >>> validate(schema: v2) :: JSON -> ValidJSON  -- ref: Bash("ajv")
--   >>> store(dest: db) :: ValidJSON -> Ack  -- ref: Bash("psql")

-- Unicode nodes with annotations
-- 読み込み(ソース: "データ.csv") :: ファイル -> 生データ
--   >>> フィルタ(条件: "年齢 > 18") :: 生データ -> フィルタ済み
--   >>> 出力 :: フィルタ済み -> レポート

-- Active example: combined pipeline demonstrating all annotation forms
fetch(url: "https://example.com") :: URL -> HTML
  >>> parse :: HTML -> Data
  >>> (count :: Data -> Stats &&& collect(fields: [email]) :: Data -> List)
  >>> format(as: report) :: Pair -> Report
  >>> (resize(width: 1920) :: Image -> Image *** compress(quality: 85) :: Audio -> Audio)
  >>> package :: Assets -> Bundle
  >>> validate(schema: v2)? :: Bundle -> Either
  >>> (
    store(dest: db) :: Bundle -> Ack
    ||| loop(
      fix(issue: validation) :: Error -> Bundle
        >>> revalidate :: Bundle -> Result
        >>> "validation passes"?
        >>> (done :: Result -> Ack ||| retry :: Result -> Error)
    )
  )
  >>> 出力 :: Ack -> レポート
