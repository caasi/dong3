-- Workflow: open-source military media monitoring
-- Monitor state media broadcasts, extract unit designations, and map to known bases
監控(頻道: [cctv7, 央視軍事], 關鍵字: [新兵入營, 訓練])  -- ref: WebFetch, Bash("yt-dlp")
  >>> 擷取資訊(欄位: [部隊番號, 人名, 地名])
  >>> (查詢已知部隊(資料庫: order_of_battle)
    *** 地理定位(線索: [受訪者發言, 背景地貌]))
  >>> 驗證(方法: 比對聲稱地點與定位結果)          -- 新兵未必知道營區真實位置
  >>> 更新(目標: unit_database, 欄位: [座標, 最後活動日期])
