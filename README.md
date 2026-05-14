# Dragon Jump
以 Godot 4.6 開發的垂直卷軸跳躍遊戲，風格參考 Doodle Jump。

* 專案名稱：`dragon_test`
* 渲染器：GL Compatibility
* 設計解析度：360 x 640（9:16），stretch mode `canvas_items / expand`（手機優化）
* 物理引擎：Jolt Physics

## 如何執行
godot --path /Users/chlienoi-imac/Desktop/dragon_jump

按 F5 執行專案，或 F6 執行當前場景。

## 場景結構（main.tscn）

```
Main (Node2D + main.gd)
├── Camera2D
│   └── Background (Sprite2D)
├── Player        (player.tscn 實例)
├── BGM           (AudioStreamPlayer)
├── Platforms     (Node2D — 動態平台容器)
├── Enemies       (Node2D — 動態敵人容器)
└── UI            (CanvasLayer)
    ├── ScoreLabel
    ├── ComboLabel
    └── GameOverScreen
        ├── Overlay
        ├── GameOverTitle
        ├── FinalScoreLabel
        ├── HintLabel
        └── CooldownLabel
```

## 主要功能

* **角色操控** — 加速度計（手機傾斜）或鍵盤左右鍵控制，自動彈跳
* **分數系統**
  * 起始 0 分，每上升 100px +2 分
  * 踩到敵人 +10 分
  * 踩到棕雲 +1 分
* **Combo 系統**
  * 每次落地點比上次更高則累加 combo，否則重置
  * Combo ≥ 3 時右上角顯示炫彩「COMBO x3!」動畫
  * Combo 加成：每 100px 得 2+（combo-2）分
* **平台類型**
  * 普通（NORMAL）：白雲，可無限踩踏
  * 崩解（CRUMBLE）：棕雲，踩踏後延遲崩落，踩中 +1 分
  * 黑雲（DAMAGE）：下沉，觸碰即觸發死亡
  * 磚塊（BRICK）：磚塊雲，可頂頭碰觸，無法穿越
* **敵人系統**
  * 從正上方踩頭 → 彈跳消滅 +10 分
  * 側面／底部碰撞 → 扣命，combo 重置
* **背景切換** — 每 200 分漸變切換（BG_01 ～ BG_04），0.5 秒淡入淡出
* **音效系統** — 跳躍／踩踏／死亡／spin／崩裂音效，各自獨立 AudioStreamPlayer
* **生命值系統** — 5 顆愛心，歸零後 30 分鐘自動回復一顆
* **Firebase Firestore 全球排行榜**
  * 以 Godot HTTPRequest 直接呼叫 REST API（無 JavaScriptBridge 依賴）
  * 排行榜 autoload singleton（`Leaderboard`），於開始畫面和 Game Over 均可開啟
  * 僅在新高分時 PATCH 更新
* **玩家名稱設定** — 儲存於 `user://player.cfg`（ConfigFile），首次啟動自動彈出輸入視窗

## 資料夾結構

```
/
├── main.gd / main.tscn
├── player.gd / player.tscn
├── platform.gd / platform.tscn
├── enemy.gd / enemy.tscn
├── start_screen.gd / start_screen.tscn
├── leaderboard.gd              (autoload singleton)
├── FredokaOne-Regular.ttf
├── project.godot
└── assets/
    ├── characters/             (Idle.png, Jump.png, jump_up/down/land.png, …)
    ├── backgrounds/            (BG_01.png ～ BG_04.png, BG_start.png)
    ├── platforms/              (cloud_normal_idle.png, cloud_brown_idle.png,
    │                            cloud_brown_crumbling.png, cloud_brick_idle.png,
    │                            cloud_dark_idle.png, cloud_dark_hit.png)
    ├── enemies/                (enemy_hit.png, enemy_idle.png, game_over_spin.png)
    ├── ui/                     (life_01.png)
    └── audio/
        ├── music/              (bgm_01.mp3, start_music.mp3)
        └── sfx/                (jump.wav, crumble.wav, brick_hit.wav, death.wav,
                                 enemy_crush.wav, death_shout.mp3, spin.wav)
```

## 修改記錄

## 2026-05-15（feature/v1.1-score-combo-cloud-sprites）

