-- Workflow: cross-platform account correlation
-- Link an online handle to real-world identity via public breadcrumbs
(搜尋(平台: threads, 關鍵字: handle)
  &&& 搜尋(平台: facebook, 關鍵字: handle)
  &&& 搜尋(平台: line, 關鍵字: handle))         -- ref: WebFetch
  >>> 交叉比對(欄位: [顯示名稱, 大頭貼, 簡介連結])
  >>> (反查公司登記(來源: "經濟部商工登記") ||| 反查網域(方法: whois))  -- ref: Bash("whois"), WebFetch
  >>> 建檔(輸出: "身份關聯報告.md")              -- ref: Write
