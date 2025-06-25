import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';
import 'health_check_screen.dart';
import 'category_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _methodChannel = MethodChannel('com.autobookkeeping.app/methods');
  bool _isListenerEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    setState(() => _isLoading = true);
    try {
      final bool isEnabled = await _methodChannel.invokeMethod('isNotificationListenerEnabled');
      if (mounted) {
        setState(() {
          _isListenerEnabled = isEnabled;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查权限失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _runFix() async {
    try {
      await _methodChannel.invokeMethod('ensureNotificationListenerEnabled');
      // 稍作延时，给系统反应时间
      await Future.delayed(const Duration(milliseconds: 500));
      // 修复后重新检查状态
      await _checkPermissionStatus();

      if (mounted && _isListenerEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('修复成功！服务已启用。'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('修复未成功，请尝试手动设置并重启App。'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('调用修复失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkPermissionStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSettingsList(context),
    );
  }

  ListView _buildSettingsList(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        ListTile(
          leading: Icon(
            Icons.notifications_active,
            color: _isListenerEnabled ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
          title: const Text('通知监听服务状态'),
          subtitle: Text(
            _isListenerEnabled ? '运行中' : '已禁用或未启动',
            style: TextStyle(
              color: _isListenerEnabled ? theme.colorScheme.primary : theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () => AppSettings.openAppSettings(type: AppSettingsType.notification),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.build_circle_outlined),
          title: const Text('手动修复服务'),
          subtitle: const Text('如果服务状态不正确，可尝试此操作'),
          onTap: _runFix,
        ),
        ListTile(
          leading: const Icon(Icons.open_in_new),
          title: const Text('跳转到系统权限页面'),
          subtitle: const Text('手动开启或关闭通知读取权限'),
          onTap: () {
            AppSettings.openAppSettings(type: AppSettingsType.notification);
          },
        ),
        const SettingsHeader(title: '通用'),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text('账单分类管理'),
          subtitle: const Text('增删改查你的账单分类'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.health_and_safety_outlined),
          title: const Text('权限健康检查'),
          subtitle: const Text('检查App核心功能所需的权限是否正常'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HealthCheckScreen()),
            ).then((_) => _checkPermissionStatus()); // Re-check after returning
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications_on_outlined),
          title: const Text('通知设置'),
          subtitle: const Text('管理App的通知渠道和声音'),
          onTap: () {
            AppSettings.openAppSettings(type: AppSettingsType.notification);
          },
        ),
        ListTile(
          leading: const Icon(Icons.security_outlined),
          title: const Text('隐私政策'),
          onTap: () {
            // TODO: Implement privacy policy screen
          },
        ),
      ],
    );
  }
}

class SettingsHeader extends StatelessWidget {
  final String title;
  const SettingsHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
} 