- **分數機制重做**：起始分數改為 0，上升 100px = +2 分，踩到 enemy +10 分，踩到 brown cloud +1 分
- **Combo 系統**：每次落地點比上次更高累加 combo，落地點下降或被擊中重置為 0；combo ≥ 3 時右上角顯示炫彩「COMBO x3!」動畫；combo 加成公式：每 100px 得 2+（combo-2）分
- **Cloud 圖片更新**：所有平台雲改用 spritesheet（512×256 每幀），包含 cloud_normal_idle、cloud_brown_idle、cloud_brown_crumbling、cloud_brick_idle
- **Dark cloud 更新**：改用 cloud_dark_idle.png + cloud_dark_hit.png spritesheet，scale 0.125，檔名統一命名規則
- **檔案命名統一**：dark_cloud_* 重命名為 cloud_dark_*

## 2026-05-14（feature/v1.0-accelerometer-portrait-icon-darkcloud）

- **iOS 強制直向**：export_presets.cfg 加入 Portrait plist，project.godot 設定 window/handheld/orientation=1
- **App Icon**：iOS 所有 icon 欄位指向 assets/ios-appstore-1024.png
- **重力感應操控**：手機平台改用 Input.get_accelerometer()，修正方向與靈敏度（gravity.x / 4.0），編輯器/Web fallback 鍵盤
- **GitHub Actions**：加入 Godot headless export + iOS export template 下載，確保每次 build 使用最新 code
- **Safe Area 修正**：Score、Hearts、Welcome 使用 DisplayServer.get_display_safe_area() 動態避開 iPhone 動態島
- **Dark cloud 換新圖**：改用 spritesheet（dark_cloud_idle.png），scale 0.15，待修碰撞死亡觸發問題

### 2026-05-11 v0.9 更新內容
- iOS 強制直向（Portrait）顯示
- App Icon 套用（iOS: assets/ios-appstore-1024.png）
- 重力感應操控（手機傾斜控制角色，編輯器/Web 保持鍵盤）
- 修正重力感應方向與靈敏度（gravity.x / 4.0）
- GitHub Actions 加入 Godot headless export + iOS export template 下載

### 2026-05-11（feature/v0.8-share-githubpages-ios）

- **GitHub Pages 上線**：遊戲可直接於瀏覽器遊玩，網址由 GitHub Pages 自動部署，無需安裝
- **分享按鈕**：Game Over 畫面新增「分享成績」按鈕，支援 Web Share API，可分享至 LINE / IG 等平台
- **GitHub Actions iOS 自動 build**：`.github/workflows/ios-build.yml` 完整流程，push main 即觸發；使用 pre-exported Xcode 專案（`ios-build/`），xcodebuild automatic signing，development 方式打包 IPA
- **IPA 成功安裝至 iPhone**：CI 產出 `dragon-jump-ios-ipa`（32 MB），透過 Xcode Devices & Simulators 側載，成功在實體 iPhone 上執行

### 2026-05-10（feature/enemy-collision-item-visual）

- **敵人碰撞修復**：任何方向碰到敵人都扣命；只有從正上方踩頭（`n.y < -0.7`）才消滅敵人並讓玩家反彈，移除先前「從下方穿透忽略」的邏輯
- **無敵黑雲閃爍**：玩家處於無敵狀態碰到黑雲時，黑雲改為閃爍三下（alpha 0↔1，每次 0.2 秒）後消失，不扣命也不觸發 Game Over；非無敵狀態維持原本扣命邏輯
- **道具視覺更新**：type=0（星星）使用 `item_power_idle.png`，type=1（彈簧鞋）使用 `item_shoes_idle.png`，兩者都套用 `item_power.gdshader` 對角線鏡面掃光效果，移除原本 `_draw()` 程式繪製及 modulate 閃爍
- **標題字型修復**：`start_screen.gd` 改為以 `FontFile` 載入 `BubblegumSans-Regular.ttf` 並套用至每個字母 Label，載入失敗時 fallback 至系統字型
- **敵人站立位置修正**：`enemy.gd` 的 Y offset 根據平台類型調整（BRICK 平台 `cloud_half_h = 30.0`，其餘 `4.0`），修正敵人在磚塊平台上浮空的問題；移除 `[ENEMY Y]` debug print

### 2026-05-09（feature/title-animation-shader）

