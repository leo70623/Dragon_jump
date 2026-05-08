# Dragon Jump

A Doodle Jump-style vertical scroller built with **Godot 4.6**.

- Project name: `dragon_test`
- Renderer: GL Compatibility
- Design resolution: 360 x 640 (9:16), stretch mode `canvas_items / expand` (mobile)
- Physics: Jolt Physics

## How to run

```
godot --path /Users/chlienoi-imac/Desktop/dragon_jump
```

Then press **F5** to run the project or **F6** to run the current scene.

## Scene tree (main.tscn)

```
Main (Node2D + main.gd)
├── Camera2D
│   └── Background (Sprite2D)
├── Player        (instance of player.tscn)
├── BGM           (AudioStreamPlayer)
├── Platforms     (Node2D — dynamic platform container)
├── Enemies       (Node2D — dynamic enemy container)
└── UI            (CanvasLayer)
    ├── ScoreLabel
    └── GameOverScreen
        ├── Overlay
        ├── GameOverTitle
        ├── FinalScoreLabel
        ├── HintLabel
        └── CooldownLabel
```

## Key features

- **龍角色跳躍** — 加速度計 (mobile) 或鍵盤左右鍵控制，自動彈跳
- **平台類型**
  - 普通 (NORMAL): 白雲，可無限踩踏
  - 崩解 (CRUMBLE): 棕雲，踩踏後延遲崩落
  - 黑雲 (DAMAGE): 下沉，觸碰即觸發死亡
  - 磚塊 (BRICK): 金屬平台，可頂頭碰觸
- **敵人系統**
  - 踩踏敵人頭頂 → 彈跳消滅（骨牌連跳）
  - 側面/底部碰撞 → 扣命死亡
- **背景圖四張輪換** — 每 200 分漸變切換 (BG_01 ~ BG_04)，0.5 秒淡入淡出
- **音效系統** — 起跳 / 踩踏 / 死亡 / spin / 崩裂音效，各自獨立 AudioStreamPlayer
- **生命值系統** — 5 顆愛心，歸零後 30 分鐘自動回復一顆
- **Firebase Firestore 全球排行榜**
  - Godot HTTPRequest 直接呼叫 REST API（無 JavaScriptBridge 依賴）
  - 排行榜 autoload singleton (`Leaderboard`)，於 start_screen 和 game over 均可開啟
  - 僅在新高分時 PATCH 更新
- **玩家名稱設定** — 儲存於 `user://player.cfg` (ConfigFile)，首次啟動自動彈出輸入視窗

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
    ├── backgrounds/            (BG_01.png ~ BG_04.png, BG_start.png)
    ├── platforms/              (cloud_01~03, brown_cloud_01~03, dark_cloud_01~02, …)
    ├── enemies/                (enemy_01.png, game_over_spin.png)
    ├── ui/                     (life_01.png)
    └── audio/
        ├── music/              (bgm_01.mp3, start_music.mp3)
        └── sfx/                (jump.wav, crumble.wav, brick_hit.wav, death.wav,
                                 enemy_crush.wav, death_shout.mp3, spin.wav)
```

## 修改記錄

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
