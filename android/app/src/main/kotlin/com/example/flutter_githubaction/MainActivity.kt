package com.example.flutter_githubaction

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 建立原生代码与Flutter的通信渠道
        NotificationListener.configure(flutterEngine)
    }
}
