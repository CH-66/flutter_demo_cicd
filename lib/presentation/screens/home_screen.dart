import 'dart:async';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/transaction.dart' as tx_model;
import '../../models/transaction_data.dart';
import '../../services/notification_parser_service.dart';
import '../../services/debug_log_service.dart';
import '../../services/transaction_service.dart';
import '../../services/notification_channel_service.dart';
import 'debug_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 定义方法通道
  static const _methodChannel = MethodChannel('com.example.flutter_githubaction/methods');

  final _notificationService = NotificationChannelService();
  final _parserService = NotificationParserService();
  final _debugLogService = DebugLogService();
  final _transactionService = TransactionService();
  
  Map<String, double> _monthlySummary = {'income': 0.0, 'expense': 0.0};
  List<tx_model.Transaction> _recentTransactions = [];
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
    _loadData();
    _notificationService.initialize();
    _notificationSubscription =
        _notificationService.notificationStream.listen(_onNotificationReceived);
  }

  Future<void> _loadData() async {
    final summary = await _transactionService.getMonthlySummary();
    final transactions = await _transactionService.getRecentTransactions();
    if (mounted) {
      setState(() {
        _monthlySummary = summary;
        _recentTransactions = transactions;
      });
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    // 1. 请求常规通知权限
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    final prefs = await SharedPreferences.getInstance();
    final hasSeenGuide = prefs.getBool('has_seen_notification_guide') ?? false;

    // 2. 通过我们自己的方法通道检查特殊权限
    bool isListenerEnabled = false;
    try {
      isListenerEnabled = await _methodChannel.invokeMethod('isNotificationListenerEnabled');
    } catch (e) {
      if (kDebugMode) {
        print("检查通知监听权限失败: $e");
      }
    }
    
    // 3. 仅在没看过引导且权限未开启时，才显示引导对话框
    if (!hasSeenGuide && !isListenerEnabled) {
      _showNotificationAccessGuideDialog();
    }
  }

  void _onNotificationReceived(dynamic data) async {
    if (data is Map<dynamic, dynamic>) {
      final notificationData = data.cast<String, dynamic>();
      await _debugLogService.addLog(notificationData);

      final parsedData = _parserService.parse(notificationData);
      if (parsedData != null && mounted) {
        _showTransactionConfirmationDialog(parsedData);
      }
    }
  }

  Future<void> _showNotificationAccessGuideDialog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_notification_guide', true);
  
    // 再次检查权限状态，提供更精准的引导
    bool isListenerEnabled = false;
    try {
      isListenerEnabled = await _methodChannel.invokeMethod('isNotificationListenerEnabled');
    } catch (e) {
      // quiet fail
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('启用自动记账功能'),
        content: Text(isListenerEnabled
            ? '太棒了！自动记账功能已准备就绪。'
            : '请在接下来的系统设置页面中，找到并开启"flutter_githubaction"的权限。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('待会再说'),
          ),
          FilledButton(
            onPressed: () {
              // 直接跳转到"通知使用权"设置页面
              AppSettings.openAppSettings(type: AppSettingsType.notification);
              Navigator.of(context).pop();
            },
            child: Text(isListenerEnabled ? '完成' : '去设置'),
          ),
        ],
      ),
    );
  }

  void _showTransactionConfirmationDialog(ParsedTransaction data) {
    final amountString = '¥ ${data.amount.toStringAsFixed(2)}';
    final title = data.merchant;
    final typeText = data.type == TransactionType.expense ? '支出' : '收入';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('发现一笔新交易 ($typeText)', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('来源: ${data.source}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              Center(child: Text(amountString, style: Theme.of(context).textTheme.displaySmall)),
              const SizedBox(height: 16),
              Center(child: Text(title, style: Theme.of(context).textTheme.bodyLarge)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('忽略')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await _transactionService.addTransactionFromParsedData(data);
                      Navigator.of(context).pop();
                      _loadData();
                    },
                    child: const Text('确认记账'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
  
  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: const Text('我的账本', style: TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.red),
            tooltip: '调试日志',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebugScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
        backgroundColor: theme.colorScheme.surface,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _SummaryCard(summary: _monthlySummary),
            const SizedBox(height: 16),
            const _ChartCard(),
            const SizedBox(height: 16),
            _TransactionsCard(transactions: _recentTransactions),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final Map<String, double> summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryItem(
              title: '本月支出',
              amount: summary['expense']!.toStringAsFixed(2),
              color: theme.colorScheme.onPrimaryContainer,
            ),
            _SummaryItem(
              title: '本月收入',
              amount: summary['income']!.toStringAsFixed(2),
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.title,
    required this.amount,
    required this.color,
  });

  final String title;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 14, color: color)),
        const SizedBox(height: 4),
        Text('¥ $amount', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('支出分类', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('（此处为支出分类图表）'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.transactions});
  final List<tx_model.Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (transactions.isEmpty) {
      return Card(
        color: theme.colorScheme.surfaceVariant,
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('暂无交易记录')),
        ),
      );
    }

    return Card(
       color: theme.colorScheme.surfaceVariant,
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Text('最近交易', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  return _TransactionItem(
                    icon: tx.type == TransactionType.expense ? Icons.arrow_downward : Icons.arrow_upward,
                    color: tx.type == TransactionType.expense ? Colors.red.shade100 : Colors.green.shade100,
                    title: tx.merchant,
                    subtitle: DateFormat('MM-dd HH:mm').format(tx.timestamp),
                    amount: '${tx.type == TransactionType.expense ? '-' : '+'} ¥ ${tx.amount.toStringAsFixed(2)}',
                  );
                },
              )
           ],
         ),
       ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  const _TransactionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Icon(icon, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            amount,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white.withOpacity(0.87),
            )
          ),
        ],
      ),
    );
  }
} 