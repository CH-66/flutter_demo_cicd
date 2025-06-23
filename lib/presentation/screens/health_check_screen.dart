import 'dart:async';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

// An enum to represent the status of a health check item
enum HealthStatus { ok, warning, error, loading }

// A data class to hold all information for a health check item
class HealthCheckItem {
  final String title;
  final String description;
  final Future<HealthStatus> Function() check;
  final Future<void> Function() action;
  HealthStatus status;

  HealthCheckItem({
    required this.title,
    required this.description,
    required this.check,
    required this.action,
    this.status = HealthStatus.loading,
  });
}

class HealthCheckScreen extends StatefulWidget {
  final bool isFirstLaunch;
  const HealthCheckScreen({super.key, this.isFirstLaunch = false});

  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen> {
  static const _methodChannel = MethodChannel('com.autobookkeeping.app/methods');
  static const String bookkeepingChannelId = 'intelligent_bookkeeping_alerts';

  late final List<HealthCheckItem> _checkItems;

  @override
  void initState() {
    super.initState();
    _checkItems = [
      HealthCheckItem(
        title: '系统通知总开关',
        description: '这是接收所有通知的基础，必须开启。',
        check: _checkSystemNotificationPermission,
        action: () => AppSettings.openAppSettings(type: AppSettingsType.notification),
      ),
      HealthCheckItem(
        title: '通知读取权',
        description: '用于捕获支付宝和微信的交易通知，是实现自动记账的核心。',
        check: _checkNotificationListenerPermission,
        action: () => AppSettings.openAppSettings(type: AppSettingsType.notification),
      ),
      HealthCheckItem(
        title: '记账提醒横幅',
        description: '捕获到交易后，App需要此权限以横幅形式弹出记账提醒，否则通知将是静默的。',
        check: _checkBannerPermission,
        action: _openBookkeepingChannelSettings,
      ),
    ];
    _runChecks();
  }

  Future<void> _runChecks() async {
    for (final item in _checkItems) {
      final status = await item.check();
      if (mounted) {
        setState(() {
          item.status = status;
        });
      }
    }
  }

  Future<HealthStatus> _checkSystemNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted ? HealthStatus.ok : HealthStatus.error;
  }

  Future<HealthStatus> _checkNotificationListenerPermission() async {
    try {
      final bool isEnabled = await _methodChannel.invokeMethod('isNotificationListenerEnabled');
      return isEnabled ? HealthStatus.ok : HealthStatus.error;
    } catch (e) {
      return HealthStatus.error;
    }
  }

  Future<HealthStatus> _checkBannerPermission() async {
    try {
      // IMPORTANCE_HIGH is 4. Anything less means the banner is likely disabled.
      final int importance = await _methodChannel.invokeMethod('getNotificationChannelImportance', {'channelId': bookkeepingChannelId});
      return importance >= 4 ? HealthStatus.ok : HealthStatus.warning;
    } catch (e) {
      return HealthStatus.error;
    }
  }

  Future<void> _openBookkeepingChannelSettings() async {
    await _methodChannel.invokeMethod('openNotificationChannelSettings', {'channelId': bookkeepingChannelId});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('权限健康检查'),
        automaticallyImplyLeading: !widget.isFirstLaunch, // Hide back button on first launch
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _checkItems.length,
        itemBuilder: (context, index) {
          final item = _checkItems[index];
          return _buildHealthItem(item);
        },
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      ),
      bottomNavigationBar: widget.isFirstLaunch ? _buildFirstLaunchBottomBar() : null,
    );
  }

  Widget _buildHealthItem(HealthCheckItem item) {
    Icon icon;
    Color color;
    String statusText;

    switch (item.status) {
      case HealthStatus.loading:
        icon = const Icon(Icons.hourglass_empty, color: Colors.grey);
        color = Colors.grey.shade300;
        statusText = '检查中...';
        break;
      case HealthStatus.ok:
        icon = const Icon(Icons.check_circle, color: Colors.green);
        color = Colors.green.shade100;
        statusText = '已开启';
        break;
      case HealthStatus.warning:
        icon = const Icon(Icons.warning, color: Colors.orange);
        color = Colors.orange.shade100;
        statusText = '建议开启';
        break;
      case HealthStatus.error:
        icon = const Icon(Icons.error, color: Colors.red);
        color = Colors.red.shade100;
        statusText = '必须开启';
        break;
    }

    return Card(
      color: color,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                ),
                Text(statusText, style: TextStyle(color: icon.color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.description, style: Theme.of(context).textTheme.bodyMedium),
            if (item.status != HealthStatus.ok && item.status != HealthStatus.loading) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () async {
                    await item.action();
                    // After returning from settings, re-check everything.
                    if (mounted) {
                      setState(() {
                         for (var i in _checkItems) {
                          i.status = HealthStatus.loading;
                        }
                      });
                      _runChecks();
                    }
                  },
                  child: const Text('前往设置'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFirstLaunchBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '请确保所有关键项都显示为"已开启"，否则App可能无法正常工作。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                // Here you would typically save that the onboarding is complete
                Navigator.of(context).pop();
              },
              child: const Text('完成并开始使用'),
            ),
          ),
        ],
      ),
    );
  }
} 