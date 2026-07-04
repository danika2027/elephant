import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/elephant_profile.dart';

/// 小象服务 —— 管理档案 + 实时状态 + 互动对话
class ElephantService {
  static const String _profileKey = 'elephant_profile';
  static const String _stateKey = 'elephant_state';
  static const String _stateDateKey = 'elephant_state_date';

  final Random _random = Random();

  // ---- 档案 ----

  Future<ElephantProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw != null) {
      return ElephantProfile.fromJson(
          Map<String, dynamic>.from(
              {for (var e in raw.split('|')) e.split(':')[0]: e.split(':').length > 1 ? e.split(':').sublist(1).join(':') : ''}));
    }
    return ElephantProfile();
  }

  /// 更可靠的 JSON 存取
  Future<ElephantProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw != null && raw.startsWith('{')) {
      return ElephantProfile.fromJson(_parseSimple(raw));
    }
    return ElephantProfile();
  }

  Future<void> saveProfile(ElephantProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final json = profile.toJson();
    await prefs.setString(
        _profileKey,
        'name:${json['name']}|personality:${json['personality']}|accessory:${json['accessory']}|colorName:${json['colorName']}');
  }

  // ---- 实时状态 ----

  Future<ElephantState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw != null) {
      // 检查是否已过天（每天衰减一次）
      final lastDate = prefs.getString(_stateDateKey) ?? '';
      final today = _today();
      if (lastDate != today) {
        final state = ElephantState(); // 新一天的基础值
        await saveState(state);
        await prefs.setString(_stateDateKey, today);
        return state;
      }
      return ElephantState.fromJson(_parseSimple(raw));
    }
    final state = ElephantState();
    await saveState(state);
    await prefs.setString(_stateDateKey, _today());
    return state;
  }

  Future<void> saveState(ElephantState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _stateKey,
        'hunger:${state.hunger}|mood:${state.mood}|energy:${state.energy}');
  }

  Future<void> feed() async {
    final state = await loadState();
    state.feed();
    await saveState(state);
  }

  Future<void> pet() async {
    final state = await loadState();
    state.pet();
    await saveState(state);
  }

  Future<void> talk() async {
    final state = await loadState();
    state.talk();
    await saveState(state);
  }

  // ==========================================================
  //  对话引擎 —— 上下文感知多轮对话
  // ==========================================================

  final Set<String> _usedGreetings = {};
  final List<String> _conversationLog = [];

  /// 根据完整上下文生成开场白
  String generateGreeting({
    required String personality,
    required String name,
    required int day,
    required String location,
    required ElephantState state,
  }) {
    // 基于状态选择话题方向
    String topic;
    if (state.hunger < 40) {
      topic = 'hungry';
    } else if (state.energy < 40) {
      topic = 'tired';
    } else if (day == 10) {
      topic = 'arrived';
    } else if (day == 1) {
      topic = 'starting';
    } else if (day >= 7) {
      topic = 'near_end';
    } else {
      topic = 'normal';
    }

    final candidates = _greetingPool(personality, name, day, location, state, topic)
        .where((g) => !_usedGreetings.contains(g))
        .toList();

    if (candidates.isEmpty) {
      _usedGreetings.clear();
      candidates.addAll(_greetingPool(personality, name, day, location, state, topic));
    }

    final picked = candidates[_random.nextInt(candidates.length)];
    _usedGreetings.add(picked);
    _conversationLog.add('🐘: $picked');
    return picked;
  }

  List<String> _greetingPool(String personality, String name, int day,
      String location, ElephantState state, String topic) {
    final base = <String>[];

    switch (topic) {
      case 'hungry':
        base.addAll([
          '好饿啊……你有没有带吃的？',
          '我的肚子在叫了。$location有没有香蕉树？',
          '走了一天了，还没吃东西呢。',
        ]);
        break;
      case 'tired':
        base.addAll([
          '今天走了好久，腿有点酸。不过看到你就不累了。',
          '我在$location歇一会儿。你要不要也坐下来？',
          '有点累了，但是开心的那种累。',
        ]);
        break;
      case 'arrived':
        base.addAll([
          '我到桂林了！$name终于走到终点了。',
          '你看那边的山——象鼻山。长得跟我有点像对吧？',
          '十天了。$name走完了。现在我就待在这儿陪你。',
        ]);
        break;
      case 'starting':
        base.addAll([
          '我出发了！南宁今天天气很好。你那里呢？',
          '第一天！$name有点紧张，但更多的是兴奋。',
          '离开南宁了。回头看了一眼，然后继续走了。',
        ]);
        break;
      case 'near_end':
        base.addAll([
          '快到桂林了。$name有点舍不得。',
          '离你越来越近了。心情有点复杂——高兴又舍不得。',
          '走了${day}天了。每一天都很值得。',
        ]);
        break;
      default:
        base.addAll([
          '今天$location的天气不错，风吹得耳朵痒痒的。',
          '我在$location。你在哪里呀？',
          '刚走了一段路，现在在$location歇脚。',
        ]);
    }

    // 性格变体
    final personalityGreetings = switch (personality) {
      'gentle' => [
          '你来了呀。我刚刚在看云。',
          '嗯？你找我？我一直在等你呢。',
        ],
      'curious' => [
          '嘿！你猜我今天在路上看到了什么？',
          '我发现$location有一种特别的石头！',
        ],
      'playful' => [
          '要不要也踩一下这个水坑？超好玩的！',
          '我刚才用鼻子给自己喷水了，凉快！',
        ],
      'calm' => [
          '嗯。你来了。坐吧。',
          '我在想一些事。不过你来了，就先不想了。',
        ],
      _ => ['你好呀！'],
    };

    base.addAll(personalityGreetings);
    return base;
  }

  /// 生成用户可以选择的回复选项（2-3个）
  List<UserOption> getUserOptions({
    required String personality,
    required int day,
    required String location,
    required ElephantState state,
    required int turn, // 第几轮对话 0=第一轮
  }) {
    final options = <UserOption>[];

    // 第一轮：关心小象 or 好奇路程
    if (turn == 0) {
      if (state.hunger < 50) {
        options.add(UserOption('🍌', '给你带了好吃的', 'feed'));
      }
      options.add(UserOption('💬', '今天路上看到了什么？', 'ask_scenery'));
      options.add(UserOption('❤️', '你累不累？要不要歇会儿', 'care'));
    } else {
      // 第二轮：更深入的话题
      options.add(UserOption('💭', '跟我说说你正在想什么', 'thoughts'));
      options.add(UserOption('🌄', '前面还有什么风景？', 'ahead'));
      if (state.energy < 50) {
        options.add(UserOption('🛖', '今晚住哪儿？早点休息吧', 'rest'));
      } else {
        options.add(UserOption('😊', '讲个路上的小故事吧', 'story'));
      }
    }

    return options;
  }

  /// 小象对用户选择的回复
  String getResponse({
    required String personality,
    required String name,
    required int day,
    required String location,
    required ElephantState state,
    required String userChoice,
  }) {
    final response = _buildResponse(personality, name, day, location, state, userChoice);
    _conversationLog.add('👤→$userChoice\n🐘: $response');
    return response;
  }

  String _buildResponse(String personality, String name, int day,
      String location, ElephantState state, String choice) {
    final pool = switch (choice) {
      'feed' => _feedResponses(name, personality),
      'ask_scenery' => _sceneryResponses(name, day, location, personality),
      'care' => _careResponses(name, day, state, personality),
      'thoughts' => _thoughtsResponses(name, day, personality),
      'ahead' => _aheadResponses(name, day, personality),
      'rest' => _restResponses(name, location, personality),
      'story' => _storyResponses(name, day, personality),
      _ => ['嗯。$name在想……该说什么好呢。'],
    };
    return pool[_random.nextInt(pool.length)];
  }

  // ---- 各话题回复池 ----

  List<String> _feedResponses(String name, String personality) {
    final gentle = [
      '谢谢……$name不好意思地低下头。你真的很好。',
      '嗯。很好吃。$name慢慢嚼着，觉得这个世界很温柔。',
    ];
    final curious = [
      '哇这是什么？！$name从来没吃过！再闻一下……嗯，好吃！',
      '好吃好吃好吃！这个味道好特别！是哪里来的？',
    ];
    final playful = [
      '嗷呜一口！好吃！你还有吗？$name用期待的眼神看着你。',
      '嘿嘿，$name最爱你了。当然不只是因为吃的——但吃的也很重要！',
    ];
    final calm = [
      '嗯。谢谢。$name慢慢吃着，觉得这样就很好。',
      '你每次都记得带吃的。$name很感激。',
    ];
    return switch (personality) {
      'gentle' => gentle, 'curious' => curious,
      'playful' => playful, 'calm' => calm, _ => gentle,
    };
  }

  List<String> _sceneryResponses(String name, int day, String location, String personality) {
    final specifics = <String>[];
    switch (day) {
      case 1: specifics.addAll(['南宁郊外好大一片甘蔗地！风一吹沙沙响，像在说悄悄话。路边的沃柑阿婆还塞给我两个橘子。']); break;
      case 2: specifics.addAll(['昆仑关的山好高，树好密。石板路哒哒响，还有一棵开了红花的木棉树。']); break;
      case 3: specifics.addAll(['桉树林里的小路窄窄的，桉树又高又直。遇到一辆拖拉机，司机给我让路了，真好。']); break;
      case 4: specifics.addAll(['宾阳县城好热闹！一个小孩子指着我说"小象！"——我好想跟他说，我不是普通小象，我是你的小象。']); break;
      case 5: specifics.addAll(['红水河的水绿绿的，名字叫红水河但水不红。站在河边看自己的倒影，水里也有一头小象在看我。']); break;
      case 6: specifics.addAll(['清水河的水真的很清，能看到河底的石头。我在河里洗了个澡，小朋友在旁边笑得蹲在地上。']); break;
      case 7: specifics.addAll(['走了一半了。来宾的红水河大桥上，所有的车都在等我过马路。没有人按喇叭。']); break;
      case 8: specifics.addAll(['穿山镇的甘蔗海一望无际！风吹过来，整片甘蔗林像在做操。忍住没进去吃——我有任务在身。']); break;
      case 9: specifics.addAll(['鹿寨的山变尖了。不是圆圆的丘陵，是有棱角的石头山。喀斯特地貌——路过的老师说的。']); break;
      case 10: specifics.addAll(['桂林的山是一根一根从地里冒出来的。象鼻山跟我好像！它是石头小象，我是走路小象。']); break;
    }
    specifics.addAll([
      '$location的风景，$name想用鼻子画下来给你看。',
      '走在$location的路上，$name在想：你要是在就好了。',
    ]);
    return specifics;
  }

  List<String> _careResponses(String name, int day, ElephantState state, String personality) {
    return [
      '有一点点累。但$name还能走。因为你在等$name。',
      '不累！好吧，有一点点。但开心的那种累。第${day}天了，每一步都值得。',
      if (state.energy < 50) '嗯……$name确实需要休息一下。不过你问$name累不累，$name就不累了。',
      '$name的脚底板有点酸，但心里是满的。谢谢你的关心。',
    ];
  }

  List<String> _thoughtsResponses(String name, int day, String personality) {
    final base = switch (personality) {
      'gentle' => [
          '$name在想：走在路上的感觉真好。不急不慢，每一天都在靠近你。',
          '想了很多。比如这十天的路到底有多长——不是公里，是每一步里对你的想念。',
        ],
      'curious' => [
          '$name在想：为什么甘蔗是甜的？为什么山是尖的？为什么人在开心的时候会笑？——你不要笑$name，$name就是会想这些。',
          '在想你啊！还有……在想前面会不会遇到有趣的东西。',
        ],
      'playful' => [
          '在想一个笑话。但是还没想好。等$name想好了第一个讲给你听！',
          '在想——如果$name会飞的话，是不是就不用走十天了？但那样就不能给你写日记了。所以还是走路好。',
        ],
      'calm' => [
          '在想：有的陪伴不需要说话。就像现在这样——你在，$name在。就够了。',
          '$name在想这一路的意义。不是为了到达，是为了这个过程。',
        ],
      _ => ['在想你。'],
    };
    return base;
  }

  List<String> _aheadResponses(String name, int day, String personality) {
    if (day >= 10) return ['前面？前面就是终点了。$name到了。以后不用走了——就待在这儿陪你。'];
    final remaining = 10 - day;
    return [
      '前面还有${remaining}天的路。会经过更多的小镇、更多的河、更多的山。$name会一个个看过来，然后讲给你听。',
      '还有${remaining}天就到桂林了。$name有点激动，又有点舍不得——这趟路$name走得很开心。',
      '前面的路$name也不太清楚。但$name不怕——因为你在终点等$name。',
    ];
  }

  List<String> _restResponses(String name, String location, String personality) {
    return [
      '嗯。$name在$location找了棵大树靠着。树荫很好，你也休息一下吧。',
      '好。$name这就找个舒服的地方——最好是棵大榕树。榕树的须根可以给$name挠背。',
      '谢谢。$name确实该歇了。今天的路走完了，剩下的明天再走。你也是，别太勉强自己。',
    ];
  }

  List<String> _storyResponses(String name, int day, String personality) {
    final stories = <String>[];
    switch (day) {
      case 1: stories.add('今天故事：出发的时候，$name在民族大道上站了好久。路人都走得很快，只有一个小孩停下来看了$name一眼。那一眼让$name觉得——这趟路值得走。'); break;
      case 3: stories.add('今天故事：$name遇到一只蝴蝶。它在$name鼻尖上停了大概三秒钟，然后飞走了。$name觉得这是它跟$name说"加油"。'); break;
      case 5: stories.add('今天故事：红水河边有一只乌龟。它比$name还慢。我们对视了一眼，都很欣赏对方的节奏。'); break;
      case 7: stories.add('今天故事：过红水河大桥的时候，$name走到一半红灯了。所有的车都停下来。没有人按喇叭。来宾的司机真好。'); break;
      default: stories.add('今天故事：$name在路上遇到一朵紫色的小花。它从石头缝里长出来的，就那么开着。$name觉得它很勇敢。');
    }
    stories.add('还有一个故事——但$name想留到明天再讲。这样你明天还会来找$name。');
    return stories;
  }

  // ---- 快捷操作反馈 ----

  String getFeedingResponse(String name) {
    return _feedResponses(name, 'gentle')[_random.nextInt(2)]; // 默认温柔
  }

  String getPettingResponse(String name) {
    final responses = [
      '嗯…好舒服。再摸一下？$name的耳朵最怕痒了。',
      '嘿嘿，$name喜欢被你摸。好久没有人这样摸$name了。',
      '呼噜呼噜……（$name发出满足的低鸣）谢谢你。',
    ];
    return responses[_random.nextInt(responses.length)];
  }

  void clearConversation() {
    _conversationLog.clear();
  }

  // ---- 工具 ----

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Map<String, dynamic> _parseSimple(String raw) {
    final map = <String, dynamic>{};
    for (var part in raw.split('|')) {
      final colon = part.indexOf(':');
      if (colon > 0) {
        final key = part.substring(0, colon);
        final value = part.substring(colon + 1);
        final intVal = int.tryParse(value);
        map[key] = intVal ?? value;
      }
    }
    return map;
  }
}

/// 用户回复选项
class UserOption {
  final String emoji;
  final String label;
  final String id; // feed | ask_scenery | care | thoughts | ahead | rest | story

  const UserOption(this.emoji, this.label, this.id);
}
