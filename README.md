# FRC 7632 Scouting System - 2026 Season

![Team 7632 Banner](https://github.com/team7632/FRC-ScoutApp/blob/master/assets/images/favicon.png)

[![Instagram](https://img.shields.io/badge/Instagram-FRC%207632-E4405F?logo=instagram&logoColor=white)](https://www.instagram.com/frc_team_7632/)
[![Facebook](https://img.shields.io/badge/Facebook-FRC%207632-1877F2?logo=facebook&logoColor=white)](https://www.facebook.com/FRCTeam7632)

這是由 FRC Team 7632  軟體團隊開發的賽季偵查系統。本專案整合了 **Desktop 管理端** 與 **Mobile 偵查端**，旨在提供高效、精確的賽場數據蒐集解決方案。

---

## 🚀 系統架構

本系統採用 Client-Server 架構，確保數據在比賽現場的即時同步與安全儲存。



### 1. 🖥️ 管理端 (Server Console)
基於 **Electron & Express** 開發，作為數據中心。
* **TBA 同步**：一鍵抓取 The Blue Alliance 賽程。
* **房間管理**：分配偵查員位置（Red 1-3, Blue 1-3）。
* **即時 Dashboard**：顯示所有偵查員的連線狀態與提交進度。
* **本地存儲**：數據自動持久化至 `database.json`。

### 2. 📱 偵查端 (Scouter App)
基於 **Flutter** 開發，專注於極簡的 UI/UX 操作。
* **自動導航**：偵查完畢後自動引導至評分頁面，並返回房間首頁。
* **動態同步**：透過 HTTP Polling 每 5 秒同步一次場次資訊。
* **橫向/縱向切換**：偵查過程強制橫向增加視野，評價與備註切換至縱向便於輸入。

---

## 🛠️ 開發與部署

### 前置要求
* Node.js (v24+)
* Flutter SDK (最新穩定版)
* 區域網路（確保電腦與手機在同一 Wi-Fi）

### 快速啟動
1.  **啟動伺服器**：
    ```bash
    cd server-directory
    npm install
    npm start
    ```
2.  **啟動手機 App**：
    ```bash
    flutter run
    ```

---

## 📈 數據結構

系統蒐集的關鍵指標包括：
* **Auto**: Ball count, Mobility (Leave), Auto Hang.
* **Teleop**: High/Low Goals, Cycles.
* **Endgame**: Climb Level, Park.
* **Drive Score**: 基於人機介面的 1-5 星級評價與質性備註。

---

## 📱 聯繫我們 (Contact Us)

如果您對本系統有任何疑問或想了解更多關於 **FRC 7632** 的資訊：

* **Instagram**: [@frc_team_7632](https://www.instagram.com/frc_team_7632/)
* **Facebook**: [FRC Team 7632](https://www.facebook.com/FRCTeam7632)

---
> *Built with ❤️ by FRC 7632 Strategy & Programming Team.*
> (Ai內容切勿當真)