- **遊戲名稱重製**：Start Screen 標題改為 "Not-so-ugly\nDragon" 兩行，使用 `BubblegumSans-Regular.ttf` 字型
- **標題視覺樣式**：黃橘漸層填色（`LABEL_GRADIENT` shader）搭配深綠色外框 (`outline_size=8`)，提升辨識度
- **字母彈跳動畫**：Tween 逐字母垂直彈跳（正弦錯開），標題入場即自動播放，循環不中斷
- **敵人鏡面掃光 shader**：`enemy_sweep.gdshader` 對角線掃光（`diagonal = UV.x + UV.y`），以 `col.a` 為 mask 避免透明區域殘光，修復 GL Compatibility `return` 編譯錯誤
- **敵人踩踏動畫**：`enemy_hit.png` 3 幀 192×64（每幀 64×64），`die()` 播放 `hit` 動畫後 `queue_free`

### 2026-05-09（main）

- **敵人圖片修復**：重製 `enemy_01.png` 為正確尺寸 256×64 sprite sheet（4 幀 64×64），修正先前 hframes/vframes 設定錯誤導致的渲染破圖問題
- **敵人踩踏動畫**：`enemy_hit.png` 3 幀 192×64（每幀 64×64），`die()` 播放 `hit` 動畫後 `queue_free`，視覺反饋更清楚
- **敵人掃光 shader**：新增 `enemy_sweep.gdshader`，對角線掃光效果（`diagonal = UV.x + UV.y`），以 `col.a` 為 mask 避免透明區域殘光，修復 GL Compatibility 不支援 `return` 的編譯錯誤
- **道具系統穩定**：黃色星星（無敵）、橘色彈簧（跳高）穩定運作，黑雲免疫判斷正確
- **排行榜 UI 修復**：CanvasLayer layer=10 確保排行榜顯示在所有遊戲層之上
- **敵人懸空持續修復**：加入 `platform_type` 判斷，BRICK 平台（type=3）的 `cloud_half_h` 改為 50.0，修正敵人在磚塊平台上的 Y 軸定位

### 2026-05-08（main — 正式發布）

- **敵人踩踏動畫**：enemy.tscn SpriteFrames 加入 `hit` 動畫（`enemy_hit.png` 192×64，3 幀 64×64，FPS=12，loop=false）；`die()` 改為播放 hit 動畫取代旋轉縮小 tween，動畫結束後 `queue_free`，同時停止移動
- **移除所有 debug print**：main.gd / player.gd / item.gd 清除全部 `[ITEM_DEBUG]`、`[ENEMY_DEBUG]`、`[DAMAGE_DEBUG]`、`[ENEMY COLLISION]`、`[GHOST]`、`[TEST]` 等輸出
- **重置測試設定**：`MAX_ENEMIES` 恢復正常值 5；`DEV_ENEMY_TEST` 保持 `false`；`score` 初始值暫保留 100（測試用）
- **截圖排除**：`.gitignore` 加入 `截圖 *.png` / `截圖 *.png.import` 規則
- **feature/enemy-item-fix → main merge**：本版本為穩定可發布狀態

### 2026-05-07（feature/enemy-item-fix）

- **敵人渲染根本修復**：enemy.tscn 節點從 Sprite2D 完整改為 `AnimatedSprite2D + SpriteFrames`；sprite sheet 1536×1024（12×8 格，每格 128×128），idle 動畫取前 4 幀（AtlasTexture region 0/128/256/384）
- **道具系統**
  - 無敵（type=0）持續時間 2s → 5s
  - 黑雲碰撞加入無敵判斷（原本直接死亡，修復後無敵期間免疫）
  - 跳高殘影（type=1）修正 `global_position` 設定時機，改為 `add_child` 後再設以確保世界座標正確
  - UI 狀態列（左上角）即時顯示無敵/跳高剩餘秒數
- **分支管理**：建立 `feature/enemy-item-fix` 保存穩定成果

### 2026-05-06

- **排行榜修復**: 改用 Godot HTTPRequest + Firebase Firestore REST API，完全移除 JavaScriptBridge 依賴；leaderboard.gd 作為 autoload singleton 登錄於 project.godot
- **Restart 點擊修復**: GameOverScreen/Overlay 加入 `mouse_filter = 2 (MOUSE_FILTER_IGNORE)`，確保點擊事件穿透至 `_unhandled_input`
- **敵人圖片修復**: enemy.tscn 設定 hframes=12, vframes=8（對應 128×128 per frame）
- **敵人 y 定位修正**: 以碰撞框頂部 (4px) 為基準計算位移，修正敵人浮空問題
- **資料夾整理**: 全部素材移入 `assets/` 子目錄，並同步更新所有 .gd/.tscn/.import 的路徑參考
- **HTML 清理**: 移除 dragon_test.html 中的 Firebase JS SDK、CSS overlay 及 `window.DragonJumpFirebase` 物件
