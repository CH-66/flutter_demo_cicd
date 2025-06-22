import 'package:flutter/material.dart';
import '../../services/debug_log_service.dart';
import '../../services/notification_channel_service.dart';
import 'package:intl/intl.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final DebugLogService _logService = DebugLogService();
  final NotificationChannelService _notificationChannelService = NotificationChannelService();
  late Future<List<DebugLog>> _logsFuture;

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
            return Center(child: Text('加载日志失败: ${snapshot.error}'));
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
                      '来源: ${log.source}',
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