import 'package:flutter/material.dart';
import '../../services/debug_log_service.dart';
import '../../services/notification_channel_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final DebugLogService _logService = DebugLogService();
  final NotificationChannelService _notificationChannelService = NotificationChannelService();
  late Future<List<DebugLog>> _logsFuture;

  // logcat内容和悬浮窗控制
  String? _logcatContent;
  OverlayEntry? _logcatOverlay;
  Timer? _logcatTimer;
  bool _logcatAutoRefresh = false;

  @override
  void initState() {
    super.initState();
    _logsFuture = _logService.getAllLogs();
  }

  void _refreshLogs() {
    setState(() {
      _logsFuture = _logService.getAllLogs();
    });
  }

  // 获取logcat并显示悬浮窗
  Future<void> _fetchLogcat({bool auto = false}) async {
    const methodChannel = MethodChannel('com.example.flutter_githubaction/methods');
    try {
      final logs = await methodChannel.invokeMethod<String>('getLogcat');
      _showLogcatOverlay(logs ?? '无日志', auto: auto);
    } catch (e) {
      _showLogcatOverlay('获取logcat失败: $e', auto: auto);
    }
  }

  void _showLogcatOverlay(String content, {bool auto = false}) {
    _logcatContent = content;
    _logcatOverlay?.remove();
    _logcatAutoRefresh = auto;
    if (_logcatAutoRefresh) {
      _logcatTimer?.cancel();
      _logcatTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchLogcat(auto: true));
    } else {
      _logcatTimer?.cancel();
    }
    _logcatOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        right: 10,
        left: 10,
        child: Material(
          color: Colors.transparent,
          child: Container(
            height: 360,
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.97),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Column(
              children: [
                // 标题栏
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                    color: Colors.black,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bug_report, color: Colors.greenAccent, size: 18),
                      const SizedBox(width: 6),
                      const Text('Logcat日志', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _logcatContent ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制全部日志')));
                        },
                        child: const Text('复制全部', style: TextStyle(color: Colors.greenAccent)),
                      ),
                      if (_logcatAutoRefresh)
                        TextButton(
                          onPressed: () {
                            _logcatAutoRefresh = false;
                            _logcatTimer?.cancel();
                            _showLogcatOverlay(_logcatContent ?? '', auto: false);
                          },
                          child: const Text('停止刷新', style: TextStyle(color: Colors.orangeAccent)),
                        )
                      else
                        TextButton(
                          onPressed: () {
                            _fetchLogcat(auto: true);
                          },
                          child: const Text('自动刷新', style: TextStyle(color: Colors.greenAccent)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          _logcatTimer?.cancel();
                          _logcatOverlay?.remove();
                        },
                        tooltip: '关闭',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.greenAccent),
                // 日志内容区
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        controller: _autoScrollController,
                        child: SelectableText(
                          _logcatContent ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.greenAccent, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true)?.insert(_logcatOverlay!);
    // 自动滚动到底部
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_autoScrollController.hasClients) {
        _autoScrollController.jumpTo(_autoScrollController.position.maxScrollExtent);
      }
    });
  }

  final ScrollController _autoScrollController = ScrollController();

  @override
  void dispose() {
    _logcatOverlay?.remove();
    _logcatTimer?.cancel();
    _autoScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _fetchLogcat(auto: false),
            tooltip: '获取Logcat',
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill),
            onPressed: () => _fetchLogcat(auto: true),
            tooltip: '实时Logcat',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSimulationDialog,
        tooltip: '模拟通知',
        child: const Icon(Icons.add_comment),
      ),
      body: FutureBuilder<List<DebugLog>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('加载日志失败: \\${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('暂无通知日志'));
          }

          final logs = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(8.0),
            itemCount: logs.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                title: Text(log.title ?? '无标题', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.text ?? '无内容'),
                    const SizedBox(height: 4),
                    Text(
                      '来源: \\${log.source}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }

  void _showSimulationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _SimulationDialog(
          onSimulate: (Map<String, dynamic> fakeNotification) {
            // 1. 通过服务发送模拟通知，触发全局监听
            _notificationChannelService.sendMockNotification(fakeNotification);

            // 2. 给用户一个清晰的反馈
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('模拟通知已发送，请返回首页查看弹窗'),
                backgroundColor: Colors.blue,
              ),
            );

            // 3. 延迟刷新日志列表，以确保HomeScreen有时间处理和保存新日志
            Future.delayed(const Duration(milliseconds: 500), () {
              if(mounted) {
                _refreshLogs();
              }
            });
          },
        );
      },
    );
  }
}

// 模拟器对话框的UI和逻辑
class _SimulationDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSimulate;
  const _SimulationDialog({required this.onSimulate});

  @override
  State<_SimulationDialog> createState() => _SimulationDialogState();
}

class _SimulationDialogState extends State<_SimulationDialog> {
  final _amountController = TextEditingController(text: '0.01');
  final _merchantController = TextEditingController(text: '示例商家');

  // 定义模板
  final Map<String, String> _templates = {
    'alipay_expense': '你向{merchant}付款{amount}元',
    'alipay_income': '支付宝成功收款{amount}元。',
    'wechat_expense': '向{merchant}成功付款{amount}元',
    'wechat_income': '微信支付收款{amount}元(朋友到店)',
  };

  late String _selectedTemplateKey;

  @override
  void initState() {
    super.initState();
    _selectedTemplateKey = _templates.keys.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('通知模拟器'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedTemplateKey,
              items: _templates.keys.map((key) {
                return DropdownMenuItem(
                  value: key,
                  child: Text(key),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedTemplateKey = value;
                  });
                }
              },
              decoration: const InputDecoration(labelText: '选择模板'),
            ),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: '金额'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextFormField(
              controller: _merchantController,
              decoration: const InputDecoration(labelText: '商家/对方'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _handleSimulate,
          child: const Text('生成并测试'),
        ),
      ],
    );
  }

  void _handleSimulate() {
    final template = _templates[_selectedTemplateKey]!;
    final amount = _amountController.text;
    final merchant = _merchantController.text;

    final text = template
        .replaceAll('{amount}', amount)
        .replaceAll('{merchant}', merchant);
    
    String source = '';
    String title = '';
    if (_selectedTemplateKey.startsWith('alipay')) {
      source = 'com.eg.android.AlipayGphone';
      title = _selectedTemplateKey.contains('income') ? '支付宝通知' : '';
    } else {
      source = 'com.tencent.mm';
      title = _selectedTemplateKey.contains('income') ? '微信支付' : '';
    }

    final fakeNotification = {
      'source': source,
      'title': title,
      'text': text,
    };

    widget.onSimulate(fakeNotification);
    Navigator.of(context).pop();
  }
} 