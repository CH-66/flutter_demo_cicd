package com.autobookkeeping.app

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
        // 队列缓存，支持多条待处理通知
        private val pendingNotificationQueue = mutableListOf<Map<String, Any?>>()

        fun configure(flutterEngine: FlutterEngine) {
            val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NAME)
            eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.d("NotificationListener", "onListen called, eventSink set, queue size: ${pendingNotificationQueue.size}")
                    // 派发所有缓存数据
                    if (pendingNotificationQueue.isNotEmpty()) {
                        for (data in pendingNotificationQueue) {
                            Log.d("NotificationListener", "onListen: sending cached data: $data")
                            Handler(Looper.getMainLooper()).post {
                                eventSink?.success(data)
                            }
                        }
                        pendingNotificationQueue.clear()
                    }
                }
                override fun onCancel(arguments: Any?) {
                    Log.d("NotificationListener", "onCancel called, eventSink cleared")
                    eventSink = null
                }
            })
        }
        
        fun sendData(data: Map<String, Any?>) {
            Log.d("NotificationListener", "sendData called, eventSink=$eventSink, data=$data, queue size: ${pendingNotificationQueue.size}")
            if (eventSink == null) {
                // 如果Flutter端还没准备好，就入队
                pendingNotificationQueue.add(data)
                Log.d("NotificationListener", "EventSink not ready. Caching notification data (queue size: ${pendingNotificationQueue.size})")
                return
            }
            // 派发所有缓存数据
            if (pendingNotificationQueue.isNotEmpty()) {
                for (pending in pendingNotificationQueue) {
                    Handler(Looper.getMainLooper()).post {
                        Log.d("NotificationListener", "EventSink is ready. Sending cached data from queue: $pending")
                        eventSink?.success(pending)
                    }
                }
                pendingNotificationQueue.clear()
            }
            Handler(Looper.getMainLooper()).post {
                Log.d("NotificationListener", "EventSink is ready. Sending data to Flutter: $data")
                eventSink?.success(data)
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    
    // 用于我们自己发送通知的配置
    private val FOREGROUND_CHANNEL_ID = "foreground_service_channel"
    private val FOREGROUND_CHANNEL_NAME = "服务运行状态"
    private val FOREGROUND_NOTIFICATION_ID = 101

    private val NOTIFICATION_CHANNEL_ID = "transaction_alerts_v2"
    private val NOTIFICATION_CHANNEL_NAME = "交易记账提醒"
    private var notificationIdCounter = 2024 // 通知ID的起始值，避免冲突

    override fun onCreate() {
        super.onCreate()
        // 必须先创建渠道，再创建通知
        createForegroundNotificationChannel()
        createNotificationChannel()

        // 启动前台服务
        val notification = NotificationCompat.Builder(this, FOREGROUND_CHANNEL_ID)
            .setContentTitle("记账助手运行中")
            .setContentText("正在监听记账通知")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true) // 设置为持续性通知
            .build()
        
        startForeground(FOREGROUND_NOTIFICATION_ID, notification)
        Log.d("NotificationListener", "Service started in foreground.")
    }

    override fun onDestroy() {
        stopForeground(true) // 停止前台服务
        Log.d("NotificationListener", "Service has been destroyed.")
        super.onDestroy()
    }
    
    // 为前台服务创建通知渠道
    private fun createForegroundNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                FOREGROUND_CHANNEL_ID,
                FOREGROUND_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW // 设置为低优先级，用户不会收到声音提醒
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
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

        // 2. 判断App状态 -> 修改为无条件发送，并额外判断是否需要系统通知
        // 永远、无条件地将数据发送到Flutter。
        // Flutter引擎可能会缓冲它，直到App返回前台。
        handler.post {
            Log.d("NotificationListener", "onNotificationPosted: sending to Flutter: $notificationData, eventSink=$eventSink")
            if (eventSink == null) {
                pendingNotificationQueue.add(notificationData)
                Log.d("NotificationListener", "onNotificationPosted: EventSink not ready, caching data. Queue size: ${pendingNotificationQueue.size}")
            } else {
                eventSink?.success(notificationData)
            }
        }

        // 如果App在后台，我们额外再显示一个系统通知作为备用。
        // 用户可以点击这个通知直接进入App，
        // 也可以忽略它，稍后手动打开App，数据同样会被处理。
        if (!isAppInForeground) {
            // App 在后台: 显示一个通用的系统通知
            Log.d("NotificationListener", "App in background. Showing generic system notification as a fallback.")
            showGenericBookkeepingNotification(notificationData)
        }
        Log.d("NotificationListener", "--- Notification Processed ---")
    }

    private fun showGenericBookkeepingNotification(originalData: Map<String, Any?>) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val sourceAppName = if (originalData["source"] == "com.eg.android.AlipayGphone") "支付宝" else "微信"

        val contentTitle = "有新的${sourceAppName}交易通知"
        val contentText = "点击查看并记账"

        // 创建一个意图：当用户点击通知时，打开我们的MainActivity
        val openAppIntent = Intent(applicationContext, MainActivity::class.java).apply {
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