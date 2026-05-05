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

## 今日修改記錄 (2026-05-06)

- **排行榜修復**: 改用 Godot HTTPRequest + Firebase Firestore REST API，完全移除 JavaScriptBridge 依賴；leaderboard.gd 作為 autoload singleton 登錄於 project.godot
- **Restart 點擊修復**: GameOverScreen/Overlay 加入 `mouse_filter = 2 (MOUSE_FILTER_IGNORE)`，確保點擊事件穿透至 `_unhandled_input`
- **敵人圖片修復**: enemy.tscn 設定 `hframes=12, vframes=8`（對應 128x128 per frame），`ENEMY_SIZE` 調整為 19
- **敵人 y 定位修正**: 以碰撞框頂部 (4px) 為基準計算位移，修正敵人浮空問題
- **資料夾整理**: 全部素材移入 `assets/` 子目錄，並同步更新所有 .gd/.tscn/.import 的路徑參考
- **HTML 清理**: 移除 dragon_test.html 中的 Firebase JS SDK、CSS overlay 及 `window.DragonJumpFirebase` 物件
