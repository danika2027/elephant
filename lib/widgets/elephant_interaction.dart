import 'package:flutter/material.dart';
import '../models/elephant_profile.dart';
import '../services/elephant_service.dart';
import '../services/ai_chat_service.dart';
import '../services/journey_service.dart';
import '../theme/app_theme.dart';

/// QQ 式聊天互动面板
class ElephantInteractionSheet extends StatefulWidget {
  final ElephantProfile profile;
  final int currentDay;
  final String location;
  final String departure;
  final String destination;
  final String distance;
  final bool hasFedToday;
  final bool hasChattedToday;

  const ElephantInteractionSheet({
    super.key,
    required this.profile,
    required this.currentDay,
    required this.location,
    required this.departure,
    required this.destination,
    required this.distance,
    this.hasFedToday = false,
    this.hasChattedToday = false,
  });

  @override
  State<ElephantInteractionSheet> createState() =>
      _ElephantInteractionSheetState();
}

class _ElephantInteractionSheetState extends State<ElephantInteractionSheet> {
  final ElephantService _elephantService = ElephantService();
  final AiChatService _aiService = AiChatService();
  final JourneyService _journeyService = JourneyService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  ElephantState? _state;
  bool _loading = true;
  bool _aiEnabled = false;
  bool _typing = false;
  int _aiRemaining = 0;
  int _fedRemaining = 3;
  int _chatRemaining = 3;
  String _todayStr = '';

  // 聊天记录: {role: 'elephant'|'user'|'system', content: '...'}
  final List<Map<String, String>> _messages = [];
  // AI 对话历史
  final List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final state = await _elephantService.loadState();
    final hasAi = await _aiService.hasApiKey();
    final quota = hasAi ? await _aiService.getRemainingQuota() : 0;

    // 加载今日互动次数
    final todayStr = _fmtToday();
    _todayStr = todayStr;
    final fedCount = await _journeyService.getFedCount(todayStr);
    final chatCount = await _journeyService.getChattedCount(todayStr);
    final max = _journeyService.maxInteractionsPerDay;

    // 小象开场白
    final greeting = _getGreeting(state);
    _messages.add({'role': 'elephant', 'content': greeting});

