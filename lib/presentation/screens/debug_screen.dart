import 'package:flutter/material.dart';
import 'package:flutter_demo/services/debug_log_service.dart';
import 'package:intl/intl.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final DebugLogService _logService = DebugLogService();
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
} 