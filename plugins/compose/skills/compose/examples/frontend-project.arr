-- Frontend project: client request to production delivery
-- 外包設計 + 內部開發的完整產品流程

-- Phase 1: Discovery
(
  Google_Meet(對象: 利害關係人, 目的: 需求訪談) :: 專案 -> 訪談紀錄
  >>> Google_Meet(對象: 使用者, 目的: 痛點訪談) :: 訪談紀錄 -> 使用者回饋
  >>> (
    Fireflies(輸出: 逐字稿) :: 錄影 -> 逐字稿 >>> Claude(任務: 會議重點摘要) :: 逐字稿 -> 摘要
    &&&
    Claude(任務: 使用者痛點分析) :: 使用者回饋 -> 痛點報告 >>> Notion(文件: 使用者旅程地圖) :: 痛點報告 -> 文件
  )
  >>> Notion(文件: 會議紀錄) :: 摘要 -> 文件
  &&&
  SimilarWeb(任務: 蒐集競品流量數據) :: 專案 -> 流量數據
  >>> (
    Claude(任務: 競品功能矩陣整理) :: 流量數據 -> 功能矩陣 &&& Figma(任務: 競品截圖標註) :: 流量數據 -> 標註圖
  )
  >>> Claude(任務: 競品優劣勢摘要) :: 分析結果 -> 競品摘要
  >>> Notion(文件: 市場定位報告) :: 競品摘要 -> 文件
)
>>> (
  Miro(任務: 資訊架構初稿) :: 需求 -> IA草稿
  >>> Claude(任務: IA結構建議) :: IA草稿 -> IA建議
  >>> Miro(任務: 資訊架構修正) :: IA建議 -> IA定稿
  >>> Notion(文件: 內容盤點清單) :: IA定稿 -> 文件
  &&&
  StackShare(任務: 技術選型調研) :: 需求 -> 技術選項
  >>> Claude(任務: 框架比較分析) :: 技術選項 -> 比較報告
  >>> (
    Notion(文件: 技術限制評估) :: 比較報告 -> 文件 &&& Notion(文件: 技術選型決策紀錄) :: 比較報告 -> 文件
  )
  &&&
  (
    Google_Sheets(任務: 工時估算) :: 需求 -> 工時表 &&& Google_Sheets(任務: 報價單) :: 需求 -> 報價
  )
  >>> Notion(文件: 專案時程表) :: 估算 -> 文件
)
>>> Claude(任務: 需求規格書草稿) :: Discovery產出 -> 規格草稿
>>> Notion(文件: 需求規格書定稿) :: 規格草稿 -> 規格書
>>> loop(
  Google_Meet(目的: 內部審查會議) :: 規格書 -> 審查紀錄
  >>> 內部審查? :: 審查紀錄 -> Either
  >>> (通過 :: Either -> 規格書 ||| (Claude(任務: 修正需求規格書) :: Either -> 修正稿 >>> Notion(文件: 需求規格書更新) :: 修正稿 -> 規格書))
)
>>> loop(
  DocuSign(對象: 客戶, 文件: 需求規格書)? :: 規格書 -> Either
  >>> (通過 :: Either -> 規格書 ||| (Claude(任務: 依客戶意見修正) :: Either -> 修正稿 >>> Notion(文件: 需求規格書更新) :: 修正稿 -> 規格書))
)

