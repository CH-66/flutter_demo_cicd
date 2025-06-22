package com.example.flutter_githubaction

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 将Flutter引擎的通信能力注册给NotificationListener的静态方法
        NotificationListener.configure(flutterEngine)
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
