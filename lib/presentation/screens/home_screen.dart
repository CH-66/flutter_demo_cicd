import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _notificationChannel = EventChannel('com.example.flutter_githubaction/notifications');
  StreamSubscription? _notificationSubscription;
  
  final List<Map<dynamic, dynamic>> _debugNotifications = [];

  @override
  void initState() {
    super.initState();
    _requestPermissionAndStartListening();
  }

  Future<void> _requestPermissionAndStartListening() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      _startListeningToNotifications();
    } else {
      _showPermissionDeniedDialog();
    }
  }

  void _startListeningToNotifications() {
    _notificationSubscription = _notificationChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is Map) {
          setState(() {
            _debugNotifications.insert(0, data);
          });
          _showTransactionConfirmationDialog(data);
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

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要权限'),
        content: const Text('应用需要访问通知的权限才能自动记账。请在系统设置中开启。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  void _showTransactionConfirmationDialog(Map<dynamic, dynamic> data) {
    // TODO: 解析 'title' 和 'text' 来提取真实数据
    final title = data['title']?.toString() ?? '未知商家';
    final text = data['text']?.toString() ?? '未知金额';

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
              Text('发现一笔新交易', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('需要记账吗？', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              Center(child: Text(text, style: Theme.of(context).textTheme.displaySmall)),
              const SizedBox(height: 16),
              Center(child: Text(title, style: Theme.of(context).textTheme.bodyLarge)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('忽略')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: () { /* TODO: Save transaction */ Navigator.of(context).pop(); }, child: const Text('确认记账')),
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
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
        backgroundColor: theme.colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (kDebugMode) _DebugCard(notifications: _debugNotifications),
          const _SummaryCard(),
          const SizedBox(height: 16),
          const _ChartCard(),
          const SizedBox(height: 16),
          const _TransactionsCard(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DebugCard extends StatelessWidget {
  const _DebugCard({required this.notifications});
  final List<Map<dynamic, dynamic>> notifications;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      color: Colors.yellow.shade100,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Debug: 接收到的原始通知', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Source: ${notification['source']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("Title: ${notification['title']}"),
                    Text("Text: ${notification['text']}"),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

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
              amount: '1,234.56',
              color: theme.colorScheme.onPrimaryContainer,
            ),
            _SummaryItem(
              title: '本月收入',
              amount: '5,000.00',
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
  const _TransactionsCard();

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
              Text('最近交易', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              _TransactionItem(
                icon: Icons.restaurant,
                color: Colors.orange.shade100,
                title: '美团外卖',
                subtitle: '今天 12:30',
                amount: '- ¥ 25.50',
              ),
              const Divider(),
              _TransactionItem(
                icon: Icons.shopping_cart,
                color: Colors.blue.shade100,
                title: '淘宝购物',
                subtitle: '昨天 20:45',
                amount: '- ¥ 188.00',
              ),
              const Divider(),
              _TransactionItem(
                icon: Icons.commute,
                color: Colors.green.shade100,
                title: '滴滴出行',
                subtitle: '2天前',
                amount: '- ¥ 32.10',
              ),
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
          Text(amount, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
} 