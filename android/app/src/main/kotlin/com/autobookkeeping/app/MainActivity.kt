package com.autobookkeeping.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL_NAME = "com.autobookkeeping.app/methods"
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001
    
    private val BOOKKEEPING_CHANNEL_ID = "intelligent_bookkeeping_alerts"
    private var notificationIdCounter = 3000

    companion object {
        var pendingIntentNotification: Map<String, Any?>? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationListener.configure(flutterEngine)

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
                        pendingIntentNotification = null
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
                    "isIgnoringBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                            val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)
                            result.success(isIgnoring)
                        } else {
                            result.success(true)
                        }
                    }
                    "openNotificationListenerSettings" -> {
                         val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                         startActivity(intent)
                         result.success(true)
                    }
                    "getNotificationChannelImportance" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val channelId = call.argument<String>("channelId")
                            if (channelId == null) {
                                result.error("MISSING_ARG", "channelId is required", null)
                            } else {
                                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                                val channel = notificationManager.getNotificationChannel(channelId)
                                result.success(channel?.importance ?: 3)
                            }
                        } else {
                            result.success(4)
                        }
                    }
                    "openNotificationChannelSettings" -> {
                        val channelId = call.argument<String>("channelId")
                        if (channelId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra("app_package", packageName)
                                putExtra("app_uid", applicationInfo.uid)
                            }
                            startActivity(intent)
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureNotificationListenerEnabled() {
        val componentName = ComponentName(this, NotificationListener::class.java)
        val pm = packageManager
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
            pendingIntentNotification = notificationData
            NotificationListener.sendData(notificationData)
        }
    }

    private fun checkAndRequestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE
                )
            }
        }
    }

    private fun getLogcatLogs(): String {
        return try {
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

        val amount = data["amount"] as? Double ?: 0.0
        val merchant = data["merchant"] as? String ?: "未知"
        val type = data["type"] as? String ?: "交易"
        val contentTitle = "新的${type}交易"
        val contentText = "金额: ${"%.2f".format(amount)}, 商家: $merchant. 点击记账。"

        val source = data["source"] as? String ?: "unknown"
        val originalTitle = data["title"] as? String ?: ""
        val originalText = data["text"] as? String ?: ""

        val openAppIntent = Intent(applicationContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            action = "SHOW_TRANSACTION_DIALOG"
            putExtra("notification_source", source)
            putExtra("notification_title", originalTitle)
            putExtra("notification_text", originalText)
        }

        val pendingIntent: PendingIntent = PendingIntent.getActivity(
            this,
            notificationIdCounter++,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

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
