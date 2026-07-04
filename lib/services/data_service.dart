import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/day_data.dart';
import '../models/route_info.dart';
import '../models/elephant_profile.dart';

/// 数据加载服务 —— 加载 JSON + 个性化模板替换
class DataService {
  static const String _defaultPath = 'assets/data/journey_data.json';
  static const String _variantsPath = 'assets/data/personality_variants.json';

  JourneyData? _cached;
  String? _cachedPath;
  Map<String, dynamic>? _variants;

  /// 加载指定路线的旅程数据（含个性化替换）
  Future<JourneyData> loadJourneyData({String? assetPath}) async {
    final path = assetPath ?? _defaultPath;
    if (_cached != null && _cachedPath == path) return _cached!;

    final jsonStr = await rootBundle.loadString(path);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    _cached = JourneyData.fromJson(json);
    _cachedPath = path;
    return _cached!;
  }

  /// 根据 RouteInfo 加载
  Future<JourneyData> loadByRoute(RouteInfo route) {
    return loadJourneyData(assetPath: route.assetPath);
  }

  /// 加载性格变体 JSON
  Future<Map<String, dynamic>> _loadVariants() async {
    if (_variants != null) return _variants!;
    final str = await rootBundle.loadString(_variantsPath);
    _variants = jsonDecode(str) as Map<String, dynamic>;
    return _variants!;
  }

  /// 核心：个性化处理日记内容
  /// 对加载好的 JourneyData 做 {name} 替换、性格变体、心愿注入
  Future<void> personalize(JourneyData data, ElephantProfile profile) async {
    final variants = await _loadVariants();
    final name = profile.name;

    for (final day in data.days) {
      final dayKey = 'day${day.day}';
      final dayVariants = variants[dayKey] as Map<String, dynamic>?;

      for (int i = 0; i < day.messages.length; i++) {
        final msg = day.messages[i];
        var content = msg.content;

        // 如果有性格变体且当前消息是"路途见闻"，替换
        if (dayVariants != null && msg.type == 'journey') {
          final variantContent = dayVariants[profile.personality] as String?;
          if (variantContent != null) {
            content = variantContent;
          }
        }

        // 替换 {name}
        content = content.replaceAll('{name}', name);

        // 第3天 + 有心愿 → 注入心愿句
        if (day.day == 3 && msg.type == 'journey' && profile.wish.isNotEmpty) {
          final wishText = _buildWishSentence(profile.wish, name);
          content = '$content\n\n$wishText';
        }

        day.messages[i] = ElephantMessage(
          type: msg.type,
          timeOfDay: msg.timeOfDay,
          location: msg.location,
          content: content,
          signature: msg.signature.replaceAll('{name}', name),
          scenery: msg.scenery,
          photoUrl: msg.photoUrl,
        );
      }
    }
  }

  /// 根据心愿关键词生成插入句子
  String _buildWishSentence(String wish, String name) {
    if (wish.contains('山')) {
      return '主人说过想看山——$name今天刚好翻过了昆仑关。山很大、很绿，风从山脊吹过来的时候，$name觉得它在替主人吹的。';
    }
    if (wish.contains('水') || wish.contains('河') || wish.contains('海')) {
      return '主人说过想看水——$name今天路过好几条小溪。水很清，叮叮咚咚的，$name用鼻子试了试水温，凉的。替主人感受过了。';
    }
    if (wish.contains('花') || wish.contains('草')) {
      return '主人说过想看花——$name在路边看到一片野花，紫的、白的、黄的，很小但很多。$name停下来看了三分钟。替主人看的。';
    }
    if (wish.contains('云') || wish.contains('天')) {
      return '主人说过想看天空——$name今天抬头看了好几次。云走得很慢，像在等谁。$name替主人数了三朵云，都是白的。';
    }
    // 通用
    return '主人说过：\"$wish\"——$name记在心里了。今天在路上，$name想到了这句话，觉得走得更起劲了。';
  }

  Future<DayData> getDay(int day) async {
    final data = await loadJourneyData();
    return data.getDay(day);
  }

  Future<List<DayData>> getAllDays() async {
    final data = await loadJourneyData();
    return data.days;
  }

  /// 获取延迟事件的个性化文案
  Future<String?> getDelayContent(int day, ElephantProfile profile) async {
    final variants = await _loadVariants();
    final key = 'delay_day$day';
    final dayVariants = variants[key] as Map<String, dynamic>?;
    if (dayVariants == null) return null;
    final content = dayVariants[profile.personality] as String?;
    if (content == null) return null;
    return content.replaceAll('{name}', profile.name);
  }

  void clearCache() {
    _cached = null;
    _cachedPath = null;
    _variants = null;
  }
}
