-- Workflow: cross-platform account correlation (defensive)
-- Illustrative only — use in lawful, ToS-compliant, privacy-respecting contexts
-- Trace the source of a dox attack by correlating the attacker's public breadcrumbs
(搜尋(平台: threads, 關鍵字: handle)
  &&& 搜尋(平台: facebook, 關鍵字: handle)
  &&& 搜尋(平台: line, 關鍵字: handle))         -- ref: WebFetch
  >>> 交叉比對(欄位: [顯示名稱, 大頭貼, 簡介連結])
  >>> 反查公司登記(來源: "經濟部商工登記")?  -- ref: WebFetch
  >>> (繼續 ||| 反查網域(方法: whois))  -- ref: Bash("whois")
  >>> ((去識別化(保留: 流程與方法, 移除: 個人身份資訊) >>> 公開流程(平台: blog, 內容: 方法與步驟))
    &&& 報案(提交: 完整調查資料))               -- ref: Write
