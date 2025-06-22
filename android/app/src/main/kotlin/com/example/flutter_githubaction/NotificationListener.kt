package com.example.flutter_githubaction

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class NotificationListener : NotificationListenerService() {

    companion object {
        private const val EVENT_CHANNEL_NAME = "com.example.flutter_githubaction/notifications"
        private var eventSink: EventChannel.EventSink? = null
        var isAppInForeground = false // 全局变量，用于精确跟踪App状态

        fun configure(flutterEngine: FlutterEngine) {
            val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NAME)
            eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
        }
        
        fun sendData(data: Map<String, Any?>) {
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(data)
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    
    // 用于我们自己发送通知的配置
    private val NOTIFICATION_CHANNEL_ID = "transaction_alerts_v2"
    private val NOTIFICATION_CHANNEL_NAME = "交易记账提醒"
    private var notificationIdCounter = 2024 // 通知ID的起始值，避免冲突

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    // 创建我们App专用的通知渠道
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "接收到支付通知时，弹出记账提醒"
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName
        val notification = sbn.notification
        val extras = notification.extras
        val title = extras.getString("android.title")
        val text = extras.getString("android.text")

        Log.d("NotificationListener", "--- New Notification Received ---")
        Log.d("NotificationListener", "Package: $packageName")
        Log.d("NotificationListener", "Title: $title")
        Log.d("NotificationListener", "Text: $text")

        // 1. 过滤我们关心的应用
        if (packageName != "com.tencent.mm" && packageName != "com.eg.android.AlipayGphone") {
            Log.d("NotificationListener", "Result: Skipped (Not a target app).")
            return
        }

        if (title.isNullOrBlank() && text.isNullOrBlank()) {
            Log.d("NotificationListener", "Result: Skipped (Empty content).")
            return
        }
        
        val notificationData = mapOf(
            "source" to packageName,
            "title" to title,
            "text" to text
        )

        // 2. 判断App状态
        if (isAppInForeground) {
            // App 在前台: 直接发送数据到Flutter
            Log.d("NotificationListener", "App in foreground. Sending data to Flutter.")
            handler.post {
                eventSink?.success(notificationData)
            }
        } else {
            // App 在后台: 显示一个通用的系统通知
            Log.d("NotificationListener", "App in background. Showing generic system notification.")
            showGenericBookkeepingNotification(notificationData)
        }
        Log.d("NotificationListener", "--- Notification Processed ---")
    }

    private fun showGenericBookkeepingNotification(originalData: Map<String, Any?>) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val sourceAppName = if (originalData["source"] == "com.eg.android.AlipayGphone") "支付宝" else "微信"

        val contentTitle = "有新的$sourceAppName交易通知"
        val contentText = "点击查看并记账"

        // 创建一个意图：当用户点击通知时，打开我们的MainActivity
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            action = "SHOW_TRANSACTION_DIALOG" // 自定义一个Action
            // 将原始通知数据附加到意图中，以便Flutter端接收和处理
            putExtra("notification_title", originalData["title"] as? String)
            putExtra("notification_text", originalData["text"] as? String)
            putExtra("notification_source", originalData["source"] as? String)
        }
        // 将普通Intent包装成PendingIntent
        val openAppPendingIntent: PendingIntent = PendingIntent.getActivity(
            this,
            notificationIdCounter, // 使用递增的ID确保每个PendingIntent是唯一的
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 使用NotificationCompat构建器来创建通知
        val notificationBuilder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher) // 使用App的启动图标
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setPriority(NotificationCompat.PRIORITY_HIGH) // 设置高优先级，确保通知会弹出
            .setContentIntent(openAppPendingIntent) // 设置点击通知后的意图
            .setAutoCancel(true) // 用户点击后自动移除通知

        // 使用唯一的ID发送通知，并递增计数器
        notificationManager.notify(notificationIdCounter++, notificationBuilder.build())
    }
} 