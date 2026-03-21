-- Workflow: systematic evidence compilation for legal proceedings (defensive)
-- Illustrative only — use in lawful, ToS-compliant, privacy-respecting contexts
-- Organize scattered online evidence of a dox attack into court-ready folders
loop(
  掃描(來源: 轉發清單, 批次: 50)                 -- ref: WebFetch, Bash("curl")
    >>> (截圖(含時間戳: true) *** 保存原始頁面(格式: mhtml))  -- ref: Playwright
    >>> 分類(依據: [發文者, 日期, 侵權類型])
    >>> evaluate(條件: 清單已處理完畢)
)
  >>> 去識別化(保留: 侵權行為模式, 移除: 受害者個資)
  >>> 產出(格式: pdf, 結構: 每人一資料夾)         -- ref: Bash("wkhtmltopdf")
  >>> (公開流程(平台: blog, 內容: 蒐證方法與統計摘要)
    *** 匯出(目的: "提告資料", 內容: 完整證據))   -- ref: Write
