-- Workflow: military infrastructure change detection
-- Compare temporal satellite imagery to identify new construction at known facilities
取得座標(來源: facility_database, 篩選: "近期活動")  -- ref: Read
  >>> (下載衛星圖(日期: "2024-01") *** 下載衛星圖(日期: "2026-03"))  -- ref: WebFetch
  >>> 差異分析(方法: pixel_diff, 閾值: 0.15)
  >>> 標記變化(類型: [新建跑道, 機堡, 雷達陣地, 營舍])
  >>> 產出報告(格式: markdown, 含圖: true)        -- ref: Write
