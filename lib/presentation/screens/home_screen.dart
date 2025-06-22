import 'dart:async';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart' as tx_model;
import '../models/transaction_data.dart';
import '../services/notification_parser_service.dart';
import '../services/debug_log_service.dart';
import '../services/transaction_service.dart';
import 'debug_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _notificationChannel = EventChannel('com.example.flutter_githubaction/notifications');
  StreamSubscription? _notificationSubscription;
  final _parserService = NotificationParserService();
  final _debugLogService = DebugLogService();
  final _transactionService = TransactionService();
  
  Map<String, double> _monthlySummary = {'income': 0.0, 'expense': 0.0};
  List<tx_model.Transaction> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    // 延迟一帧后执行，确保 BuildContext 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionAndStartListening();
    });
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

  Future<void> _checkPermissionAndStartListening() async {
    // 立即开始监听，即使用户稍后才去授权，我们也不会错过。
    _startListeningToNotifications();

    final prefs = await SharedPreferences.getInstance();
    final hasSeenGuide = prefs.getBool('has_seen_notification_guide') ?? false;

    if (!hasSeenGuide) {
      // 只有在用户没看过引导时才显示对话框
      _showNotificationAccessGuideDialog();
    }
  }

  void _startListeningToNotifications() {
    _notificationSubscription = _notificationChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is Map) {
          // 首先，无条件保存所有通知到调试数据库
          _debugLogService.addLog(data);

          // 然后，尝试解析
          final parsedData = _parserService.parse(data);
          if (parsedData != null) {
            _showTransactionConfirmationDialog(parsedData);
          }
        }
      },
      onError: (dynamic error) {
        if (kDebugMode) {
          print('Received error: ${error.message}');
        }
      },
      cancelOnError: false,
    );
  }

  Future<void> _showNotificationAccessGuideDialog() async {
    // 在显示对话框之前，先记录下"已经看过"
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_notification_guide', true);

    showDialog(
      context: context,
      barrierDismissible: false, // 用户必须通过按钮交互
      builder: (context) => AlertDialog(
        title: const Text('启用自动记账功能'),
        content: const Text('为了自动识别支付信息，App需要您在系统设置中手动开启【通知使用权】。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () {
              // 直接跳转到"通知使用权"设置页面
              AppSettings.openAppSettings(type: AppSettingsType.notification);
              Navigator.of(context).pop();
            },
            child: const Text('去开启'),
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
                      _loadData(); // 保存后刷新数据
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
            onPressed: () {},
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