import 'dart:async';
import 'package:flutter/services.dart';

/// 一个单例服务，用于管理与原生代码通信的EventChannel。
/// 这确保了应用的多个部分可以监听同一个通知流，
/// 并且可以从Dart代码中模拟通知事件。
class NotificationChannelService {
  // 私有构造函数
  NotificationChannelService._privateConstructor();

  // 单例实例
  static final NotificationChannelService _instance =
      NotificationChannelService._privateConstructor();

  // 获取单例实例的工厂构造函数
  factory NotificationChannelService() {
    return _instance;
  }

  // EventChannel
  static const _eventChannel =
      EventChannel('com.example.flutter_githubaction/notifications');

  // StreamController，用于合并真实通知和模拟通知
  final _notificationController = StreamController<dynamic>.broadcast();

  // 用于外部监听的Stream
  Stream<dynamic> get notificationStream => _notificationController.stream;

  bool _isInitialized = false;

  /// 初始化服务，开始监听来自原生代码的真实通知。
  /// 这个方法应该只被调用一次。
  void initialize() {
    if (_isInitialized) {
      print('[NotificationChannelService] initialize() called but already initialized.');
      return;
    }
    print('[NotificationChannelService] Initializing EventChannel...');
    _eventChannel.receiveBroadcastStream().listen(
      (data) {
        print('[NotificationChannelService] Received data from native: $data');
        // 当收到真实通知时，将其添加到流中
        _notificationController.add(data);
      },
      onError: (error) {
        print('[NotificationChannelService] Error receiving notification: $error');
        _notificationController.addError(error);
      },
    );
    _isInitialized = true;
    print('[NotificationChannelService] EventChannel initialized.');
  }

  /// 从Dart代码中模拟一个通知事件。
  /// 这对于调试和测试非常有用。
  void sendMockNotification(Map<String, dynamic> mockData) {
    _notificationController.add(mockData);
  }

  /// 关闭StreamController，在应用生命周期结束时调用
  void dispose() {
    _notificationController.close();
  }
} 