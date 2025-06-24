<div align="center">
  <img src="assets/app_icon.png" alt="App Icon" width="128"/>
  <h1>自动记账 (AutoBookkeeping)</h1>
  <p><strong>一款真正懂你的智能记账App，让你彻底告别手动输入的繁琐。</strong></p>
  
  <p>
    <img src="https://img.shields.io/badge/Platform-Android-brightgreen.svg" alt="Platform: Android">
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT">
    <img src="https://img.shields.io/badge/UI-Material%203-blueviolet.svg" alt="UI: Material 3">
  </p>
</div>

---

你是否也曾因为懒得打开记账App，而让无数笔消费记录石沉大海？或者在每次支付后，都要繁琐地手动复制、粘贴、填写金额和商家？

**AutoBookkeeping** 专为解决这些痛点而生。它像一个安静的助手，在后台默默守护，一旦识别到支付通知，便会主动为你准备好一切，你只需轻轻一点，即可完成记账。

## ✨ 核心亮点

- **🧠 智能识别**: 自动捕获并精准解析支付宝、微信的支付通知。无论是支出还是收入，都能轻松识别。

- ** seamless 无缝体验**:
    - **App在前台**：直接弹出记账确认卡片，操作一气呵成。
    - **App在后台**：推送一条高优先级的"记账提醒"通知，点击即可完成记录，无需打开主应用。

- **🛡️ 权限健康检查**: 独创的"健康检查"系统，会引导你完成所有必要的权限设置（如通知读取、电池优化等），为App的稳定运行保驾护航。彻底告别"为什么收不到通知"的困扰。

- **📊 清晰看板**: 首页提供清晰的月度收支汇总和动态饼图，财务状况一目了然。支持下拉刷新，随时获取最新数据。

- **🔒 本地存储**: 所有交易数据均安全地存储在设备本地的SQLite数据库中，由你完全掌控，无需担心隐私泄露。

- **🛠️ 开发者友好**: 内置了功能强大的调试工具，包括实时日志查看器和通知模拟器，方便快速定位问题和贡献代码。

## 🚀 获取应用

### 方式一：下载稳定版 (推荐)
前往项目的 **[Releases 页面](https://github.com/ch-66/flutter_demo_cicd/releases)**，直接下载最新发布的稳定版APK。这是最简单、最可靠的方式。

### 方式二：体验开发版 (通过 CI/CD 构建)
我们项目的每一次代码更新都会触发CI/CD流程，自动构建出包含最新功能的开发版APK。

- **如果你想尝鲜或参与测试**：请前往项目的 **[Actions 页面](https://github.com/ch-66/flutter_demo_cicd/actions)**，在列表中点击最新的工作流记录，然后在页面底部的 "Artifacts" 部分下载构建产物。
- **如果你想贡献代码**：请 Fork 本仓库。当你发起一个 Pull Request 时，CI/CD会自动为你构建一个用于测试和审查的APK。

---

**⚠️ 重要**: 首次启动时，请务必根据"健康检查"页面的指引，完成所有权限的授权。这是App能正常工作的关键！

## 💻 技术栈

- **框架**: Flutter 3.x
- **UI**: Material 3
- **原生层 (Android)**: Kotlin
- **平台通信**: MethodChannel & EventChannel
- **本地数据库**: sqflite
- **状态管理**: StatefulWidget + Service单例模式
- **依赖库**: `permission_handler`, `fl_chart`, `app_settings`, ...

## 🗺️ 未来蓝图

本项目采用敏捷开发模式，并有清晰的路线图。我们计划在未来加入账单分类管理、历史账单编辑、云端同步等更多强大功能。

详情请参阅我们的 **[项目开发计划 (Development Plan)](./docs/development_plan.md)**。

## 🤝 贡献

我们欢迎任何形式的贡献，无论是提交Issue、发起Pull Request，还是改进文档。

## 📄 协议

本项目基于 [MIT License](./LICENSE) 开源。
