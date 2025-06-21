import 'package:flutter/material.dart';
import 'package:flutter_demo/presentation/screens/main_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '自动记账App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        useMaterial3: true,
        fontFamily: 'Noto Sans SC',
      ),
      home: const MainShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
