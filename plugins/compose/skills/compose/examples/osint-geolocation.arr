-- Workflow: geolocation from broadcast footage
-- Identify a facility's coordinates by cross-referencing video frames with satellite imagery
擷取影格(來源: "官媒報導.mp4", 間隔: 5s)        -- ref: Bash("ffmpeg")
  >>> 辨識地標(方法: [建築輪廓, 地形, 植被])     -- ref: Agent(vision)
  >>> (查詢衛星圖(提供者: google_earth, 解析度: 0.5m)
    &&& 查詢衛星圖(提供者: sentinel2, 日期: "2026-03"))  -- ref: WebFetch
  >>> 疊合比對(容許誤差: 50m)
  >>> 標註(輸出格式: geojson, 座標系: "WGS84")   -- ref: Write
