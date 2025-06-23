package com.autobookkeeping.app

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import androidx.core.app.NotificationCompat

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL_NAME = "com.autobookkeeping.app/methods"
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001
    
    // Channel for bookkeeping notifications sent from Flutter
    private val BOOKKEEPING_CHANNEL_ID = "intelligent_bookkeeping_alerts"
    private var notificationIdCounter = 3000 // Start from a high number to avoid conflicts

    companion object {
        // Restore the static variable. This acts as a reliable fallback cache.
        var pendingIntentNotification: Map<String, Any?>? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 将Flutter引擎的通信能力注册给NotificationListener的静态方法
        NotificationListener.configure(flutterEngine)

        // 设置MethodChannel，用于Flutter调用原生方法
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationListenerEnabled" -> {
                        val isEnabled = isNotificationServiceEnabled()
                        result.success(isEnabled)
                    }
                    "ensureNotificationListenerEnabled" -> {
                        ensureNotificationListenerEnabled()
                        result.success(null)
                    }
                    "getLogcat" -> {
                        val logs = getLogcatLogs()
                        result.success(logs)
                    }
                    "getPendingIntentNotification" -> {
                        result.success(pendingIntentNotification)
                        pendingIntentNotification = null // Clear after reading
                    }
                    "showBookkeepingNotification" -> {
                        val args = call.arguments as? Map<String, Any>
                        if (args != null) {
                            showBookkeepingNotification(args)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "Missing arguments for notification", null)
                        }
                    }
                    else -> result.notImplemented()
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

        createBookkeepingNotificationChannel()

        // 显式启动通知监听服务，确保它能立即作为前台服务运行
        val serviceIntent = Intent(this, NotificationListener::class.java)
        startService(serviceIntent)
        
        checkAndRequestNotificationPermission()
        intent?.let { handleIntent(it) }
    }

    override fun onStart() {
        super.onStart()
        NotificationListener.isAppInForeground = true
    }

    override fun onStop() {
        super.onStop()
        NotificationListener.isAppInForeground = false
    }

    override fun onDestroy() {
        super.onDestroy()
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
                "text" to intent.getStringExtra("notification_text"),
                "isFromManualClick" to "true"
            )
            // Restore caching to the static variable as a fallback.
            pendingIntentNotification = notificationData
            // Also send to the primary channel. The first one to deliver wins.
            NotificationListener.sendData(notificationData)
        }
    }

    private fun checkAndRequestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) { // TIRAMISU is Android 13
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) {
                // You can directly ask for the permission.
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE
                )
            }
        }
    }

    // 新增：获取最近200行logcat日志
    private fun getLogcatLogs(): String {
        return try {
            // We get all recent logs and then filter them by our app's package name
            // to provide clean, relevant output.
            val process = Runtime.getRuntime().exec("logcat -d")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val packageName = context.packageName
            val relevantLogs = StringBuilder()

            reader.forEachLine { line ->
                if (line.contains(packageName)) {
                    relevantLogs.append(line).append('\n')
                }
            }
            reader.close()

            if (relevantLogs.isNotEmpty()) {
                relevantLogs.toString()
            } else {
                "No logs found for package: $packageName"
            }
        } catch (e: Exception) {
            "获取logcat失败: ${e.message}"
        }
    }

    private fun createBookkeepingNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                BOOKKEEPING_CHANNEL_ID,
                "智能记账提醒",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "成功解析交易后，由App主动发出的记账提醒"
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showBookkeepingNotification(data: Map<String, Any>) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // --- Data for displaying the notification ---
        val amount = data["amount"] as? Double ?: 0.0
        val merchant = data["merchant"] as? String ?: "未知"
        val type = data["type"] as? String ?: "交易"
        val contentTitle = "新的${type}交易"
        val contentText = "金额: ${"%.2f".format(amount)}, 商家: $merchant. 点击记账。"

        // --- Data for the intent (to be re-parsed by Flutter) ---
        // This MUST be the original data from the payment app notification
        val source = data["source"] as? String ?: "unknown"
        val originalTitle = data["title"] as? String ?: "" // Assume Flutter sends this back
        val originalText = data["text"] as? String ?: ""   // Assume Flutter sends this back

        // Create an intent that will open the app when the notification is tapped.
        val openAppIntent = Intent(applicationContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            action = "SHOW_TRANSACTION_DIALOG"
            // IMPORTANT: Pass the ORIGINAL data back, so Flutter can re-parse it consistently.
            putExtra("notification_source", source)
            putExtra("notification_title", originalTitle) // Use original title
            putExtra("notification_text", originalText)   // Use original text
        }

        val pendingIntent: PendingIntent = PendingIntent.getActivity(
            this,
            notificationIdCounter, // Use unique request code
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Build the notification with the clean, formatted text
        val notification = NotificationCompat.Builder(this, BOOKKEEPING_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(notificationIdCounter++, notification)
    }
}
