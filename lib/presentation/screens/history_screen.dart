import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史账单'),
      ),
      body: const Center(
        child: Text('这里是历史账单页面'),
      ),
    );
  }
} 