import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'presentation/screens/main_shell.dart';

void main() async {
  // 确保Flutter绑定已经初始化
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化中文日期格式化支持
  await initializeDateFormatting('zh_CN', null);
  
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
