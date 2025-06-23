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
import 'package:fl_chart/fl_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // 定义方法通道
  static const _methodChannel = MethodChannel('com.autobookkeeping.app/methods');

  final _notificationService = NotificationChannelService();
  final _parserService = NotificationParserService();
  final _debugLogService = DebugLogService();
  final _transactionService = TransactionService();
  
  Map<String, double> _monthlySummary = {'income': 0.0, 'expense': 0.0};
  List<tx_model.Transaction> _recentTransactions = [];
  StreamSubscription? _notificationSubscription;
  final Set<String> _processedNotifications = {}; // 用于防止重复处理
  AppLifecycleState? _appLifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLifecycleState = WidgetsBinding.instance.lifecycleState; // Get initial state
    _checkAndRequestPermissions();
    _loadData();
    _notificationService.initialize();
    _notificationSubscription =
        _notificationService.notificationStream.listen(_onNotificationReceived);
    // Restore the fallback mechanism to handle cases where the event stream
    // might be delayed on certain OSes during a cold start.
    _fetchPendingIntentNotification();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
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
      final bool isFromManualClick = notificationData['isFromManualClick'] as bool? ?? false;

      // 反重复机制
      final notificationSignature =
          "${notificationData['source']}-${notificationData['title']}-${notificationData['text']}";
      
      // Only check for duplicates if it's a new notification, not one from a manual click.
      if (!isFromManualClick && _processedNotifications.contains(notificationSignature)) {
        if (kDebugMode) {
          print("重复的通知，已忽略: $notificationSignature");
        }
        return;
      }
      _processedNotifications.add(notificationSignature);
      // 10秒后移除签名，防止内存无限增长
      Future.delayed(const Duration(seconds: 10), () {
        _processedNotifications.remove(notificationSignature);
      });
      
      await _debugLogService.addLog(notificationData);

      final parsedData = _parserService.parse(notificationData);
      if (parsedData != null && mounted) {
        // Core logic change: decide how to notify based on app state
        if (_appLifecycleState == AppLifecycleState.resumed) {
          // App is in foreground, show in-app dialog
          _showTransactionConfirmationDialog(parsedData);
        } else {
          // App is in background or inactive, request a native system notification
          try {
            await _methodChannel.invokeMethod('showBookkeepingNotification', {
              // Data for displaying the notification
              'amount': parsedData.amount,
              'merchant': parsedData.merchant,
              'type': parsedData.type == TransactionType.income ? '收入' : '支出',
              
              // IMPORTANT: Original data for the intent to re-parse later
              'source': parsedData.source,
              'title': notificationData['title'], // Pass original title
              'text': notificationData['text'],   // Pass original text
            });
          } catch (e) {
            if (kDebugMode) {
              print('Failed to show native notification: $e');
            }
          }
        }
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
        content: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: <TextSpan>[
              const TextSpan(text: '为了让App能自动捕获交易通知，需要您手动开启两个关键权限：\n\n'),
              TextSpan(
                text: '1. 通知使用权：',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '请在列表中找到并开启"记账助手"。\n\n'),
              TextSpan(
                text: '2. 后台弹出界面 (或悬浮窗)：',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '这是为了确保App在后台时，也能弹出记账提醒。这个选项通常在"权限管理"中，不同手机名称可能不同。\n'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('待会再说'),
          ),
          FilledButton(
            onPressed: () {
              // AppSettings.openAppSettings(type: AppSettingsType.notification) 
              // 只能精确跳转到"通知使用权"，为了引导用户开启其他权限，
              // 我们直接跳转到应用自身的设置页，让用户自己找。
              AppSettings.openAppSettings(type: AppSettingsType.settings);
              Navigator.of(context).pop();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  void _showTransactionConfirmationDialog(ParsedTransaction data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // 为了管理按钮状态，我们将内容提取到一个StatefulWidget中
        return _ConfirmationDialogContent(
          data: data,
          transactionService: _transactionService,
          onConfirm: () {
            _loadData(); // 记账成功后，刷新主页数据
            Navigator.of(context).pop(); // 关闭弹窗
          },
        );
      },
    );
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // Restore the method to fetch data from the fallback cache.
  Future<void> _fetchPendingIntentNotification() async {
    const methodChannel = MethodChannel('com.autobookkeeping.app/methods');
    try {
      final data = await methodChannel.invokeMethod('getPendingIntentNotification');
      if (data is Map && data['source'] != null) {
        // Use a small delay to ensure this is processed after any potential
        // race condition with the event channel. The anti-replay check
        // will prevent double processing.
        Future.delayed(const Duration(milliseconds: 100), () {
          _onNotificationReceived(Map<String, dynamic>.from(data));
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to fetch pending intent notification: $e');
      }
    }
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
            _ChartCard(summary: _monthlySummary),
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

class _ChartCard extends StatefulWidget {
  const _ChartCard({required this.summary});
  final Map<String, double> summary;

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final income = widget.summary['income'] ?? 0.0;
    final expense = widget.summary['expense'] ?? 0.0;
    final total = income + expense;
    final hasData = income > 0 || expense > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('收支构成', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: hasData
                  ? Row(
                      children: <Widget>[
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      touchedIndex = -1;
                                      return;
                                    }
                                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: showingSections(income, expense, total),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            _Indicator(color: Colors.green, text: '收入', isSquare: false),
                            SizedBox(height: 4),
                            _Indicator(color: Colors.red, text: '支出', isSquare: false),
                          ],
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        '暂无收支数据',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> showingSections(double income, double expense, double total) {
    return List.generate(2, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 18.0 : 14.0;
      final radius = isTouched ? 60.0 : 50.0;

      switch (i) {
        case 0: // Income
          return PieChartSectionData(
            color: Colors.green,
            value: income,
            title: '${(income / total * 100).toStringAsFixed(0)}%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        case 1: // Expense
          return PieChartSectionData(
            color: Colors.red,
            value: expense,
            title: '${(expense / total * 100).toStringAsFixed(0)}%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        default:
          throw Error();
      }
    });
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.color,
    required this.text,
    required this.isSquare,
    this.size = 16,
    this.textColor,
  });
  final Color color;
  final String text;
  final bool isSquare;
  final double size;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        )
      ],
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

class _ConfirmationDialogContent extends StatefulWidget {
  const _ConfirmationDialogContent({
    required this.data,
    required this.transactionService,
    required this.onConfirm,
  });

  final ParsedTransaction data;
  final TransactionService transactionService;
  final VoidCallback onConfirm;

  @override
  State<_ConfirmationDialogContent> createState() =>
      __ConfirmationDialogContentState();
}

class __ConfirmationDialogContentState
    extends State<_ConfirmationDialogContent> {
  bool _isSaving = false;

  Future<void> _handleConfirm() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.transactionService.addTransaction(widget.data);
      // 调用父widget传递的回调，这个回调会负责刷新UI和关闭弹窗
      widget.onConfirm();
    } catch (e) {
      if (kDebugMode) {
        print("保存交易失败: $e");
      }
      setState(() {
        _isSaving = false;
      });
      // 可以在这里显示一个错误提示
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = widget.data.type == TransactionType.expense;
    final amountColor = isExpense ? Colors.red : Colors.green;
    final amountPrefix = isExpense ? '-' : '+';

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('记录一笔新交易', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.price_change_outlined, '金额',
              '$amountPrefix ¥${widget.data.amount.toStringAsFixed(2)}', amountColor),
          _buildInfoRow(
              Icons.business_center_outlined, '类型', isExpense ? '支出' : '收入'),
          _buildInfoRow(Icons.store_mall_directory_outlined, '商户', widget.data.merchant),
          _buildInfoRow(Icons.apps_outlined, '来源', widget.data.source),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isSaving ? '保存中...' : '确认记账'),
                onPressed: _handleConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, [Color? valueColor]) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: theme.textTheme.bodySmall?.color, size: 20),
          const SizedBox(width: 16),
          Text(label, style: theme.textTheme.bodyLarge),
          const Spacer(),
          Text(value, style: theme.textTheme.bodyLarge?.copyWith(color: valueColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
} 