    if (mounted) {
      setState(() {
        _state = state;
        _aiEnabled = hasAi;
        _aiRemaining = quota;
        _fedRemaining = (max - fedCount).clamp(0, max);
        _chatRemaining = (max - chatCount).clamp(0, max);
        _loading = false;
      });
    }
  }

  String _getGreeting(ElephantState state) {
    final name = widget.profile.name;
    if (state.hunger < 40) return '好饿啊……你有没有带吃的？';
    if (state.energy < 40) return '今天走了好久。有点累了——不过看到你就不累了。';
    if (widget.currentDay == 10) return '$name 到桂林了！你看那边的山——长得跟 $name 有点像对吧？';
    if (widget.currentDay == 1) return '第一天！$name 出发了。南宁今天天气不错，你那里呢？';
    return '你来了呀。$name 正在 ${widget.location} 歇脚呢。今天风很舒服。';
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ==========================================================
  //  发送消息
  // ==========================================================

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _chatRemaining <= 0) return;

    final userMsg = text.trim();
    _inputCtrl.clear();

    // 添加用户消息
    setState(() => _messages.add({'role': 'user', 'content': userMsg}));
    _scrollToBottom();
    setState(() => _typing = true);

    String reply;

    if (_aiEnabled) {
      // AI 对话
      _chatHistory.add({'role': 'user', 'content': userMsg});
      reply = await _aiService.chat(
        profile: widget.profile,
        day: widget.currentDay,
        location: widget.location,
        departure: widget.departure,
        destination: widget.destination,
        distance: widget.distance,
        state: {
          'hunger': _state?.hunger ?? 80,
          'mood': _state?.mood ?? 90,
          'energy': _state?.energy ?? 85,
        },
        history: _chatHistory,
        userMessage: userMsg,
      );
      _chatHistory.add({'role': 'assistant', 'content': reply});
      _aiRemaining = await _aiService.getRemainingQuota();
    } else {
      // 本地兜底
      reply = _localRespond(userMsg);
    }

    await _elephantService.talk();
    final s = await _elephantService.loadState();

    if (mounted) {
      setState(() {
        _messages.add({'role': 'elephant', 'content': reply});
        _state = s;
        _typing = false;
        _chatRemaining--;
      });
      await _journeyService.incrementChatted(_todayStr);
      _scrollToBottom();
    }
  }

  String _localRespond(String msg) {
    final name = widget.profile.name;
    final lower = msg.toLowerCase();

    if (lower.contains('吃') || lower.contains('饿') || lower.contains('喂') || lower.contains('香蕉')) {
      return '谢谢！$name 最喜欢吃东西了。你给的东西特别好吃——可能是因为你送的。';
    }
    if (lower.contains('累') || lower.contains('休息') || lower.contains('辛苦')) {
      return '有点累。但 $name 还能走。因为你在终点等着——每一步都值得。';
    }
    if (lower.contains('想') || lower.contains('念') || lower.contains('思念')) {
      return '$name 也在想你。走在路上看到好看的云、漂亮的花，都在想：你要是在就好了。';
    }
    if (lower.contains('风景') || lower.contains('看到') || lower.contains('路上') || lower.contains('什么')) {
      return '今天在${widget.location}附近，风景很好。$name 看到一些很美的山和河。等见面了慢慢跟你讲。';
    }
    if (lower.contains('加油') || lower.contains('棒') || lower.contains('厉害')) {
      final left = 10 - widget.currentDay;
      return '嗯！$name 会加油的。还有${left}天就到了。已经走了${widget.currentDay}天，不远了。';
    }
    if (lower.contains('晚安') || lower.contains('睡')) {
      return '晚安。$name 也要睡了。今晚的星星很亮。明天见。';
    }
    if (lower.contains('天气') || lower.contains('热') || lower.contains('冷') || lower.contains('雨')) {
      return '今天天气还好。$name 不怕热也不怕冷——小象皮厚嘛。不过你那里天气怎么样？';
    }
    if (lower.contains('爱') || lower.contains('喜欢')) {
      return '$name 也爱你。虽然 $name 只是一头走路的小象——但 $name 觉得，被你喜欢是这趟旅程最好的事。';
    }
    if (lower.contains('故事') || lower.contains('讲讲')) {
      return '今天的故事：$name 在${widget.location}遇到一只小蜗牛。它爬得比 $name 还慢。$name 等它过去了再走。因为 $name 理解慢慢走的感觉。';
    }

    // 泛化回应
    final generic = [
      '嗯。$name 听到了。你的话让 $name 觉得很暖。',
      '你说话的时候，$name 的耳朵会轻轻扇一下——那是 $name 在认真听。',
      '$name 不太会说话。但 $name 觉得，有人可以聊天，真好。',
    ];
    return generic[widget.currentDay % generic.length];
  }

  // ==========================================================
  //  快捷操作
  // ==========================================================

  Future<void> _feed() async {
    if (_fedRemaining <= 0) return;
    await _elephantService.feed();
    final s = await _elephantService.loadState();
    await _journeyService.incrementFed(_todayStr);
    final reply = '谢谢！这个好好吃。${widget.profile.name}很幸福。';
    if (mounted) {
      setState(() {
        _state = s;
        _fedRemaining--;
        _messages.add({'role': 'system', 'content': '🍌 你给${widget.profile.name}喂了吃的'});
        _messages.add({'role': 'elephant', 'content': reply});
      });
      _scrollToBottom();
    }
  }

  Future<void> _pet() async {
    if (_fedRemaining <= 0) return;
    await _elephantService.pet();
    final s = await _elephantService.loadState();
    await _journeyService.incrementFed(_todayStr);
    final reply = '嗯…好舒服。再摸一下？${widget.profile.name}最喜欢被你摸耳朵了。';
    if (mounted) {
      setState(() {
        _state = s;
        _fedRemaining--;
        _messages.add({'role': 'system', 'content': '✋ 你摸了摸${widget.profile.name}'});
        _messages.add({'role': 'elephant', 'content': reply});
      });
      _scrollToBottom();
    }
  }

  String _fmtToday() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==========================================================
  //  Build
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryWarm)),
      );
    }

    final acc = widget.profile.accessoryEmoji;

    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.55;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: maxHeight,
          child: Column(
            children: [
            // 拖拽条
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),

            // 头部
            _buildHeader(acc),
            const SizedBox(height: AppTheme.spacingSm),
            _buildStatusBar(),
            const SizedBox(height: AppTheme.spacingSm),
            const Divider(height: 1, color: AppTheme.dividerColor),

            // 消息列表
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: AppTheme.spacingSm,
                ),
                itemCount: _messages.length + (_typing ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _typing) {
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[index];
                  return _buildBubble(msg['role']!, msg['content']!);
                },
              ),
            ),

            // 快捷操作
            _buildQuickActions(),

            // 输入栏
            _buildInputBar(),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildHeader(String acc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Row(
        children: [
          Text('🐘$acc', style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.profile.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Text('${widget.profile.personalityLabel} · 第${widget.currentDay}天',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (_aiEnabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('AI·剩$_aiRemaining次',
                  style: const TextStyle(fontSize: 10, color: AppTheme.accentGreen, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    if (_state == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Row(
        children: [
          _miniStat('🍌', _state!.hunger),
          const SizedBox(width: 12),
          _miniStat('😊', _state!.mood),
          const SizedBox(width: 12),
          _miniStat('⚡', _state!.energy),
        ],
      ),
    );
  }

  Widget _miniStat(String emoji, int value) {
    final color = value > 60
        ? AppTheme.accentGreen
        : (value > 30 ? AppTheme.primaryWarm : Colors.red.shade300);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 3),
        Container(
          width: 40, height: 3,
          decoration: BoxDecoration(
            color: color.withAlpha(60),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value / 100,
            child: Container(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
      ],
    );
  }

  // ---- 气泡 ----

  Widget _buildBubble(String role, String content) {
    final isElephant = role == 'elephant';
    final isSystem = role == 'system';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(content,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isElephant ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isElephant) ...[
            const Text('🐘', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isElephant ? AppTheme.bgWarm : AppTheme.primaryWarm.withAlpha(25),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isElephant ? 4 : 16),
                  bottomRight: Radius.circular(isElephant ? 16 : 4),
                ),
              ),
              child: Text(content,
                  style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.5)),
            ),
          ),
          if (!isElephant) ...[
            const SizedBox(width: 6),
            const Text('💬', style: TextStyle(fontSize: 18)),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Text('🐘', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgWarm,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _TypingDots(),
          ),
        ],
      ),
    );
  }

  // ---- 快捷操作 ----

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: AppTheme.spacingSm),
      child: Row(
        children: [
          _quickBtn('🍌', '喂食', _feed, _fedRemaining <= 0, _fedRemaining > 0 ? '还能喂$_fedRemaining次' : '今天已经喂过啦，明天再来吧'),
          const SizedBox(width: 8),
          _quickBtn('✋', '摸摸', _pet, _fedRemaining <= 0, '今天互动过啦'),
          const Spacer(),
          if (!_aiEnabled)
            GestureDetector(
              onTap: () => _showApiKeyDialog(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryWarm.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🔑 接入AI让小象更聪明',
                    style: TextStyle(fontSize: 11, color: AppTheme.primaryWarm)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _quickBtn(String emoji, String label, VoidCallback onTap, bool disabled, String disabledText) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: disabled ? AppTheme.dividerColor.withAlpha(40) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: disabled ? AppTheme.dividerColor : AppTheme.dividerColor),
        ),
        child: Text(
          disabled ? disabledText : '$emoji $label',
          style: TextStyle(
            fontSize: 13,
            color: disabled ? AppTheme.textSecondary : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  // ---- 输入栏 ----

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingSm, AppTheme.spacingSm, AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.bgWarm,
        border: Border(top: BorderSide(color: AppTheme.dividerColor.withAlpha(128))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              onSubmitted: _chatRemaining <= 0 ? null : _sendMessage,
              enabled: _chatRemaining > 0,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: _chatRemaining <= 0
                    ? '今天已经聊过啦，明天再来吧'
                    : (_chatRemaining > 1
                        ? '跟小象说点什么...（还能聊$_chatRemaining次）'
                        : '最后一次聊天机会啦'),
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: _chatRemaining <= 1 ? AppTheme.primaryWarm : AppTheme.textSecondary,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppTheme.primaryWarm, width: 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _sendMessage(_inputCtrl.text),
            child: Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryWarm,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ---- API Key 设置 ----

  void _showApiKeyDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔑 接入 AI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('输入你的 Claude API Key，小象就能跟你自由聊天了。', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            const Text('Key 只存在你手机本地，不会上传。', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'sk-ant-api03-...',
                hintStyle: const TextStyle(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final key = ctrl.text.trim();
              if (key.isNotEmpty) {
                await _aiService.saveApiKey(key);
                if (mounted) {
                  setState(() => _aiEnabled = true);
                  _messages.add({'role': 'system', 'content': '🔑 AI 已接入！小象现在可以自由聊天了。'});
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryWarm, foregroundColor: Colors.white),
            child: const Text('接入'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  打字动画
// ============================================================

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final opacity1 = (_ctrl.value < 0.33 || _ctrl.value > 0.66) ? 1.0 : 0.3;
        final opacity2 = (_ctrl.value >= 0.33 && _ctrl.value < 0.66) ? 1.0 : 0.3;
        final opacity3 = (_ctrl.value >= 0.66) ? 1.0 : 0.3;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(opacity1), const SizedBox(width: 4),
            _dot(opacity2), const SizedBox(width: 4),
            _dot(opacity3),
          ],
        );
      },
    );
  }

  Widget _dot(double opacity) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
