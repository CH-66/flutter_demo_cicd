# 项目说明：自动记账App

## 1. 项目愿景

开发一款智能记账App，旨在将用户从繁琐的手动记账流程中解放出来。通过自动识别主流支付平台（微信、支付宝）的交易通知，实现"一键记账"，让个人财务管理变得前所未有的轻松、智能和高效。

## 2. 核心功能

- **自动捕获交易**：在用户授权后，App能够在后台监听系统通知，自动识别来自微信和支付宝的支付成功信息。
- **智能解析**：自动从通知文本中提取关键数据，如**交易金额**、**商户信息**和**支付时间**。
- **悬浮窗快捷确认**：以非打扰的底部弹窗形式，向用户推送已解析的交易信息，并提供预设的交易分类。
- **一键记账**：用户只需检查信息并点击"确认"，即可将该笔交易存入本地数据库。整个过程耗时不超过3秒。
- **手动记账**：保留传统的"点击+号"手动记账功能，作为自动捕获的补充，覆盖线下现金支付等场景。
- **数据可视化**：提供清晰的日/月/年视图，通过图表（如饼图、折线图）直观展示用户的消费结构和财务趋势。
- **数据安全**：所有交易数据仅存储在用户本地设备，确保用户隐私安全。

## 3. 技术栈

- **前端/UI**: Flutter
- **状态管理**: (待定, 根据复杂度选择 Riverpod 或 Bloc)
- **原生通信**: Platform Channels
- **Android 端**: `NotificationListenerService` 用于监听通知。
- **iOS 端**: (待定, 实现难度高，需调研替代方案)
- **本地存储**: `sqflite` 或 `drift` (高性能的本地SQL数据库)

## 4. 目标用户

- 追求高效率，希望简化生活流程的年轻用户。
- 有记账需求，但常常因为过程繁琐而放弃的群体。
- 希望能清晰掌握自己财务状况，但又不愿投入过多时间的用户。 