# Flutter 应用发布终极指南

本指南旨在提供一个全面、详细的清单，确保您在发布Flutter应用到 Google Play 和 Apple App Store 之前，完成所有必要的检查和配置。

---

## 一、通用发布前准备清单

这些步骤是针对两个平台的通用准备工作。

#### 1. 版本号管理
-   [ ] **更新版本号**: 在 `pubspec.yaml` 文件中，更新应用的版本号。
    -   格式为 `version: <major>.<minor>.<patch>+<build-number>` (例如: `1.0.0+1`)。
    -   `1.0.0` 是用户看到的**版本名称 (versionName)**。
    -   `+1` 是内部**构建号 (versionCode/buildNumber)**，每次发布到商店都**必须递增**。

#### 2. 代码和依赖项
-   [ ] **移除所有调试代码**:
    -   确保已删除或通过条件编译 (`kReleaseMode`) 禁用了所有的 `print()` 和 `debugPrint()` 语句。
    -   移除所有仅用于调试的页面、按钮或逻辑 (例如项目中的 `debug_screen.dart` 入口)。
-   [ ] **代码混淆与压缩 (强烈建议)**:
    -   Flutter在Release模式下默认会进行代码混淆（使用 `--obfuscate` 标志）。这会使您的Dart代码更难被逆向工程。
    -   在构建时使用 `--split-debug-info` 标志来分离调试信息，减小应用体积。
-   [ ] **依赖项审查**:
    -   运行 `flutter pub outdated` 检查是否有可更新的依赖项。
    -   移除 `pubspec.yaml` 中不再使用的包，然后运行 `flutter pub get`。
-   [ ] **错误和性能监控**:
    -   (可选但强烈建议) 集成第三方错误监控服务，如 Sentry 或 Firebase Crashlytics。这能帮助您在应用发布后，及时发现和定位用户遇到的崩溃问题。

#### 3. 资源和素材
-   [ ] **应用图标**:
    -   使用 `flutter_launcher_icons` 或类似工具，确保已为 Android 和 iOS 生成所有尺寸的正式版应用图标。
-   [ ] **启动画面 (Splash Screen)**:
    -   确认启动画面 (`splash screen`) 是最终版本，而不是默认的Flutter白色屏幕。可以使用 `flutter_native_splash` 包来定制。
-   [ ] **资源文件优化**:
    -   压缩 `assets/images/` 目录下的图片资源，以减小最终的应用体积。可以使用 TinyPNG 等工具。

#### 4. 全面测试
-   [ ] **Release 模式测试**:
    -   在真实设备上运行和测试 Release 版本的应用，而不是Debug版本。命令: `flutter run --release`。
    -   Release 模式的性能、行为可能与 Debug 模式有差异。
-   [ ] **多设备测试**:
    -   在不同品牌、不同屏幕尺寸、不同系统版本的真实设备上进行测试，特别是要覆盖您在 `android/app/build.gradle.kts` 中设置的 `minSdkVersion` 版本的设备。

---

## 二、Android 发布特定步骤 (Google Play)

#### 1. 生成发布签名密钥 (Keystore)
这是发布Android应用**最关键**的一步。您需要一个数字证书来为您的应用签名。

-   [ ] **生成密钥库 (Keystore)**: 如果您还没有，请使用以下命令生成一个。
    ```bash
    keytool -genkey -v -keystore <keystore-name>.jks -keyalg RSA -keysize 2048 -validity 10000 -alias <key-alias>
    ```
    -   **备份! 备份! 备份!**: **务必将生成的 `.jks` 文件和您设置的密码、别名等信息备份到安全的地方。如果丢失，您将永远无法更新您的应用！**

#### 2. 配置签名信息
-   [ ] **创建 `key.properties` 文件**: 在 `android/` 目录下创建一个名为 `key.properties` 的文件，**不要**将此文件提交到Git。
    ```properties
    storePassword=<你的密钥库密码>
    keyPassword=<你的密钥别名密码>
    keyAlias=<你的密钥别名>
    storeFile=<keystore-name>.jks
    ```