-- Phase 2: Design (outsourced)
>>> (
  Pinterest(任務: 視覺靈感蒐集) :: 需求 -> 靈感圖集 &&& Dribbble(任務: UI趨勢調研) :: 需求 -> 趨勢參考 &&& Mobbin(任務: 競品UX參考) :: 需求 -> UX參考
)
>>> (
  Figma(任務: 品牌風格探索, 面向: 色彩) :: 靈感素材 -> 色彩方案 &&& Figma(任務: 品牌風格探索, 面向: 字型) :: 靈感素材 -> 字型方案
)
>>> Miro(任務: Moodboard彙整) :: 風格素材 -> Moodboard
>>> loop(
  Loom(任務: 風格方向提案) :: Moodboard -> 提案影片
  >>> 客戶風格確認? :: 提案影片 -> Either
  >>> (通過 :: Either -> 風格定稿 ||| Figma(任務: 風格方向修正) :: Either -> Moodboard)
)
>>> (
  Figma(任務: Wireframe, 裝置: mobile) :: 風格定稿 -> 線框稿 >>> Figma(任務: 互動流程, 裝置: mobile) :: 線框稿 -> 互動稿
  &&&
  Figma(任務: Wireframe, 裝置: desktop) :: 風格定稿 -> 線框稿 >>> Figma(任務: 互動流程, 裝置: desktop) :: 線框稿 -> 互動稿
)
>>> Figma(任務: Wireframe標註資訊層級) :: 互動稿 -> 標註稿
>>> loop(
  Loom(任務: 設計提案簡報) :: 標註稿 -> 簡報影片
  >>> 客戶設計審查? :: 簡報影片 -> Either
  >>> (通過 :: Either -> 設計定稿 ||| Figma(任務: Wireframe修正) :: Either -> 標註稿)
)
>>> (
  Figma(任務: Design_Token定義, 面向: 色彩) :: 設計定稿 -> Token
  &&& Figma(任務: Design_Token定義, 面向: 字型) :: 設計定稿 -> Token
  &&& Figma(任務: Design_Token定義, 面向: 間距) :: 設計定稿 -> Token
)
>>> Figma(任務: Design_System建立) :: Token -> DesignSystem
>>> (
  Figma(元件: 按鈕, 含: 所有狀態) :: DesignSystem -> 元件
  &&& Figma(元件: 輸入框, 含: 所有狀態) :: DesignSystem -> 元件
  &&& Figma(元件: 表單, 含: 驗證回饋) :: DesignSystem -> 元件
  &&& Figma(元件: 導覽列, 含: RWD) :: DesignSystem -> 元件
  &&& Figma(元件: 卡片) :: DesignSystem -> 元件
  &&& Figma(元件: Modal) :: DesignSystem -> 元件
  &&& Figma(元件: Toast通知) :: DesignSystem -> 元件
)
>>> (
  Figma(頁面: 首頁) :: 元件庫 -> 頁面稿
  &&& Figma(頁面: 產品列表頁) :: 元件庫 -> 頁面稿
  &&& Figma(頁面: 產品詳情頁) :: 元件庫 -> 頁面稿
  &&& Figma(頁面: 購物車) :: 元件庫 -> 頁面稿
  &&& Figma(頁面: 結帳流程) :: 元件庫 -> 頁面稿
  &&& Figma(頁面: 會員中心) :: 元件庫 -> 頁面稿
)
>>> (
  Figma(互動狀態: hover) :: 頁面稿 -> 狀態稿
  &&& Figma(互動狀態: active) :: 頁面稿 -> 狀態稿
  &&& Figma(互動狀態: disabled) :: 頁面稿 -> 狀態稿
  &&& Figma(互動狀態: loading_skeleton) :: 頁面稿 -> 狀態稿
  &&& Figma(互動狀態: error) :: 頁面稿 -> 狀態稿
  &&& Figma(互動狀態: empty_state) :: 頁面稿 -> 狀態稿
)
>>> (
  Figma(響應式: 375px) :: 狀態稿 -> RWD稿 &&& Figma(響應式: 768px) :: 狀態稿 -> RWD稿 &&& Figma(響應式: 1440px) :: 狀態稿 -> RWD稿
)
>>> (
  Figma(任務: Prototype串接, 範圍: 完整流程) :: RWD稿 -> Prototype &&& Figma(任務: Prototype串接, 範圍: 微互動動畫) :: RWD稿 -> Prototype
)
>>> Maze(任務: 易用性測試, 受測者: 5) :: Prototype -> 測試結果
>>> (
  Claude(任務: 測試結果量化分析) :: 測試結果 -> 量化報告 &&& Claude(任務: 易用性改善建議) :: 測試結果 -> 改善建議
)
>>> Figma(任務: 設計修正, 輪次: 1) :: 改善建議 -> 修正稿
>>> Maze(任務: 修正後驗證測試) :: 修正稿 -> 驗證結果
>>> Figma(任務: 設計修正, 輪次: 2) :: 驗證結果 -> 設計完稿
>>> loop(
  Loom(任務: 最終設計簡報) :: 設計完稿 -> 簡報影片
  >>> 客戶最終簽核? :: 簡報影片 -> Either
  >>> (通過 :: Either -> 設計定版 ||| Figma(任務: 設計修正_依客戶意見) :: Either -> 設計完稿)
)

