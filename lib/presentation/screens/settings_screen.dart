import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';

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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final isEnabled = await _methodChannel.invokeMethod('isNotificationListenerEnabled');
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
        setState(() {
          _isLoading = false;
        });
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: RefreshIndicator(
        onRefresh: _checkPermissionStatus,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
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
                      )
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _checkPermissionStatus,
                      tooltip: '刷新状态',
                    ),
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
                ],
              ),
      ),
    );
  }
} 