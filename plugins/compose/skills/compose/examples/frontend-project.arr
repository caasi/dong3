-- Frontend project: client request to production delivery
-- 外包設計 + 內部開發的完整產品流程

-- Phase 1: Discovery
(
  Google_Meet(對象: 利害關係人, 目的: 需求訪談)
  >>> Google_Meet(對象: 使用者, 目的: 痛點訪談)
  >>> (
    Fireflies(輸出: 逐字稿) >>> Claude(任務: 會議重點摘要)
    &&&
    Claude(任務: 使用者痛點分析) >>> Notion(文件: 使用者旅程地圖)
  )
  >>> Notion(文件: 會議紀錄)
  &&&
  SimilarWeb(任務: 蒐集競品流量數據)
  >>> (
    Claude(任務: 競品功能矩陣整理) &&& Figma(任務: 競品截圖標註)
  )
  >>> Claude(任務: 競品優劣勢摘要)
  >>> Notion(文件: 市場定位報告)
)
>>> (
  Miro(任務: 資訊架構初稿)
  >>> Claude(任務: IA結構建議)
  >>> Miro(任務: 資訊架構修正)
  >>> Notion(文件: 內容盤點清單)
  &&&
  StackShare(任務: 技術選型調研)
  >>> Claude(任務: 框架比較分析)
  >>> (
    Notion(文件: 技術限制評估) &&& Notion(文件: 技術選型決策紀錄)
  )
  &&&
  (
    Google_Sheets(任務: 工時估算) &&& Google_Sheets(任務: 報價單)
  )
  >>> Notion(文件: 專案時程表)
)
>>> Claude(任務: 需求規格書草稿) >>> Notion(文件: 需求規格書定稿)
>>> loop(
  Google_Meet(目的: 內部審查會議) >>> 內部審查?
  >>> (通過 ||| Claude(任務: 修正需求規格書) >>> Notion(文件: 需求規格書更新))
)
>>> loop(
  DocuSign(對象: 客戶, 文件: 需求規格書)?
  >>> (通過 ||| Claude(任務: 依客戶意見修正) >>> Notion(文件: 需求規格書更新))
)

-- Phase 2: Design (outsourced)
>>> (
  Pinterest(任務: 視覺靈感蒐集) &&& Dribbble(任務: UI趨勢調研) &&& Mobbin(任務: 競品UX參考)
)
>>> (
  Figma(任務: 品牌風格探索, 面向: 色彩) &&& Figma(任務: 品牌風格探索, 面向: 字型)
)
>>> Miro(任務: Moodboard彙整)
>>> loop(
  Loom(任務: 風格方向提案) >>> 客戶風格確認?
  >>> (通過 ||| Figma(任務: 風格方向修正))
)
>>> (
  Figma(任務: Wireframe, 裝置: mobile) >>> Figma(任務: 互動流程, 裝置: mobile)
  &&&
  Figma(任務: Wireframe, 裝置: desktop) >>> Figma(任務: 互動流程, 裝置: desktop)
)
>>> Figma(任務: Wireframe標註資訊層級)
>>> loop(
  Loom(任務: 設計提案簡報) >>> 客戶設計審查?
  >>> (通過 ||| Figma(任務: Wireframe修正))
)
>>> (
  Figma(任務: Design_Token定義, 面向: 色彩)
  &&& Figma(任務: Design_Token定義, 面向: 字型)
  &&& Figma(任務: Design_Token定義, 面向: 間距)
)
>>> Figma(任務: Design_System建立)
>>> (
  Figma(元件: 按鈕, 含: 所有狀態)
  &&& Figma(元件: 輸入框, 含: 所有狀態)
  &&& Figma(元件: 表單, 含: 驗證回饋)
  &&& Figma(元件: 導覽列, 含: RWD)
  &&& Figma(元件: 卡片)
  &&& Figma(元件: Modal)
  &&& Figma(元件: Toast通知)
)
>>> (
  Figma(頁面: 首頁)
  &&& Figma(頁面: 產品列表頁)
  &&& Figma(頁面: 產品詳情頁)
  &&& Figma(頁面: 購物車)
  &&& Figma(頁面: 結帳流程)
  &&& Figma(頁面: 會員中心)
)
>>> (
  Figma(互動狀態: hover)
  &&& Figma(互動狀態: active)
  &&& Figma(互動狀態: disabled)
  &&& Figma(互動狀態: loading_skeleton)
  &&& Figma(互動狀態: error)
  &&& Figma(互動狀態: empty_state)
)
>>> (
  Figma(響應式: 375px) &&& Figma(響應式: 768px) &&& Figma(響應式: 1440px)
)
>>> (
  Figma(任務: Prototype串接, 範圍: 完整流程) &&& Figma(任務: Prototype串接, 範圍: 微互動動畫)
)
>>> Maze(任務: 易用性測試, 受測者: 5)
>>> (
  Claude(任務: 測試結果量化分析) &&& Claude(任務: 易用性改善建議)
)
>>> Figma(任務: 設計修正, 輪次: 1)
>>> Maze(任務: 修正後驗證測試)
>>> Figma(任務: 設計修正, 輪次: 2)
>>> loop(
  Loom(任務: 最終設計簡報) >>> 客戶最終簽核?
  >>> (通過 ||| Figma(任務: 設計修正_依客戶意見))
)

