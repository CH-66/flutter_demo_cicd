import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package.intl/intl.dart';
import '../../services/debug_log_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  static const _methodChannel = MethodChannel('com.autobookkeeping.app/methods');
  final _debugLogService = DebugLogService();

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
} 