package com.example.flutter_githubaction

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class NotificationListener : NotificationListenerService() {
    companion object {
        private const val EVENT_CHANNEL_NAME = "com.example.flutter_githubaction/notifications"
        private var eventSink: EventChannel.EventSink? = null

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
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName
        val notification = sbn.notification
        val extras = notification.extras

        // 仅处理微信和支付宝的通知 (示例包名)
        if (packageName in listOf("com.tencent.mm", "com.eg.android.AlipayGphone")) {
            val title = extras.getString(Notification.EXTRA_TITLE)
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()

            Log.i("NotificationListener", "Received notification: $title - $text")
            
            // TODO: 在这里添加解析逻辑，从 title 和 text 中提取金额、商户等信息

            val data = mapOf(
                "title" to title,
                "text" to text,
                "source" to packageName
            )
            
            // 将解析后的数据发送到Flutter端
            eventSink?.success(data)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        // 可选：在这里处理通知被移除的逻辑
    }
} 