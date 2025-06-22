package com.example.flutter_githubaction

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL_NAME = "com.example.flutter_githubaction/methods"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 将Flutter引擎的通信能力注册给NotificationListener的静态方法
        NotificationListener.configure(flutterEngine)

        // 设置MethodChannel，用于Flutter调用原生方法
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                if (call.method == "isNotificationListenerEnabled") {
                    val isEnabled = isNotificationServiceEnabled()
                    result.success(isEnabled)
                } else if (call.method == "ensureNotificationListenerEnabled") {
                    ensureNotificationListenerEnabled()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun ensureNotificationListenerEnabled() {
        val componentName = ComponentName(this, NotificationListener::class.java)
        val pm = packageManager
        // 禁用然后重新启用组件，这是一种在某些定制系统上（如ColorOS）强制重新绑定服务的技巧
        pm.setComponentEnabledSetting(
            componentName,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
        pm.setComponentEnabledSetting(
            componentName,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        val componentName = ComponentName(this, NotificationListener::class.java)
        return enabledListeners?.contains(componentName.flattenToString()) ?: false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.let { handleIntent(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.action == "SHOW_TRANSACTION_DIALOG") {
            val notificationData = mapOf(
                "source" to intent.getStringExtra("notification_source"),
                "title" to intent.getStringExtra("notification_title"),
                "text" to intent.getStringExtra("notification_text")
            )
            // 通过NotificationListener的静态方法发送数据
            NotificationListener.sendData(notificationData)
        }
    }
}
