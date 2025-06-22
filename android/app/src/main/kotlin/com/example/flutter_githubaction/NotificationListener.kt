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

    // 内部数据类，用于存放原生解析结果
    private data class ParsedTransaction(
        val type: String, // "income" 或 "expense"
        val amount: Double,
        val merchant: String,
        val source: String
    )

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

        // 2. 无论如何，都将原始数据发往Flutter端，用于调试日志记录
        // 我们不再加[诊断]前缀，因为现在有更详细的Logcat日志
        handler.post {
            eventSink?.success(notificationData)
        }

        // 3. 尝试在原生端解析通知
        val parsedResult = parseNotification(text ?: "", packageName)

        // 4. 如果原生端解析成功，则发出我们自己的记账提醒通知
        if (parsedResult != null) {
            Log.d("NotificationListener", "Result: Parsed successfully. Showing bookkeeping notification.")
            showBookkeepingNotification(parsedResult, notificationData)
        } else {
            Log.d("NotificationListener", "Result: Failed to parse.")
        }
        Log.d("NotificationListener", "--- Notification Processed ---")
    }

    private fun parseNotification(text: String, sourcePackage: String): ParsedTransaction? {
        Log.d("NotificationListener", "Parsing text: '$text' from package: $sourcePackage")
        val source = if (sourcePackage.contains("alipay")) "alipay" else "wechat"
        
        val patterns = mapOf(
            Regex("""你向(.+?)付款([\d.]+)元""") to { result: MatchResult ->
                Log.d("NotificationListener", "Matched: Alipay Expense (Pattern 1)")
                ParsedTransaction("expense", result.groupValues[2].toDouble(), result.groupValues[1], source)
            },
            Regex("""你有一笔([\d.]+)元的支出""") to { result: MatchResult ->
                Log.d("NotificationListener", "Matched: Alipay Expense (Pattern 2)")
                ParsedTransaction("expense", result.groupValues[1].toDouble(), "支付宝", source)
            },
            Regex("""成功收款([\d.]+)元""") to { result: MatchResult -> // 更通用的收款格式
                Log.d("NotificationListener", "Matched: Income (Generic)")
                val merchant = if (source == "alipay") "支付宝收款" else "微信支付"
                ParsedTransaction("income", result.groupValues[1].toDouble(), merchant, source)
            },
            Regex("""向(.+?)成功付款([\d.]+)元""") to { result: MatchResult ->
                Log.d("NotificationListener", "Matched: WeChat Expense (Pattern 1)")
                ParsedTransaction("expense", result.groupValues[2].toDouble(), result.groupValues[1], source)
            },
            Regex("""微信支付收款([\d.]+)元""") to { result: MatchResult ->
                 Log.d("NotificationListener", "Matched: WeChat Income (Pattern 1)")
                ParsedTransaction("income", result.groupValues[1].toDouble(), "微信支付", source)
            }
        )

        for ((pattern, parser) in patterns) {
            pattern.find(text)?.let {
                try {
                    return parser(it)
                } catch (e: Exception) {
                    Log.e("NotificationListener", "Error parsing with pattern: $pattern", e)
                    return null 
                }
            }
        }
        Log.d("NotificationListener", "No patterns matched.")
        return null
    }

    private fun showBookkeepingNotification(parsed: ParsedTransaction, originalData: Map<String, Any?>) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val typeText = if (parsed.type == "expense") "支出" else "收入"
        val contentTitle = "新的${typeText}记账提醒"
        val contentText = "从 ${parsed.source} 识别到一笔${parsed.amount}元的${typeText}，需要记录吗？"

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
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(openAppPendingIntent) // 设置点击行为
            .setAutoCancel(true) // 用户点击后自动移除通知
            .setTimeoutAfter(5 * 60 * 1000) // 5分钟后自动消失

        // 发送通知
        notificationManager.notify(notificationIdCounter++, notificationBuilder.build())
    }
} 