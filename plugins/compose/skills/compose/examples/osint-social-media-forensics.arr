-- Workflow: social media timeline forensics
-- Crawl a target's post history to extract identifying artifacts
收集(平台: social_media, 範圍: "全部貼文")   -- ref: Bash("gallery-dl"), WebFetch
  >>> 篩選(類型: [圖片, 個資線索])
  >>> (擷取文字(方法: ocr) *** 提取metadata(欄位: [時間, 地點, 裝置]))
  >>> 比對(資料庫: known_identities)           -- ref: Grep, Bash("fzf")
  >>> 彙整(格式: 證據資料夾)