-- Phase 3: Handoff
>>> Figma(任務: Dev_Mode啟用) :: 設計定版 -> DevMode稿
>>> (
  Figma(任務: 元件文件撰寫, 含: Props與Variants) :: DevMode稿 -> 元件文件 &&& Figma(任務: Design_Token匯出, 格式: JSON) :: DevMode稿 -> TokenJSON
)
>>> Figma_MCP(任務: 讀取元件規格) :: 元件文件 -> 元件規格
>>> AI生成品質評估? :: 元件規格 -> Either
>>> (
  ((Cursor(任務: 生成元件程式碼) :: Either -> 程式碼 &&& Claude(任務: 程式碼品質檢查) :: Either -> 檢查報告)
    >>> Cursor(任務: 修正生成結果) :: 檢查結果 -> 元件程式碼)
  |||
  (Zeplin(任務: 標註匯出) :: Either -> 標註
    >>> (Notion(文件: 元件規格) :: 標註 -> 文件 &&& Notion(文件: 互動行為描述) :: 標註 -> 文件 &&& Notion(文件: 邊界情況清單) :: 標註 -> 文件))
)
>>> (
  Style_Dictionary(任務: Design_Token轉CSS變數) :: TokenJSON -> CSS變數 >>> Style_Dictionary(任務: 生成Tailwind設定) :: CSS變數 -> TailwindConfig
  &&&
  (Figma(匯出: SVG圖示) :: DevMode稿 -> SVG &&& Figma(匯出: 圖片資源) :: DevMode稿 -> 圖片) >>> ImageOptim(任務: 資源壓縮) :: 資源 -> 壓縮資源
  &&&
  Notion(文件: 互動規格) :: Handoff產出 -> 文件
  &&& Notion(文件: 動畫規格, 含: easing與duration) :: Handoff產出 -> 文件
  &&& Notion(文件: 無障礙規格, 含: ARIA標註) :: Handoff產出 -> 文件
)
>>> Google_Meet(目的: 開發團隊Handoff會議) :: Handoff資料 -> 會議紀錄
>>> Notion(文件: Handoff會議QA紀錄) :: 會議紀錄 -> 文件

