-- Workflow: data processing with unicode node names, keys, and unit suffixes
-- Demonstrates CJK identifiers and unicode unit suffixes
読み込み(ソース: "データ.csv")       -- ref: Read
  >>> フィルタ(条件: "年齢 > 18")   -- ref: Bash("jq")
  >>> (集計 *** 抽出(項目: [名前, メール]))
  >>> 加熱(溫度: 72.5℃, 時間: 30分鐘)
  >>> 出力(形式: レポート)
