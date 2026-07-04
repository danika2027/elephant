import 'package:shared_preferences/shared_preferences.dart';

/// 旅程状态管理
/// —— 追踪"小象走到哪了"
class JourneyService {
  static const String _startDateKey = 'journey_start_date';
  static const String _onboardedKey = 'has_onboarded';
  static const String _routeIdKey = 'selected_route_id';
  static const String _lastOpenedDateKey = 'last_opened_date';
  static const String _hasReadTodayKey = 'has_read_today';
  static const String _hasFedTodayKey = 'has_fed_today';
  static const String _hasChattedTodayKey = 'has_chatted_today';
  static const String _delayedDayKey = 'delayed_day';
  static const String _totalDaysKey = 'total_days';
  static const String _arrivedKey = 'has_arrived_ceremony';
  static const String _arrivalDateKey = 'arrival_date';
  static const String _unlockedKey = 'msg_unlocked';
  static const int totalDays = 10;

  // ---- 路线存储 ----

  Future<String> getRouteId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_routeIdKey) ?? 'nanning_guilin';
  }

  Future<void> setRouteId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_routeIdKey, id);
  }

  // ---- 首次启动管理 ----

  /// 是否已完成首次启动引导
  Future<bool> hasOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  /// 标记引导完成
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
  }

  // ---- 日期管理 ----

  /// 读取旅程开始日期（需先完成 onboarding）
  Future<DateTime> getStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_startDateKey);
    if (stored != null) return DateTime.parse(stored);
    final today = _today();
    await prefs.setString(_startDateKey, _fmt(today));
    return today;
  }

  /// 手动设置出发日期（给未来预留：用户可以主动选择出发日）
  Future<void> setStartDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_startDateKey, _fmt(date));
  }

  /// 重置旅程（重新出发）
  /// 清除旅程状态，但保留引导标记和小象档案
  Future<void> resetJourney() async {
    final prefs = await SharedPreferences.getInstance();
    final keep = {_onboardedKey, 'elephant_profile', 'elephant_state'};
    final toRemove = prefs.getKeys().where((k) => !keep.contains(k)).toList();
    for (final k in toRemove) {
      await prefs.remove(k);
    }
  }

  // ---- 旅程进度 ----

  /// 今天是第几天（1 - totalDays）
  Future<int> getCurrentDay() async {
    final start = await getStartDate();
    final td = await getTotalDays();
    final diff = _today().difference(start).inDays + 1;
    if (diff < 1) return 1;
    if (diff > td) return td;
    return diff;
  }

  /// 实际经过天数
  Future<int> getElapsedDays() async {
    final start = await getStartDate();
    return _today().difference(start).inDays + 1;
  }

  /// 小象是否已经到达目的地
  Future<bool> hasArrived() async {
    final td = await getTotalDays();
    return await getElapsedDays() > td;
  }

  /// 旅程进度（0.0 - 1.0）
  Future<double> getProgress() async {
    final day = await getCurrentDay();
    final arrived = await hasArrived();
    final td = await getTotalDays();
    if (arrived) return 1.0;
    return day / td;
  }

  // ---- 每日状态 ----

  /// 最后打开日期 "YYYY-MM-DD"
  Future<String> getLastOpenedDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastOpenedDateKey) ?? '';
  }

  Future<void> setLastOpenedDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOpenedDateKey, date);
  }

  /// 今天是否已读过日记
  Future<bool> hasReadToday(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_hasReadTodayKey);
    return stored == today;
  }

  Future<void> markReadToday(String today) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hasReadTodayKey, today);
  }

  static const int _maxInteractionsPerDay = 3;

  /// 今天已喂食次数
  Future<int> getFedCount(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_hasFedTodayKey}_$today';
    return prefs.getInt(key) ?? 0;
  }

  /// 今天还能喂食吗
  Future<bool> canFeedToday(String today) async {
    return await getFedCount(today) < _maxInteractionsPerDay;
  }

  Future<void> incrementFed(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_hasFedTodayKey}_$today';
    final count = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, count);
  }

  int get maxInteractionsPerDay => _maxInteractionsPerDay;

  /// 今天已聊天次数
  Future<int> getChattedCount(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_hasChattedTodayKey}_$today';
    return prefs.getInt(key) ?? 0;
  }

  /// 今天还能聊天吗
  Future<bool> canChatToday(String today) async {
    return await getChattedCount(today) < _maxInteractionsPerDay;
  }

  Future<void> incrementChatted(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_hasChattedTodayKey}_$today';
    final count = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, count);
  }

  // 兼容旧方法（给 HomeScreen 用，检查是否已达上限）
  Future<bool> hasFedToday(String today) async {
    return !(await canFeedToday(today));
  }

  Future<bool> hasChattedToday(String today) async {
    return !(await canChatToday(today));
  }

  // ---- 延迟事件 ----

  Future<int?> getDelayedDay() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_delayedDayKey);
    return v;
  }

  Future<void> setDelayedDay(int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_delayedDayKey, day);
  }

  Future<int> getTotalDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalDaysKey) ?? totalDays;
  }

  Future<void> setTotalDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_totalDaysKey, days);
  }

  /// 是否已展示到达仪式
  Future<bool> hasShownArrivalCeremony() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_arrivedKey) ?? false;
  }

  Future<void> markArrivalCeremonyShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_arrivedKey, true);
  }

  // ---- 到达日期 & 陪伴天数 ----

  Future<DateTime?> getArrivalDate() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_arrivalDateKey);
    if (s == null) return null;
    return DateTime.parse(s);
  }

  Future<void> setArrivalDate(DateTime d) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_arrivalDateKey, _fmt(d));
  }

  /// 到达后第几天（到达当天=1，次日=2，以此类推）
  Future<int> getDaysSinceArrival() async {
    final arrival = await getArrivalDate();
    if (arrival == null) return 1;
    final diff = _today().difference(arrival).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  // ---- 今日消息解锁 ----

  /// 今天已解锁的消息数（0-3）
  Future<int> getUnlockedCount(String today) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${_unlockedKey}_$today') ?? 0;
  }

  /// 解锁下一条消息（返回新的解锁数）
  Future<int> unlockNext(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_unlockedKey}_$today';
    final current = prefs.getInt(key) ?? 0;
    final next = (current + 1).clamp(0, 3);
    await prefs.setInt(key, next);
    return next;
  }

  /// 是否是旅程最后天
  Future<bool> isLastDay() async {
    final td = await getTotalDays();
    final day = await getCurrentDay();
    return day >= td;
  }

  /// 检测昨天是否错过了——lastOpenedDate 比昨天还早
  Future<bool> checkMissedYesterday() async {
    final last = await getLastOpenedDate();
    if (last.isEmpty) return false;
    final yesterday = _fmt(_today().subtract(const Duration(days: 1)));
    return last.compareTo(yesterday) < 0;
  }

  // ---- 工具 ----

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