-   [ ] **配置 `build.gradle.kts`**: 修改 `android/app/build.gradle.kts` 文件以读取 `key.properties` 并配置签名。
    ```kotlin
    // ... at the top of the file
    val keyProperties = java.util.Properties()
    val keyPropertiesFile = rootProject.file("key.properties")
    if (keyPropertiesFile.exists()) {
        keyProperties.load(java.io.FileInputStream(keyPropertiesFile))
    }

    android {
        // ...

        signingConfigs {
            create("release") {
                keyAlias = keyProperties["keyAlias"] as String?
                keyPassword = keyProperties["keyPassword"] as String?
                storeFile = file(keyProperties["storeFile"] as String?)
                storePassword = keyProperties["storePassword"] as String?
            }
        }

        buildTypes {
            release {
                // ...
                signingConfig = signingConfigs.getByName("release")
                // 启用 R8 代码压缩和优化
                isMinifyEnabled = true
                isShrinkResources = true
                // 定义 ProGuard 规则
                proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            }
        }
    }
    ```
-   [ ] **更新 `.gitignore`**: 在项目根目录的 `.gitignore` 文件中，添加以下行，防止密钥被提交：
    ```gitignore
    /android/key.properties
    *.jks
    ```

#### 3. 检查 `AndroidManifest.xml`
-   [ ] **权限检查**: 仔细检查 `android/app/src/main/AndroidManifest.xml` 中的 `<uses-permission>` 标签。只申请应用绝对需要的权限。对于每个权限，都要准备好向Google Play解释其用途。
-   [ ] **移除 `debuggable`**: 确保 `application` 标签中没有 `android:debuggable="true"`。 (Flutter的release构建会自动处理，但检查一下更安全)。

#### 4. 构建发布包
-   [ ] **构建 App Bundle (.aab)**: Google Play 推荐使用 App Bundle 格式，因为它可以优化分发体积。
    ```bash
    flutter build appbundle
    ```
    -   构建完成后，发布文件位于 `build/app/outputs/bundle/release/app-release.aab`。

---

## 三、iOS 发布特定步骤 (App Store)

#### 1. 准备工作
-   [ ] **Apple Developer Program**: 确保您拥有一个有效的、付费的 Apple Developer 账户。

#### 2. Xcode 项目配置
-   [ ] **打开Xcode**: 使用Xcode打开您项目中的 `ios/Runner.xcworkspace` 文件。
-   [ ] **设置身份和签名**: 在 `Runner` -> `Signing & Capabilities` 中:
    -   勾选 `Automatically manage signing`。
    -   选择您的 `Team`。
    -   确保 `Bundle Identifier` 是您在 App Store Connect 中注册的唯一标识符。
-   [ ] **设置部署目标**: 在 `General` -> `Deployment Info` 中，设置应用支持的最低 iOS 版本 (`Target`)。
-   [ ] **检查 `Info.plist`**:
    -   检查 `Runner/Info.plist` 文件中的 `CFBundleDisplayName`, `CFBundleShortVersionString` (版本名称), 和 `CFBundleVersion` (构建号)。Flutter 构建时会自动更新这些值，但需要确认。
    -   如果您的应用需要访问任何受保护的资源（如相机、位置、相册），必须在此文件中添加对应的 `...UsageDescription` 键和说明文字。

#### 3. 构建和上传
-   [ ] **构建归档文件 (.ipa)**:
    ```bash
    flutter build ipa
    ```
-   [ ] **通过Xcode上传**:
    -   构建完成后，在Xcode中，进入 `Product` -> `Archive`。
    -   在弹出的 Archives 窗口中，选择刚刚构建的版本，点击 `Distribute App`。
    -   按照向导，选择 `App Store Connect`，然后上传到您的账户。
-   [ ] **通过TestFlight测试**:
    -   上传成功后，登录 [App Store Connect](https://appstoreconnect.apple.com/)。
    -   在您的应用下，进入 `TestFlight` 标签页。
    -   将构建版本添加给内部或外部测试员进行最后一轮测试。

---

此指南涵盖了发布流程的核心要点。请务必在每次发布前逐项核对，特别是备份好您的签名密钥。 