-- Phase 4: Implementation
>>> Next(任務: create_next_app) :: 專案規格 -> 專案骨架
>>> pnpm(任務: 安裝依賴) :: 專案骨架 -> 專案環境
>>> (
  ESLint(任務: 設定lint規則) :: 專案環境 -> Config
  &&& Prettier(任務: 設定格式化) :: 專案環境 -> Config
  &&& Husky(任務: 設定git_hooks) :: 專案環境 -> Config
  &&& Tailwind(任務: 設定Design_Token對應) :: 專案環境 -> Config
  &&& next_config(任務: 設定圖片與i18n) :: 專案環境 -> Config
  &&& TypeScript(任務: 設定path_alias) :: 專案環境 -> Config
  &&& Storybook(任務: 設定元件文件環境) :: 專案環境 -> Config
  &&& GitHub_Actions(任務: CI_pipeline建立) :: 專案環境 -> Config
)
>>> GitHub(任務: 建立feature_branches) :: Config -> Repo
>>> Cursor(元件: 共用Layout) :: Repo -> Layout元件
>>> (
  Cursor(元件: Header) :: Layout元件 -> 元件 &&& Cursor(元件: Footer) :: Layout元件 -> 元件
)
>>> (
  Cursor(頁面: 首頁) :: 元件 -> 頁面
  &&& Cursor(頁面: 產品列表頁) :: 元件 -> 頁面
  &&& Cursor(頁面: 產品詳情頁) :: 元件 -> 頁面
  &&& Cursor(頁面: 購物車) :: 元件 -> 頁面
  &&& Cursor(頁面: 結帳流程) :: 元件 -> 頁面
  &&& Cursor(頁面: 會員中心) :: 元件 -> 頁面
)
>>> (
  Storybook(任務: 元件文件撰寫) :: 頁面 -> 文件
  &&& Playwright(測試: E2E核心流程) :: 頁面 -> 測試結果
  &&& Chromatic(測試: 視覺回歸, 範圍: 所有頁面) :: 頁面 -> 測試結果
  &&& axe(測試: 無障礙檢測, 標準: WCAG2AA) :: 頁面 -> 測試結果
)
>>> loop(
  Claude(任務: Code_Review) :: PR -> 審查意見
  >>> GitHub(任務: PR審查) :: 審查意見 -> 審查結果
  >>> "approved"? :: 審查結果 -> Either
  >>> (GitHub(任務: merge) :: Either -> 合併結果 ||| Cursor(任務: 修正後重新提交) :: Either -> PR)
)
>>> Vercel(任務: 部署, 環境: staging) :: 合併結果 -> Staging環境
>>> (
  Lighthouse(測試: Core_Web_Vitals) :: Staging環境 -> 效能報告
  &&& BugHerd(任務: QA回報bug) :: Staging環境 -> Bug清單
  &&& Claude(任務: staging頁面逐頁檢查) :: Staging環境 -> 檢查報告
)
>>> loop(
  Cursor(任務: 撰寫修正) :: Bug清單 -> 修正碼
  >>> Playwright(測試: 回歸測試) :: 修正碼 -> 測試結果
  >>> Vercel(任務: 重新部署, 環境: staging) :: 測試結果 -> Staging環境
  >>> QA驗證? :: Staging環境 -> Either
  >>> (通過 :: Either -> 穩定版 ||| 繼續修正 :: Either -> Bug清單)
)

-- Phase 5: Delivery
>>> (
  Notion(文件: 上線checklist) :: 穩定版 -> 文件
  &&& Vercel(任務: 環境變數設定, 環境: production) :: 穩定版 -> 環境設定
)
>>> (
  Vercel(任務: DNS設定) :: 環境設定 -> DNS
  &&& Cloudflare(任務: CDN設定) :: 環境設定 -> CDN
  &&& Cloudflare(任務: SSL憑證驗證) :: 環境設定 -> SSL
  &&& Sentry(任務: 錯誤監控設定) :: 環境設定 -> 監控
)
>>> Vercel(任務: 部署, 環境: production) :: 基礎設施 -> Production環境
>>> (
  Lighthouse(測試: production效能驗證, 目標: 90) :: Production環境 -> 效能報告
  &&& Checkly(任務: uptime監控啟用) :: Production環境 -> 監控狀態
  &&& Google_Analytics(測試: GA4埋點驗證) :: Production環境 -> 追蹤報告
  &&& Sentry(測試: 錯誤監控驗證) :: Production環境 -> 監控報告
)
>>> (
  Loom(任務: 客戶操作教學錄製) :: Production環境 -> 教學影片
  &&& Notion(文件: 維運文件_部署流程) :: Production環境 -> 文件
  &&& Notion(文件: 維運文件_常見問題) :: Production環境 -> 文件
)
>>> loop(
  Google_Meet(目的: 客戶驗收會議) :: Production環境 -> 驗收紀錄
  >>> 客戶驗收? :: 驗收紀錄 -> Either
  >>> (通過 :: Either -> 結案 ||| (Cursor(任務: 驗收意見修正) :: Either -> 修正碼 >>> Vercel(任務: 重新部署, 環境: production) :: 修正碼 -> Production環境))
)
>>> (
  Notion(文件: 專案結案報告) :: 結案 -> 文件
  &&& Google_Drive(任務: 設計原始檔移交) :: 結案 -> 移交紀錄
  &&& GitHub(任務: 程式碼Repository移交) :: 結案 -> 移交紀錄
  &&& Notion(文件: 帳號權限移交清單) :: 結案 -> 文件
)
