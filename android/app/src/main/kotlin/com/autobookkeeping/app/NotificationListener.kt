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
        private const val EVENT_CHANNEL_NAME = "com.autobookkeeping.app/notifications"
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

    override fun onCreate() {
        super.onCreate()
        // 必须先创建渠道，再创建通知
        createForegroundNotificationChannel()

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

        // 2. 判断App状态 -> 修改为无条件发送，不再自己创建系统通知
        // 永远、无条件地将数据发送到Flutter。
        sendData(notificationData)

        Log.d("NotificationListener", "--- Notification Processed ---")
    }
} 