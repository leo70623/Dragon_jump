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

## 素材資源

### 音效素材
- **Kenney** — kenney.nl/assets，CC0 完全免費，無版權限制，適合遊戲商用
- **Mixkit** — mixkit.co/free-sound-effects，免費下載無浮水印，允許遊戲商用
- **ElevenLabs Sound Effects** — elevenlabs.io/sound-effects，AI 生成音效，免費方案每月有額度，生成後可商用，輸入文字描述生成

### 音效格式規範
- 格式：WAV，取樣率 44100Hz（Godot 4 相容），避免 48000Hz
- 若音效為 48000Hz 請用 ffmpeg 轉換：
  ffmpeg -i input.wav -ar 44100 output.wav

## 部署

### iOS ipa 安裝
- ipa 預設下載路徑：~/Downloads/
- 安裝指令：ios-deploy --bundle ~/Downloads/檔名.ipa --no-wifi
- 需要裝置已加入 Apple Developer Provisioning Profile
- Apple Developer Program 需有效（$99/年）

## 版本紀錄

### 2026-05-18（feature/v1.5-pump-item）
- **打氣機道具**：新增 PUMP 道具（item_pump.png），三種道具等機率出現
- **膨脹飄浮**：吃到後角色自動上升 7 秒，充氣 1 秒→最膨 5 秒→消氣 1 秒，速度最高 550px/s
- **膨脹動畫**：dragon_pump_sheet.png 三幀 spritesheet，scale 從 0.25 漸變至 0.5
- **碰撞消滅**：膨脹狀態碰到敵人或黑雲消滅對方，顯示 effect_puff 白煙動畫
- **穿越磚塊**：膨脹期間忽略 Brick 碰撞層
- **音效**：充氣（sfx_pump_inflate.wav）、消氣（sfx_pump_deflate.wav）、消滅（enemy_crush.wav）
- **待修**：膨脹狀態分數 UI 不即時更新、碰撞範圍待觀察

### 2026-05-16（feature/v1.2-difficulty-tuning）
- **新手保護區**：200 分前白雲 90%、棕雲 10%、平台靜止、間距 60–75px
- **錯位雙平台**：新增 _try_spawn_second()，依分數分段控制機率與類型，200分前棕雲固定不移動
- **難度對應表**：建立 docs/difficulty_table.md 記錄各分數段平台、移動、敵人設定

### 2026-05-17（feature/v1.3-difficulty-redesign）
- **難度四段重設計**：0–199 新手保護 / 200–599 入門挑戰 / 600–999 中級壓力 / 1000+ 高手模式
- **背景切換對齊**：背景切換點改為 0 / 200 / 600 / 1000 對齊難度分段
- **新手保護區強化**：X 軸分左中右三區分布，平台全部靜止
- **道具頻率調整**：依分數段動態調整生成間隔（15 / 10 / 8 / 6）
- **BRICK 錯位**：BRICK 平台 X 軸強制偏向對側，避免影響 combo
- **Game over 動畫**：GAME OVER 改為 Keep it up! / New Record! 動畫，加入搖擺與脈動效果
- **新紀錄慶祝**：全版跑分動畫 + 龍煙火施放（jump_up / jump_land）+ 炫彩標題循環變色
- **煙火音效**：嗚呼主音效（record_whoop.wav）+ 煙火背景循環音（fireworks_loop.wav）
- **排行榜排名**：分隔線下方顯示自己排名，格式與排行榜一致
- **首頁按鈕**：Leaderboard 按鈕改為藍色圓角樣式

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
- 版本紀錄格式統一為：### 日期（feature/branch名稱）+ - **類別**：說明，README 和 PROJECT_CONTEXT 保持一致
- 給 Claude Code 的指令用白話文描述，盡量少用程式碼片段溝通，讓 Claude Code 自行判斷實作方式

## 重要工作方式
1. 程式碼相關的操作（讀檔、修改、執行）一律透過 Claude Code 執行，不需要用戶貼程式碼
2. 給 Claude Code 的指令用單一 code block 包住，用戶直接複製貼上
3. Claude Code 回傳的結果用戶會貼回對話，根據結果繼續分析
4. 實作前先確認需求和預期結果，不急著下指令
5. 遇到不清楚的地方先提問，一次只問一個問題
6. 設計決策先用表格或視覺化確認再給 Claude Code 實作
7. 每個新功能版本建立新 branch（feature/v版本號-功能名稱），同一版本內持續 commit 到同一 branch
8. 與 Claude Code 溝通時使用白話文，避免在指令中直接寫程式碼，由 Claude Code 自行決定實作細節

流程：需求 → 確認理解 → Claude Code 指令（code block）→ 用戶執行後貼結果 → 分析 → 繼續
