import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 推送通知服务
/// —— 一天三篇日记，分段随机时间到达
///    晨间 7:00-9:00 / 路途 12:00-15:00 / 傍晚 17:00-20:00
///    每天 App 打开时重新随机时间
class NotificationService {
  static const String _channelId = 'elephant_daily';
  static const String _channelName = '小象日记提醒';
  static const int _morningId = 0;
  static const int _journeyId = 1;
  static const int _eveningId = 2;
  static const int _lastDayId = 9;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Random _random = Random();

  void Function(int messageIndex)? onNotificationTap;

  // ---- 初始化 ----

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );

    Future<void> onDidReceive(NotificationResponse r) async {
      if (r.notificationResponseType == NotificationResponseType.selectedNotification) {
        onNotificationTap?.call(r.id ?? -1);
      }
    }

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onDidReceive,
      onDidReceiveBackgroundNotificationResponse: onDidReceive,
    );

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: '每天提醒你小象走到了哪里',
      importance: Importance.defaultImportance,
      enableVibration: false,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // ---- 排定一天的三个推送 ----

  Future<void> scheduleDayMessages({
    required String elephantName,
    required String morningLoc,
    required String journeyLoc,
    required String eveningLoc,
  }) async {
    await cancelAll();

    // 三个推送用 RepeatInterval.daily，每天自动在相同时刻重复
    // 每次 App 打开时重新随机时间 → cancelAll + 重新排定 = 每天不同
    await _plugin.periodicallyShow(
      _morningId,
      '🌅 $elephantName 出发了',
      '从 $morningLoc 启程，晨间日记已写好',
      RepeatInterval.daily,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    await _plugin.periodicallyShow(
      _journeyId,
      '🚶 $elephantName 在路上',
      '路过 $journeyLoc，路途日记已写好',
      RepeatInterval.daily,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    await _plugin.periodicallyShow(
      _eveningId,
      '🌙 $elephantName 歇脚了',
      '在 $eveningLoc 安顿下来，傍晚日记已写好',
      RepeatInterval.daily,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> scheduleLastDayMessage({required String elephantName}) async {
    await cancelAll();
    await _plugin.periodicallyShow(
      _lastDayId,
      '🐘 你的小象今天就要到了',
      '$elephantName 离你还有最后15公里。今天傍晚，它就会走到你面前。',
      RepeatInterval.daily,
      _details(importance: Importance.high, priority: Priority.high),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  NotificationDetails _details({
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.low,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId, _channelName,
        channelDescription: '每天提醒你小象走到了哪里',
        importance: importance, priority: priority,
        enableVibration: false,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: false,
      ),
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancel(_morningId);
    await _plugin.cancel(_journeyId);
    await _plugin.cancel(_eveningId);
    await _plugin.cancel(_lastDayId);
  }

  Future<void> showTestNotification(int day, String location) async {
    await _plugin.show(day, '🐘 第$day天 · $location',
        '小象刚刚走到了$location，来看看它今天的日记吧', _details());
  }
}
