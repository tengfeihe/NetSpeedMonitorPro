# NetSpeedMonitor Pro

## English

**NetSpeedMonitor Pro** is a lightweight, native macOS menu bar application that monitors your network speed in real-time.

Unlike other Electron-based apps, this tool is written in pure Swift and uses kernel-level system calls (`sysctl`) to ensure **near-zero CPU usage** and minimal memory footprint.

### ✨ Features

* **Extremely Lightweight** : Uses `sysctl` NET_RT_IFLIST2 for kernel-level monitoring. CPU usage is typically  **0.5%** .
* **Native Rendering** : Uses Core Graphics for direct drawing. No `NSTextField` overhead, no layer blending issues.
* **Multi-Language** : Supports English, Simplified Chinese, Traditional Chinese, and Japanese. Auto-detects system language.
* **Customizable** : Adjustable update intervals (1s, 2s, 5s, 10s, 30s) with persistence.
* **Smart Filtering** : Automatically filters out loopback (`localhost`) traffic and inactive interfaces.
* **Tools Integration** : Quick access to macOS Activity Monitor.

### 📥 Installation

1. Download the latest `.dmg` from the [Releases](https://www.google.com/search?q=https://github.com/tengfeihe/NetSpeedMonitorPro/releases "null") page.
2. Open the disk image and drag the app to your **Applications** folder.
3. Launch the app. It will appear in your menu bar.

### 🛠 Building from Source

You don't need Xcode to build this! A simple terminal command is enough.

**Prerequisites:**

* macOS with Swift installed (Command Line Tools).

**Build:**

```bash
# 1. Clone the repository
git clone https://github.com/tengfeihe/NetSpeedMonitorPro.git
cd NetSpeedMonitorPro

# 2. Run the build script
# This will compile the app and create a DMG installer automatically.
chmod +x build_dmg.sh
./build_dmg.sh
```

### 🤖 Acknowledgments

This project was developed with the assistance of  **Google Gemini** .


## 简体中文

**NetSpeedMonitor Pro** 是一款轻量级的 macOS 原生菜单栏网速监控应用。

与市面上臃肿的 Electron 应用不同，本项目完全使用 Swift 编写，并利用内核级系统调用 (`sysctl`) 直接读取网络数据，确保了 **极低的 CPU 占用** (通常仅为 0.5%) 和极小的内存消耗。

### ✨ 功能特性

* **极致轻量** : 基于 `sysctl` 内核接口监控，告别 `getifaddrs` 遍历开销。
* **原生渲染** : 使用 Core Graphics 直接绘图，无控件开销，完美适配深色模式。
* **多语言支持** : 支持 简体中文、繁体中文、英文、日文。自动跟随系统语言。
* **高度可定制** : 支持切换刷新频率 (1秒/2秒/5秒/10秒/30秒)，自动保存设置。
* **智能过滤** : 自动过滤本地回环 (`localhost`) 流量和未启动的网卡，数据更真实。
* **便捷工具** : 菜单内集成“打开活动监视器”入口，方便查毒。

### 📥 安装方法

1. 在 [Releases](https://www.google.com/search?q=https://github.com/tengfeihe/NetSpeedMonitorPro/releases "null") 页面下载最新的 `.dmg` 安装包。
2. 打开安装包，将应用拖入 **应用程序 (Applications)** 文件夹。
3. 启动应用，它将安静地驻留在你的菜单栏右上角。

### 🛠 源码编译

你甚至不需要安装庞大的 Xcode IDE，只需要 macOS 自带的终端工具即可编译。

**编译步骤:**

```bash
# 1. 克隆仓库
git clone https://github.com/tengfeihe/NetSpeedMonitorPro.git
cd NetSpeedMonitorPro

# 2. 运行构建脚本
# 脚本会自动编译代码、生成图标并打包成 DMG 文件。
chmod +x build_dmg.sh
./build_dmg.sh
```

### 🤖 致谢

本项目由 **Google Gemini** 辅助开发。

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://www.google.com/search?q=LICENSE "null") file for details.
