-- Workflow: data processing with unicode node names and argument keys
-- Demonstrates CJK identifiers in a coherent Japanese data pipeline
読み込み(ソース: "データ.csv")       -- ref: Read
  >>> フィルタ(条件: "年齢 > 18")   -- ref: Bash("jq")
  >>> (集計 *** 抽出(項目: [名前, メール]))
  >>> 出力(形式: レポート)
