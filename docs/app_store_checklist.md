# 应用上架材料清单 (Google Play Store)

本文档旨在提供一个清单，帮助您准备将Flutter应用发布到Google Play商店所需的全部材料。

---

### 1. 店面信息 (Store Listing)

这些是用户在商店页面上直接看到的核心信息。

-   [ ] **应用名称 (App Name)**
    -   长度：最多 50 个字符。
    -   示例: `自动记账`

-   [ ] **简短说明 (Short Description)**
    -   长度：最多 80 个字符。
    -   这是用户在商店列表第一眼看到的摘要。
    -   示例: `一款通过监听支付通知，实现自动记账的智能应用。`

-   [ ] **详细说明 (Full Description)**
    -   长度：最多 4000 个字符。
    -   详细介绍应用的功能、优势和使用场景。可以分点、分段落，使其清晰易读。

---

### 2. 图形资源 (Graphics)

图形资源是吸引用户下载的关键。请确保所有图片都清晰、美观且符合规范。

-   [ ] **高分辨率图标 (High-resolution icon)**
    -   **尺寸**: `512 x 512` 像素。
    -   **格式**: 32位 PNG (含Alpha通道)。
    -   *项目内已有路径 (请确认尺寸)*: `assets/app_icon.png`

-   [ ] **置顶大图 (Feature Graphic)**
    -   **尺寸**: `1024 x 500` 像素。
    -   **格式**: JPG 或 24位 PNG (不含Alpha通道)。
    -   这是商店页面的头部横幅，应包含品牌和核心信息。

-   [ ] **手机屏幕截图 (Phone Screenshots)**
    -   **数量**: 2 到 8 张。
    -   **格式**: JPG 或 24位 PNG (不含Alpha通道)。
    -   **尺寸**: 边长介于 320 像素至 3840 像素之间，宽高比不能超过 2:1 或 1:2。
    -   **建议截图页面**:
        -   `lib/presentation/screens/home_screen.dart` (首页)
        -   `lib/presentation/screens/history_screen.dart` (历史记录)
        -   `lib/presentation/screens/settings_screen.dart` (设置页)
        -   一个交易确认对话框的截图。

-   [ ] **7英寸平板电脑屏幕截图 (7-inch Tablet Screenshots)** (可选，但建议提供)
    -   规范同手机截图。

-   [ ] **10英寸平板电脑屏幕截图 (10-inch Tablet Screenshots)** (可选，但建议提供)
    -   规范同手机截图。

---

### 3. 应用信息与合规性

-   [ ] **应用类别 (Application Category)**
    -   类型: 应用 (Application) 或 游戏 (Game)。
    -   类别: 财务、工具、效率等。

-   [ ] **内容分级 (Content Rating)**
    -   在 Play 管理中心填写内容分级调查问卷。

-   [ ] **隐私政策 (Privacy Policy)**
    -   **要求**: 提供一个公开可访问的URL，指向您的隐私政策文档。
    -   **重要**: 由于您的应用使用了 `NotificationListenerService` 来访问用户通知，这是一项敏感权限，因此**隐私政策是强制性的**。您需要清楚地说明应用收集了哪些数据（如通知内容）、为什么收集以及如何使用这些数据。

-   [ ] **联系方式 (Contact Details)**
    -   [ ] 网站 (可选)
    -   [ ] 电子邮件地址 (必填)
    -   [ ] 电话号码 (可选)

---

### 4. 发布包 (Release Bundle)

-   [ ] **签名的 App Bundle 或 APK**
    -   **格式**: 推荐使用 Android App Bundle (`.aab`)。
    -   **签名**: 必须使用发布密钥库 (release keystore) 进行签名。
    -   *提示*: 您在 `development_plan.md` 中提到已设置CI/CD，请确保CI流程生成的是签名的发布版本。
    -   **调试功能**: 在打包前，请务必确认所有调试功能（如 `debug_screen.dart` 的入口）已被移除或禁用。

---

### 下一步行动建议

1.  **创建隐私政策页面**: 您可以使用 Github Pages、Gitee Pages 或其他静态网站托管服务免费创建一个隐私政策页面。
2.  **准备图形素材**: 根据上述规范，设计置顶大图并截取应用截图。
3.  **填写文本信息**: 撰写吸引人的应用名称和说明。
4.  **打包并测试**: 生成签名的发布包，并在真实设备上进行最后一轮安装和测试，确保一切正常。 