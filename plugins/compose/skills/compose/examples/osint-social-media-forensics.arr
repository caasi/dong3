-- Workflow: social media timeline forensics (defensive)
-- Illustrative only — use in lawful, ToS-compliant, privacy-respecting contexts
-- Trace who spread a victim's personal data by analyzing the spreader's timeline
收集(平台: social_media, 範圍: "全部貼文")   -- ref: Bash("gallery-dl"), WebFetch
  >>> 篩選(類型: [圖片, 個資線索])
  >>> (擷取文字(方法: ocr) *** 提取metadata(欄位: [時間, 地點, 裝置]))
  >>> 比對(資料庫: known_identities)           -- ref: Grep, Bash("fzf")
  >>> 去識別化(保留: 調查方法與時序, 移除: 涉及人員身份)
  >>> (公開流程(平台: blog, 內容: 調查方法紀錄) *** 彙整(格式: 證據資料夾, 用途: 報案))  -- ref: Write