-- Phase 3: Handoff
>>> Figma(任務: Dev_Mode啟用)
>>> (
  Figma(任務: 元件文件撰寫, 含: Props與Variants) &&& Figma(任務: Design_Token匯出, 格式: JSON)
)
>>> (
  Figma_MCP(任務: 讀取元件規格)
    >>> (
      Cursor(任務: 生成元件程式碼) &&& Claude(任務: 程式碼品質檢查)
    )
    >>> Cursor(任務: 修正生成結果)? -- known false positive: ? matches ||| below
  |||
  (
    Zeplin(任務: 標註匯出)
    >>> (
      Notion(文件: 元件規格)
      &&& Notion(文件: 互動行為描述)
      &&& Notion(文件: 邊界情況清單)
    )
  )
)
>>> (
  Style_Dictionary(任務: Design_Token轉CSS變數) >>> Style_Dictionary(任務: 生成Tailwind設定)
  &&&
  Figma(匯出: SVG圖示) &&& Figma(匯出: 圖片資源) >>> ImageOptim(任務: 資源壓縮)
  &&&
  Notion(文件: 互動規格)
  &&& Notion(文件: 動畫規格, 含: easing與duration)
  &&& Notion(文件: 無障礙規格, 含: ARIA標註)
)
>>> Google_Meet(目的: 開發團隊Handoff會議) >>> Notion(文件: Handoff會議QA紀錄)

-- Phase 4: Implementation
>>> Next(任務: create_next_app) >>> pnpm(任務: 安裝依賴)
>>> (
  ESLint(任務: 設定lint規則)
  &&& Prettier(任務: 設定格式化)
  &&& Husky(任務: 設定git_hooks)
  &&& Tailwind(任務: 設定Design_Token對應)
  &&& next_config(任務: 設定圖片與i18n)
  &&& TypeScript(任務: 設定path_alias)
  &&& Storybook(任務: 設定元件文件環境)
  &&& GitHub_Actions(任務: CI_pipeline建立)
)
>>> GitHub(任務: 建立feature_branches)
>>> Cursor(元件: 共用Layout)
>>> (
  Cursor(元件: Header) &&& Cursor(元件: Footer)
)
>>> (
  Cursor(頁面: 首頁)
  &&& Cursor(頁面: 產品列表頁)
  &&& Cursor(頁面: 產品詳情頁)
  &&& Cursor(頁面: 購物車)
  &&& Cursor(頁面: 結帳流程)
  &&& Cursor(頁面: 會員中心)
)
>>> (
  Storybook(任務: 元件文件撰寫)
  &&& Playwright(測試: E2E核心流程)
  &&& Chromatic(測試: 視覺回歸, 範圍: 所有頁面)
  &&& axe(測試: 無障礙檢測, 標準: WCAG2AA)
)
>>> loop(
  Claude(任務: Code_Review) >>> GitHub(任務: PR審查)
  >>> "approved"?
  >>> (GitHub(任務: merge) ||| Cursor(任務: 修正後重新提交))
)
>>> Vercel(任務: 部署, 環境: staging)
>>> (
  Lighthouse(測試: Core_Web_Vitals)
  &&& BugHerd(任務: QA回報bug)
  &&& Claude(任務: staging頁面逐頁檢查)
)
>>> loop(
  Cursor(任務: 撰寫修正) >>> Playwright(測試: 回歸測試)
  >>> Vercel(任務: 重新部署, 環境: staging)
  >>> QA驗證?
  >>> (通過 ||| 繼續修正)
)

-- Phase 5: Delivery
>>> (
  Notion(文件: 上線checklist)
  &&& Vercel(任務: 環境變數設定, 環境: production)
)
>>> (
  Vercel(任務: DNS設定) &&& Cloudflare(任務: CDN設定) &&& Cloudflare(任務: SSL憑證驗證) &&& Sentry(任務: 錯誤監控設定)
)
>>> Vercel(任務: 部署, 環境: production)
>>> (
  Lighthouse(測試: production效能驗證, 目標: 90)
  &&& Checkly(任務: uptime監控啟用)
  &&& Google_Analytics(測試: GA4埋點驗證)
  &&& Sentry(測試: 錯誤監控驗證)
)
>>> (
  Loom(任務: 客戶操作教學錄製)
  &&& Notion(文件: 維運文件_部署流程)
  &&& Notion(文件: 維運文件_常見問題)
)
>>> loop(
  Google_Meet(目的: 客戶驗收會議) >>> 客戶驗收?
  >>> (通過 ||| Cursor(任務: 驗收意見修正) >>> Vercel(任務: 重新部署, 環境: production))
)
>>> (
  Notion(文件: 專案結案報告)
  &&& Google_Drive(任務: 設計原始檔移交)
  &&& GitHub(任務: 程式碼Repository移交)
  &&& Notion(文件: 帳號權限移交清單)
)
