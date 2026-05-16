# Dragon Jump 專案說明文件

## 基本資訊
- 專案路徑：/Users/chlienoi-imac/Desktop/dragon_jump
- GitHub：leo70623/Dragon_jump（public）
- GitHub Pages：https://leo70623.github.io/Dragon_jump/
- 技術：Godot 4.6，GL Compatibility，Jolt Physics
- 設計解析度：360×640（9:16），canvas_items/expand
- iOS：GitHub Actions 自動 build（ios-build.yml），ios-deploy 安裝 ipa

## 主要檔案
- main.gd / main.tscn — 主遊戲邏輯
- player.gd / player.tscn — 玩家角色
- platform.gd / platform.tscn — 平台（動態生成）
- enemy.gd / enemy.tscn — 敵人
- start_screen.gd — 開始畫面
- leaderboard.gd — Firebase 排行榜 autoload

## 平台類型
- NORMAL (0)：白雲，可無限踩踏
- CRUMBLE (1)：棕雲，踩後崩解，+1分
- DAMAGE (2)：黑雲，觸碰死亡
- BRICK (3)：磚塊雲，實體碰撞，無法穿越

## 分數機制
- 起始 0 分
- 上升 100px = +2 分（含 combo 加成）
- 踩敵人 +10 分
- 踩棕雲 +1 分
- Combo：落地點比上次更高累加，combo ≥ 3 開始有加成（每100px +combo-2分）

## 難度曲線（v1.3）

### 0–199 新手保護
- 白雲 90%、棕雲 10%，黑雲磚塊不出現
- 間距 60–75px（約 8–10 個平台在畫面內）
- 平台全部靜止，X 軸分左中右三區
- 敵人不出現
- 道具間隔 15 個 NORMAL 平台

### 200–599 入門挑戰
- 白雲 70%、棕雲 15%、黑雲 5%、磚塊 10%
- 間距 80–100px
- 移動機率 20%，速度 100px/s
- 敵人每 10 台一隻，靜止
- 道具間隔 10 個 NORMAL 平台

### 600–999 中級壓力
- 白雲 55%、棕雲 25%、黑雲 10%、磚塊 10%
- 間距 100–120px
- 移動機率 30%，速度 120px/s
- 敵人每 8 台一隻，移動 50px/s
- 道具間隔 8 個 NORMAL 平台

### 1000+ 高手模式
- 白雲 45%、棕雲 25%、黑雲 15%、磚塊 15%
- 間距 120–140px
- 移動機率 40%，速度 140px/s
- 敵人每 6 台一隻，移動 70px/s
- 道具間隔 6 個 NORMAL 平台

## 背景切換
- 0–199：BG_01.png
- 200–599：BG_02.png
- 600–999：BG_03.png
- 1000+：BG_04.png

## Firebase 設定
- 專案 ID：dragon-jump-f2b22
- Collection：leaderboard
- 欄位：name, score, country, date
- 排行榜顯示前 20 名 + 自己排名

## 音效檔案
- jump.wav：落在白雲/棕雲
- crumble.wav：踩棕雲崩解
- brick_hit.wav：踩磚塊
- death.wav：死亡
- death_shout.mp3：game over 瞬間
- spin.wav：死亡旋轉動畫
- enemy_crush.wav：踩敵人
- record_whoop.wav：新紀錄嗚呼音效
- fireworks_loop.wav：煙火背景循環音

## 版本紀錄
- v1.2：新手保護區、錯位雙平台、難度表格
- v1.3：難度四段重設計、Game over 動畫、龍煙火慶祝、排行榜自己排名

## 待處理
- [ ] 排行榜自己排名欄位對齊問題
- [ ] Apple Developer Program 續費後更新 Provisioning Profile
- [ ] 三隻新裝置 UDID：00008101-00050DA90E50001E / 00008030-0001601C2133802E / 00008130-001C70393E40001C
- [ ] ios-build.yml Godot 版本更新至 4.6
- [ ] Splash screen 純黑問題
- [ ] Android export preset

## 對話習慣
- 所有給 Claude Code 的指令用單一 code block 包住，方便一鍵複製
- 實作前先確認需求和預期結果，不急著下指令
- 每個新功能版本開始時建立新 branch（feature/v版本號-功能名稱），同一版本內的修改持續 commit 到同一個 branch，不直接推到 main
- 遇到不清楚的地方先提問再實作
- 難度、UI 等設計決策先用表格或視覺化確認，再給 Claude Code 實作
- 給 Claude Code 的指令盡量一次整合多個修改，減少來回次數
