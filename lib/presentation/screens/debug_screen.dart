import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/debug_log_service.dart';
import '../../services/notification_channel_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  static const _methodChannel = MethodChannel('com.autobookkeeping.app/methods');
  final _debugLogService = DebugLogService();
  final _notificationChannelService = NotificationChannelService();

  List<Map<String, dynamic>> _appLogs = [];
  String _logcatOutput = 'Tap refresh to load logcat...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshAllLogs();
  }

  Future<void> _fetchAppLogs() async {
    setState(() {
      _appLogs = _debugLogService.getLogs();
    });
  }

  Future<void> _fetchLogcat() async {
    try {
      final String logs = await _methodChannel.invokeMethod('getLogcat');
      if (mounted) {
        setState(() {
          _logcatOutput = logs;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logcatOutput = 'Failed to fetch logcat: $e';
        });
      }
    }
  }

  Future<void> _refreshAllLogs() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchAppLogs(),
      _fetchLogcat(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _clearAllLogs() {
    _debugLogService.clearLogs();
    setState(() {
      _appLogs = [];
      _logcatOutput = 'Logs cleared. Tap refresh to reload.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('调试日志'),
          actions: [
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Logs',
                onPressed: _refreshAllLogs,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear Logs',
              onPressed: _clearAllLogs,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'App 事件日志'),
              Tab(text: '系统 Logcat'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showSimulationDialog,
          tooltip: '模拟通知',
          child: const Icon(Icons.add_comment),
        ),
        body: TabBarView(
          children: [
            _buildAppLogView(),
            _buildLogcatView(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppLogView() {
    if (_appLogs.isEmpty) {
      return const Center(child: Text('没有App事件日志'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _appLogs.length,
      itemBuilder: (context, index) {
        final log = _appLogs[index];
        final timestamp = log['timestamp'] as DateTime?;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (timestamp != null)
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                const SizedBox(height: 4),
                SelectableText(
                  'Source: ${log['source']}\nTitle: ${log['title']}\nText: ${log['text']}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogcatView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: SelectableText(
        _logcatOutput,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }

  void _showSimulationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _SimulationDialog(
          onSimulate: (Map<String, dynamic> fakeNotification) {
            _notificationChannelService.sendMockNotification(fakeNotification);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('模拟通知已发送，请返回首页查看弹窗'),
                backgroundColor: Colors.blue,
              ),
            );
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _refreshAllLogs();
              }
            });
          },
        );
      },
    );
  }
}

class _SimulationDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSimulate;
  const _SimulationDialog({required this.onSimulate});

  @override
  State<_SimulationDialog> createState() => _SimulationDialogState();
}

class _SimulationDialogState extends State<_SimulationDialog> {
  final _amountController = TextEditingController(text: '0.01');
  final _merchantController = TextEditingController(text: '示例商家');

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