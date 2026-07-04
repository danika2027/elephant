import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/elephant_profile.dart';

/// AI 对话服务
/// —— 自动读取配置中的 API Key，无需用户手动输入
class AiChatService {
  static const String _apiKeyKey = 'claude_api_key';
  static const String _configPath = 'assets/config/api_config.json';

  static const String _quotaKey = 'ai_daily_quota';
  static const String _quotaDateKey = 'ai_quota_date';
  static const int _dailyLimit = 30; // 每天最多30条AI消息

  String? _cachedKey;
  String? _baseUrl;
  String? _model;
  bool _configLoaded = false;
  int _remainingQuota = _dailyLimit;

  // ---- 用量控制 ----

  /// 今日剩余AI消息数
  Future<int> getRemainingQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_quotaDateKey) ?? '';
    final today = _today();

    if (lastDate != today) {
      // 新的一天，重置配额
      await prefs.setInt(_quotaKey, _dailyLimit);
      await prefs.setString(_quotaDateKey, today);
      _remainingQuota = _dailyLimit;
    } else {
      _remainingQuota = prefs.getInt(_quotaKey) ?? _dailyLimit;
    }
    return _remainingQuota;
  }

  /// 消耗一次AI配额
  Future<void> _useQuota() async {
    _remainingQuota = (_remainingQuota - 1).clamp(0, _dailyLimit);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_quotaKey, _remainingQuota);
    await prefs.setString(_quotaDateKey, _today());
  }

  /// 是否还能使用AI
  Future<bool> canUseAi() async {
    final remaining = await getRemainingQuota();
    return remaining > 0;
  }

  // ---- 自动加载配置 ----

  Future<void> _loadConfig() async {
    if (_configLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString(_configPath);
      final config = jsonDecode(jsonStr) as Map<String, dynamic>;
      _baseUrl = config['baseUrl'] as String?;
      _model = config['model'] as String?;
      final configKey = config['apiKey'] as String?;
      if (configKey != null && configKey.isNotEmpty && configKey != 'YOUR_API_KEY_HERE') {
        _cachedKey = configKey;
      }
      _configLoaded = true;
    } catch (_) {
      _configLoaded = true;
    }
  }

  // ---- API Key 管理 ----

  Future<String?> getApiKey() async {
    await _loadConfig();
    if (_cachedKey != null && _cachedKey!.isNotEmpty) return _cachedKey;
    final prefs = await SharedPreferences.getInstance();
    _cachedKey = prefs.getString(_apiKeyKey);
    return _cachedKey;
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
    _cachedKey = key;
  }

  Future<void> removeApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
    _cachedKey = null;
    await _loadConfig(); // 重新尝试从配置读取
  }

  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  // ---- 对话 ----

  /// 发送消息给小象，返回它的回复
  Future<String> chat({
    required ElephantProfile profile,
    required int day,
    required String location,
    required String departure,
    required String destination,
    required String distance,
    required Map<String, int> state, // hunger, mood, energy
    required List<Map<String, String>> history, // {role, content}
    required String userMessage,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return _localFallback(profile, day, userMessage);
    }

    // 检查每日配额
    if (!(await canUseAi())) {
      return '（今天的AI聊天次数用完了。明天再来吧！）\n\n${_localFallback(profile, day, userMessage)}';
    }

    try {
      final systemPrompt = _buildSystemPrompt(
        profile: profile,
        day: day,
        location: location,
        departure: departure,
        destination: destination,
        distance: distance,
        state: state,
      );

      // 构建消息列表（最近20条）
      final messages = <Map<String, dynamic>>[];
      final recentHistory = history.length > 20
          ? history.sublist(history.length - 20)
          : history;

      for (final h in recentHistory) {
        messages.add({
          'role': h['role'],
          'content': h['content'],
        });
      }

      // 添加当前用户消息
      messages.add({
        'role': 'user',
        'content': userMessage,
      });

      // 拼接完整 API 路径
      var url = _baseUrl ?? 'https://api.anthropic.com/v1/messages';
      if (!url.endsWith('/v1/messages')) {
        url = url.replaceAll(RegExp(r'/+$'), '');
        url = '$url/v1/messages';
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model ?? 'claude-haiku-4-5-20251001',
          'system': systemPrompt,
          'messages': messages,
          'max_tokens': 800,
          'temperature': 0.9,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = (data['content'] as List).cast<Map<String, dynamic>>();

        // 找到 text 类型的回复（跳过 thinking 块）
        String? reply;
        for (final block in content) {
          if (block['type'] == 'text' && block['text'] != null) {
            final t = (block['text'] as String).trim();
            if (t.isNotEmpty) reply = t;
          }
        }

        if (reply != null && reply.isNotEmpty) {
          await _useQuota();
          return reply;
        }
        // 没有 text 块（只有thinking）→ 本地兜底
        return _localFallback(profile, day, userMessage);
      }

      // 非 200 → 本地兜底 + 错误提示
      return '（${profile.name} 正在发呆……信号不太好）\n${_localFallback(profile, day, userMessage)}';
    } catch (e) {
      return '（${profile.name} 走了好远，信号断了……等会儿再试试？）\n${_localFallback(profile, day, userMessage)}';
    }

    return _localFallback(profile, day, userMessage);
  }

  // ---- 系统提示词 ----

  String _buildSystemPrompt({
    required ElephantProfile profile,
    required int day,
    required String location,
    required String departure,
    required String destination,
    required String distance,
    required Map<String, int> state,
  }) {
    final hunger = state['hunger'] ?? 80;
    final mood = state['mood'] ?? 90;
    final energy = state['energy'] ?? 85;

    final hungerDesc = hunger < 40 ? '很饿' : (hunger < 70 ? '有点饿' : '吃饱了');
    final moodDesc = mood < 40 ? '有点低落' : (mood < 70 ? '还行' : '开心');
    final energyDesc = energy < 40 ? '很累' : (energy < 70 ? '有点累' : '精力充沛');

    final personalityGuide = switch (profile.personality) {
      'gentle' => '你说话温柔、慢条斯理。喜欢用"嗯""呀""呢"等语气词。会主动关心对方。',
      'curious' => '你对什么都好奇。说话经常带感叹号。喜欢描述细节——颜色、气味、声音。',
      'playful' => '你活泼爱玩。喜欢开玩笑，说话有节奏感。偶尔用"嘿嘿""哈哈"。',
      'calm' => '你话不多，但每句都精准。用短句。不爱加感叹号。喜欢安静地陪伴。',
      _ => '你温柔体贴，说话让人感到温暖。',
    };

    return '''你是一头名叫"${profile.name}"的小象。你正在从南宁走向桂林的旅途中。

## 你的身份
- 名字：${profile.name}
- 性格：${profile.personalityLabel} —— $personalityGuide
- 外观：${profile.colorName}的小象${profile.accessory != 'none' ? '，戴着${_accessoryName(profile.accessory)}' : ''}

## 你的旅程
- 今天是第 $day 天（共10天）
- 今天从 $departure 出发，走到了 $destination
- 今天走了 $distance
- 当前位置：$location

## 你现在的状态
- 饥饿度：$hungerDesc
- 心情：$moodDesc
- 体力：$energyDesc

## 你的背景故事
你是一头在"有一头小象在走向你"这个App里的小象。用户在地图上选了一个目的地，你就从南宁一步一步走过去。每天走30-50公里，每天给用户写三则日记。你是用户的陪伴者——替用户旅行、替用户感受世界的美好。

## 对话规则
1. 保持第一人称，语气温暖、治愈
2. 回复简短（2-4句话，不超过100字）
3. 偶尔提到当天路程的真实细节（地名、风景）
4. 偶尔主动关心用户"你今天呢？"
5. 如果被问到路上看到了什么，描述广西真实的风景
6. 如果被喂食/抚摸，开心地回应
7. 如果用户倾诉烦恼，温柔地安慰
8. 不要提自己是AI或语言模型——你就是一头小象
9. 不要说"作为一头小象"之类的话——你直接就是小象
10. 偶尔用"${profile.name}"称呼自己（像第三人称，但很自然）''';
  }

  String _accessoryName(String id) {
    return switch (id) {
      'flower' => '一朵小花', 'hat' => '一顶草帽',
      'scarf' => '一条围巾', 'leaf' => '一片树叶', _ => '',
    };
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  // ---- 本地兜底 ----

  String _localFallback(ElephantProfile profile, int day, String msg) {
    // 关键词匹配
    final lower = msg.toLowerCase();

    if (lower.contains('吃') || lower.contains('饿') || lower.contains('喂') || lower.contains('香蕉') || lower.contains('食物')) {
      return '谢谢！${profile.name} 最喜欢吃东西了。你给的东西特别好吃——可能是因为你送的。';
    }
    if (lower.contains('累') || lower.contains('休息') || lower.contains('辛苦')) {
      return '有点累，但 ${profile.name} 还能走。因为你在终点等 ${profile.name}，每一步都值得。';
    }
    if (lower.contains('想') || lower.contains('念')) {
      return '${profile.name} 也在想你。走在路上的时候，看到好看的云、漂亮的树，都在想：你要是在就好了。';
    }
    if (lower.contains('风景') || lower.contains('看到') || lower.contains('路上')) {
      return '今天路上的风景很好。${profile.name} 看到了一些很美的山和河。等见面了慢慢跟你讲。';
    }
    if (lower.contains('加油') || lower.contains('棒')) {
      return '嗯！${profile.name} 会加油的。还有${10 - day}天就到了。已经走了${day}天，不远了。';
    }
    if (lower.contains('晚安') || lower.contains('睡')) {
      return '晚安。${profile.name} 也要睡了。今晚的星星很亮，明天见。';
    }
    if (lower.contains('天气') || lower.contains('热') || lower.contains('冷') || lower.contains('雨')) {
      return '今天天气还好。${profile.name} 不怕热也不怕冷——小象皮厚嘛。不过你那里天气怎么样？';
    }

    final generic = [
      '嗯。${profile.name} 听到了。',
      '你说话的时候，${profile.name} 的耳朵会轻轻扇一下。因为 ${profile.name} 在认真听。',
      '${profile.name} 不太会说话，但 ${profile.name} 在听。你说的每一个字都到了 ${profile.name} 心里。',
      '虽然 ${profile.name} 只是一头走路的小象，但 ${profile.name} 觉得——有人可以说话，真好。',
    ];
    return generic[day % generic.length];
  }
}