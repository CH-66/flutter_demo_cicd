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

        val title = extras.getString(Notification.EXTRA_TITLE)
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()

        Log.i("NotificationListener", "Received notification from $packageName: $title - $text")
        
        val data = mapOf(
            "source" to packageName,
            "title" to title,
            "text" to text
        )
        
        // 将所有解析后的数据发送到Flutter端
        eventSink?.success(data)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        // 可选：在这里处理通知被移除的逻辑
    }
} 