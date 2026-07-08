import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'theme/app_theme.dart';
import 'services/data_service.dart';
import 'services/journey_service.dart';
import 'services/notification_service.dart';
import 'services/elephant_service.dart';
import 'services/companion_service.dart';
import 'models/day_data.dart';
import 'models/elephant_profile.dart';
import 'models/route_info.dart';
import 'screens/onboarding_screen.dart';
import 'screens/elephant_setup_screen.dart';
import 'screens/about_journey_screen.dart';
import 'screens/new_journey_screen.dart';
import 'screens/map_screen.dart';
import 'widgets/message_card.dart';
import 'widgets/skeleton_card.dart';
import 'widgets/envelope_animation.dart';
import 'widgets/arrival_ceremony.dart';
import 'dart:async';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElephantApp());
}

// ============================================================
//  App 根节点
// ============================================================

class ElephantApp extends StatelessWidget {
  const ElephantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '有一头小象在走向你',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.materialTheme,
      home: const AppGate(),
      routes: {
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}

// ============================================================
//  启动闸门 —— 判断是否展示引导页
// ============================================================

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  final JourneyService _journeyService = JourneyService();
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final done = await _journeyService.hasOnboarded();
    if (!mounted) return;
    setState(() => _onboarded = done);
  }

  @override
  Widget build(BuildContext context) {
    // 检查中 → 极简闪屏
    if (_onboarded == null) {
      return Scaffold(
        backgroundColor: AppTheme.bgWarm,
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Opacity(opacity: value, child: child);
            },
            child: const Text('🐘', style: TextStyle(fontSize: 72)),
          ),
        ),
      );
    }

    // 首次启动 → 引导页
    if (!_onboarded!) return const OnboardingScreen();

    // 正常 → 主页
    return const HomeScreen();
  }
}

// ============================================================
//  主页面
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  final JourneyService _journeyService = JourneyService();
  final NotificationService _notificationService = NotificationService();
  final ElephantService _elephantService = ElephantService();
  final CompanionService _companionService = CompanionService();

  bool _loading = true;
  String? _error;
  List<DayData>? _allDays;
  int _currentDay = 1;
  int _totalDays = 10;
  bool _hasArrived = false;
  JourneyMeta? _meta;
  ElephantProfile _elephantProfile = ElephantProfile();

  // 每日状态
  bool _showEnvelope = false;
  String? _missedDayMessage;
  String _todayStr = '';
  bool _hasFedToday = false;
  bool _hasChattedToday = false;
  bool _isLastDay = false;
  bool _showArrival = false;
  String _arrivalQuote = '';
  int _unlockedCount = 0; // 今天已解锁消息数 0-3
  Timer? _arrivalTimer;

  // 陪伴模式
  int _daysSinceArrival = 0;
  ElephantMessage? _companionMessage;
  Map<String, String>? _journeyStats;

  late PageController _pageController;
  int _viewedDay = 1;
  bool _previewMode = false; // 预览模式：解锁所有天数

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // ---- 每日状态检测 ----
      final todayStr = _fmt(DateTime.now());
      _todayStr = todayStr;
      final lastOpened = await _journeyService.getLastOpenedDate();
      final alreadyRead = await _journeyService.hasReadToday(todayStr);
      final missed = await _journeyService.checkMissedYesterday();
      final fed = await _journeyService.hasFedToday(todayStr);
      final chatted = await _journeyService.hasChattedToday(todayStr);

      // 加载路线
      final routeId = await _journeyService.getRouteId();
      final route = RouteRegistry.find(routeId) ?? RouteRegistry.defaultRoute;

      final journey = await _dataService.loadByRoute(route);
      final profile = await _elephantService.loadProfile();
      // 个性化处理：{name} 替换、性格变体、心愿注入
      await _dataService.personalize(journey, profile);
      // 延迟事件处理
      await _processDelays(journey, profile);
      final td = await _journeyService.getTotalDays();
      final day = await _journeyService.getCurrentDay();
      final arrived = day > td;

      // 通知：一天三段，分段解锁
      await _notificationService.initialize();
      if (!arrived) {
        final unlocked = await _journeyService.getUnlockedCount(todayStr);
        if (await _journeyService.isLastDay()) {
          await _notificationService.scheduleLastDayMessage(elephantName: profile.name);
        } else {
          final dd = journey.days[day.clamp(1, journey.days.length) - 1];
          await _notificationService.scheduleDayMessages(
            elephantName: profile.name,
            morningLoc: dd.departure,
            journeyLoc: dd.destination,
            eveningLoc: dd.lodging.split('·').last.trim(),
          );
        }
        // 处理通知点击 → 解锁消息
        _notificationService.onNotificationTap = (int id) async {
          final newCount = await _journeyService.unlockNext(todayStr);
          if (mounted) setState(() => _unlockedCount = newCount);
        };
      } else {
        await _notificationService.cancelAll();
      }

      final unlocked = await _journeyService.getUnlockedCount(todayStr);

      // 错过昨天 → 生成道歉消息
      String? missedMsg;
      if (missed && day > 1) {
        missedMsg = '主人，你昨天没来看我。没关系，我知道你在忙。我昨天过得还不错……';
      }

      // 新的一天 → 标记已读 + 展示信封
      final isNewDay = lastOpened != todayStr;
      if (isNewDay) {
        await _journeyService.setLastOpenedDate(todayStr);
        await _journeyService.markReadToday(todayStr);
      }

      setState(() {
        _meta = journey.meta;
        _allDays = journey.days;
        _currentDay = day;
        _hasArrived = arrived;
        _elephantProfile = profile;
        _viewedDay = day.clamp(1, _allDays!.length);
        _totalDays = td;
        _missedDayMessage = missedMsg;
        _showEnvelope = isNewDay && !alreadyRead;
        _hasFedToday = fed;
        _hasChattedToday = chatted;
        _loading = false;
      });

      _pageController = PageController(initialPage: _viewedDay - 1);

      // ---- 陪伴模式加载 ----
      if (arrived) {
        // 首次到达 → 记录到达日期
        final existingArrival = await _journeyService.getArrivalDate();
        if (existingArrival == null) {
          await _journeyService.setArrivalDate(DateTime.now());
        }
        final daysSince = await _journeyService.getDaysSinceArrival();
        final companionMsg = _companionService.generateMessage(
          daysSinceArrival: daysSince,
          profile: profile,
        );
        final stats = _companionService.getJourneyStats(
          days: journey.days,
          meta: journey.meta,
        );
        setState(() {
          _daysSinceArrival = daysSince;
          _companionMessage = companionMsg;
          _journeyStats = stats;
        });
      }

      // ---- 最后一天逻辑 ----
      _isLastDay = await _journeyService.isLastDay();
      if (_isLastDay && !arrived) {
        // 加载性格金句
        final quote = await _pickArrivalQuote(profile.personality);
        final now = DateTime.now();
        final arrivalTime = DateTime(now.year, now.month, now.day, 18, 0);
        final alreadyShown = await _journeyService.hasShownArrivalCeremony();

        if (!alreadyShown) {
          if (now.isAfter(arrivalTime) || now.isAtSameMomentAs(arrivalTime)) {
            // 已经过了 18:00 → 直接展示
            if (mounted) {
              setState(() {
                _arrivalQuote = quote;
                _showArrival = true;
              });
            }
          } else {
            // 还没到 18:00 → 设定时器
            final delay = arrivalTime.difference(now);
            _arrivalTimer = Timer(delay, () {
              if (mounted) {
                setState(() {
                  _arrivalQuote = quote;
                  _showArrival = true;
                });
              }
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _arrivalTimer?.cancel();
    if (_loading == false) _pageController.dispose();
    super.dispose();
  }

  Future<String> _pickArrivalQuote(String personality) async {
    try {
      final str = await rootBundle.loadString('assets/data/arrival_quotes.json');
      final map = jsonDecode(str) as Map<String, dynamic>;
      final quotes = (map[personality] as List<dynamic>?) ?? [];
      if (quotes.isEmpty) return '终于到了。这一路走了很久，但很值。';
      final idx = DateTime.now().millisecondsSinceEpoch % quotes.length;
      return quotes[idx] as String;
    } catch (_) {
      return '终于到了。这一路走了很久，但很值。';
    }
  }

  // ==========================================================
  //  Build
  // ==========================================================

  bool get _inCompanionMode =>
      (_hasArrived || _previewMode) && _viewedDay == _allDays!.length;

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoadingScreen();
    if (_error != null) return _buildErrorScreen();

    final viewedDayData = _allDays![_viewedDay - 1];
    final companion = _inCompanionMode;

    return Scaffold(
      backgroundColor: AppTheme.bgWarm,
      body: SafeArea(
        child: Stack(
          children: [
            // 主页面
            Column(
              children: [
                _buildHeader(viewedDayData),
                const SizedBox(height: AppTheme.spacingSm),
                _buildProgressBar(),
                const SizedBox(height: AppTheme.spacingSm),
                if (companion)
                  _buildCompanionStats()
                else
                  _buildDayNavigation(),
                const SizedBox(height: AppTheme.spacingMd),
                Expanded(
                  child: companion
                      ? _buildCompanionContent()
                      : PageView.builder(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          itemCount: _allDays!.length,
                          itemBuilder: (context, index) {
                            final day = index + 1;
                            if (day > _currentDay &&
                                !_hasArrived &&
                                !_previewMode) {
                              return _buildLockedDay(day);
                            }
                            return _buildDayContent(_allDays![index]);
                          },
                        ),
                ),
                if (companion)
                  _buildCompanionButtons(viewedDayData)
                else
                  _buildBottomButton(viewedDayData),
              ],
            ),

            // 信封动画覆盖层
            if (_showEnvelope)
              EnvelopeAnimation(
                day: _currentDay,
                location: _allDays![_currentDay - 1].destination,
                dateLabel: _dateLabel(DateTime.now()),
                onComplete: _onEnvelopeDone,
              ),

            // 到达仪式覆盖层
            if (_showArrival && _allDays != null)
              ArrivalCeremony(
                profile: _elephantProfile,
                allDays: _allDays!,
                quote: _arrivalQuote,
                onComplete: () {
                  _journeyService.markArrivalCeremonyShown();
                  setState(() => _showArrival = false);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  //  加载 / 错误 / 骨架屏
  // ==========================================================

  // ==========================================================
  //  陪伴模式组件
  // ==========================================================

  void _showShareSheet(DayData dayData) {
    // 取当天的第一条消息作为分享文案
    final firstMsg = dayData.messages.isNotEmpty
        ? dayData.messages.first.content
            .replaceAll('\n\n', '\n')
            .split('\n')
            .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
        : '';
    // 截取前60字
    final quote = firstMsg.length > 60
        ? '${firstMsg.substring(0, 60)}…'
        : firstMsg;

    final dayLabel = _hasArrived && _viewedDay == _allDays!.length
        ? '已完成全部旅程 ✨'
        : '第 ${dayData.day} 天 · ${dayData.destination}';
    final shareText = '🐘 有一头小象在走向你\n\n'
        '$dayLabel\n'
        '"$quote"\n'
        '——你的${_elephantProfile.name}\n\n'
        '从南宁到桂林，一头小象每天都在走向你。\n'
        '试试看：https://danika2027.github.io/elephant-diary/';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽条
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 分享卡片预览
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.bgWarm,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Column(
                  children: [
                    const Text('🐘', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    const Text('有一头小象在走向你',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(dayLabel,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.primaryWarm)),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity, height: 1,
                      color: AppTheme.dividerColor,
                    ),
                    const SizedBox(height: 12),
                    Text('"$quote"',
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('——你的${_elephantProfile.name}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic)),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryWarm.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'danika2027.github.io/elephant-diary',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryWarm),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 复制按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // 用 Clipboard API（Web）/ Clipboard（移动端）
                    _copyToClipboard(shareText);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('分享文案已复制，去小红书/朋友圈粘贴吧 ✨'),
                        duration: Duration(seconds: 2),
                        backgroundColor: AppTheme.primaryWarm,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('复制分享文案'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryWarm,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  void _jumpToCompanionPreview() {
    if (_allDays == null || _allDays!.isEmpty) return;
    setState(() {
      _previewMode = true;
      _viewedDay = _allDays!.length;
    });
  }

  Widget _buildCompanionStats() {
    // 即时生成统计数据（兼容预览模式）
    final stats = _journeyStats ??
        _companionService.getJourneyStats(
          days: _allDays!,
          meta: _meta!,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.primaryWarm.withAlpha(18),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.primaryWarm.withAlpha(50)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('📅', stats['totalDays']!, '旅程'),
            Container(width: 1, height: 24,
                color: AppTheme.primaryWarm.withAlpha(40)),
            _statItem('🛤️', stats['totalKm']!, '里程'),
            Container(width: 1, height: 24,
                color: AppTheme.primaryWarm.withAlpha(40)),
            _statItem('📍', stats['places']!, '驻足'),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String emoji, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildCompanionContent() {
    // 即时生成陪伴消息（兼容预览模式 + 真实到达）
    final msg = _companionMessage ??
        _companionService.generateMessage(
          daysSinceArrival: _daysSinceArrival < 1 ? 1 : _daysSinceArrival,
          profile: _elephantProfile,
        );
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      physics: const BouncingScrollPhysics(),
      children: [
        // 陪伴标题
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
          child: Row(
            children: [
              Text('💛',
                  style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.primaryWarm.withAlpha(200))),
              const SizedBox(width: 6),
              Text(
                _daysSinceArrival == 1 ? '今天开始，我留下来陪你' : '陪你第 $_daysSinceArrival 天',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        // 陪伴消息卡片
        AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 400),
          child: AnimatedSlide(
            offset: Offset.zero,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: ElephantMessageCard(message: msg, showDivider: false),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Center(
          child: Text(
            '明天再来，{name}还会给你写新的消息。'
                .replaceAll('{name}', _elephantProfile.name),
            style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppTheme.spacingLg),
      ],
    );
  }

  Widget _buildCompanionButtons(DayData dayData) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg, AppTheme.spacingSm, AppTheme.spacingLg, AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgWarm,
        boxShadow: [
          BoxShadow(
            color: AppTheme.dividerColor.withAlpha(100),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 主按钮行
          Row(
            children: [
              Expanded(
                child: _outlinedButton('📖 回忆旅程', () {
                  setState(() {
                    _previewMode = true;
                    _viewedDay = 1;
                  });
                  // PageView 重建后再跳转
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _pageController.jumpToPage(0);
                  });
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _outlinedButton('🗺️ 回顾路线', () => _openMap(dayData)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 新旅程按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _startNewJourney,
              icon: const Text('🐘', style: TextStyle(fontSize: 20)),
              label: const Text('开启新旅程'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryWarm,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlinedButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Center(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary)),
        ),
      ),
    );
  }

  Future<void> _startNewJourney() async {
    // 获取上一次路线名称
    final lastRouteId = await _journeyService.getRouteId();
    final lastRoute =
        RouteRegistry.find(lastRouteId) ?? RouteRegistry.defaultRoute;

    if (!mounted) return;

    // 显示三选一过渡页
    final choice = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => NewJourneyScreen(
          lastRouteName: lastRoute.name,
          elephantName: _elephantProfile.name,
        ),
      ),
    );

    if (choice == null || !mounted) return; // 用户取消

    await _journeyService.resetJourney();
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppTheme.bgWarm,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingLg,
                AppTheme.spacingMd,
                AppTheme.spacingLg,
                0,
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: const Text('🐘', style: TextStyle(fontSize: 20)),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '有一头小象在走向你',
                    style: TextStyle(
                      color: AppTheme.primaryWarm,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            const Expanded(child: HomeSkeleton()),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: AppTheme.bgWarm,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('😶', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text('加载失败: $_error',
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _initApp();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryWarm,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                ),
                child: const Text('再试一次'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  固定头部
  // ==========================================================

  Widget _buildHeader(DayData dayData) {
    final now = DateTime.now();
    final weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dateStr =
        '${now.year}年${now.month}月${now.day}日 ${weekDays[now.weekday - 1]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg,
        AppTheme.spacingMd,
        AppTheme.spacingLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onLongPress: _jumpToCompanionPreview,
                child: Hero(
                  tag: 'elephant',
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: const Text('🐘', style: TextStyle(fontSize: 18)),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _meta?.title ?? '',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.primaryWarm,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const AboutJourneyScreen()),
                ),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.textSecondary.withAlpha(25),
                  ),
                  child: const Icon(Icons.help_outline,
                      size: 16, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showShareSheet(dayData),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryWarm.withAlpha(25),
                  ),
                  child: const Icon(Icons.ios_share,
                      size: 16, color: AppTheme.primaryWarm),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _hasArrived && _viewedDay == _allDays!.length
                  ? '${_elephantProfile.name}在你身边 💛'
                  : '第 $_viewedDay 天',
              key: ValueKey('day_$_viewedDay'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(dateStr, style: Theme.of(context).textTheme.bodyMedium),
              if ((_hasArrived || _previewMode) &&
                  _viewedDay == _allDays!.length) ...[
                const SizedBox(width: 8),
                Text(
                  _hasArrived ? '· 已陪伴 $_daysSinceArrival 天' : '· 预览模式',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryWarm,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Row(
              key: ValueKey('loc_$_viewedDay'),
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: AppTheme.primaryWarm),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dayData.destination,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${dayData.distance} · 累计 ${_meta?.totalDistanceKm.toInt() ?? 0}km',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  //  进度条 + 日期导航
  // ==========================================================

  Widget _buildProgressBar() {
    final viewedProgress = (_hasArrived && _viewedDay == _totalDays)
        ? 1.0
        : (_viewedDay / _totalDays);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('南宁', style: Theme.of(context).textTheme.labelSmall),
              Text(
                '${(viewedProgress * 100).toInt()}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.primaryWarm, fontWeight: FontWeight.w600),
              ),
              Text('桂林', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: viewedProgress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: AppTheme.dividerColor,
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.mapRouteColor),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _navArrow(Icons.chevron_left,
              _viewedDay > 1 ? () => _goToDay(_viewedDay - 1) : null),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Text(
              '${_viewedDay < 10 ? "0$_viewedDay" : _viewedDay} / $_totalDays 天',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          _navArrow(
            Icons.chevron_right,
            (_viewedDay < _totalDays &&
                    (_viewedDay < _currentDay || _hasArrived || _previewMode))
                ? () => _goToDay(_viewedDay + 1)
                : null,
          ),
          // 预览模式开关
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => setState(() => _previewMode = !_previewMode),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _previewMode
                    ? AppTheme.primaryWarm.withAlpha(40)
                    : Colors.transparent,
                border: Border.all(
                  color: _previewMode ? AppTheme.primaryWarm : AppTheme.dividerColor,
                ),
              ),
              child: Icon(
                _previewMode ? Icons.visibility : Icons.visibility_off_outlined,
                size: 16,
                color: _previewMode ? AppTheme.primaryWarm : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navArrow(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? AppTheme.primaryWarm.withAlpha(30)
              : AppTheme.dividerColor.withAlpha(60),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled ? AppTheme.primaryWarm : AppTheme.textSecondary),
      ),
    );
  }

  void _goToDay(int day) {
    _pageController.animateToPage(day - 1,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  // ==========================================================
  //  PageView 内容
  // ==========================================================

  Widget _buildDayContent(DayData dayData) {
    final showMissed = dayData.day == _currentDay && _missedDayMessage != null;
    // 当天日记按解锁数分段显示；非当天直接全显示
    final unlocked = (dayData.day == _currentDay) ? _unlockedCount : dayData.messages.length;
    return _AnimatedMessagesList(
      dayData: dayData,
      missedMessage: showMissed ? _missedDayMessage : null,
      unlockedCount: unlocked,
      key: ValueKey('content_${dayData.day}'),
    );
  }

  Widget _buildLockedDay(int day) {
    final dayData = _allDays![day - 1];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.92, end: 1.0),
              duration: const Duration(milliseconds: 2000),
              builder: (context, value, child) =>
                  Opacity(opacity: value, child: child),
              child: const Text('🐘💭', style: TextStyle(fontSize: 64)),
            ),
            const SizedBox(height: 20),
            Text('第 $day 天',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('小象还在路上，\n还没走到${dayData.destination}呢',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('明天再来看看吧',
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  void _onPageChanged(int index) {
    final newDay = index + 1;
    if (newDay == _viewedDay) return;
    setState(() => _viewedDay = newDay);
  }

  // ==========================================================
  //  底部按钮（带页面过渡动画）
  // ==========================================================

  Widget _buildBottomButton(DayData dayData) {
    // 最后一天 → 脉动蹄印
    if (_isLastDay) {
      return _buildHoofPrint();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg, AppTheme.spacingSm, AppTheme.spacingLg, AppTheme.spacingLg,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgWarm,
        boxShadow: [
          BoxShadow(
            color: AppTheme.dividerColor.withAlpha(100),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _openMap(dayData),
          icon: const Text('🗺️', style: TextStyle(fontSize: 20)),
          label: Text('查看第$_viewedDay天地图'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryWarm,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _dateLabel(DateTime d) {
    final weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return '${d.year}年${d.month}月${d.day}日 ${weekDays[d.weekday - 1]}';
  }

  void _onEnvelopeDone() {
    if (mounted) setState(() => _showEnvelope = false);
  }

  Future<void> _processDelays(JourneyData journey, ElephantProfile profile) async {
    // 已经触发过延迟 → 不再重复判定
    final existingDelay = await _journeyService.getDelayedDay();
    if (existingDelay != null) return;

    // 检查有 delayProbability 的天数
    for (final dayData in journey.days) {
      final raw = dayData.rawJson;
      if (raw == null) continue;
      final baseProb = (raw['delayProbability'] as num?)?.toDouble();
      if (baseProb == null) continue;

      final mods = raw['delayPersonalityMod'] as Map<String, dynamic>?;
      final mod = (mods?[profile.personality] as num?)?.toDouble() ?? 1.0;
      final chance = (baseProb * mod).clamp(0.0, 1.0);

      // 随机判定
      final roll = DateTime.now().millisecondsSinceEpoch % 100 / 100.0;
      if (roll < chance) {
        // 触发延迟！
        final delayContent = await _dataService.getDelayContent(dayData.day, profile);
        if (delayContent == null) continue;

        await _journeyService.setDelayedDay(dayData.day);
        await _journeyService.setTotalDays(11);

        // 插入延迟消息
        final delayMsg = ElephantMessage(
          type: 'delay',
          timeOfDay: '路途意外',
          location: dayData.destination,
          content: delayContent,
          signature: '——你的${profile.name}',
        );
        dayData.messages.insert(1, delayMsg);

        // 后续所有天数的 day 字段 +1
        for (final d in journey.days) {
          if (d.day > dayData.day) d.shiftDay();
        }
        break; // 只触发一次延迟
      }
    }
  }

  Widget _buildHoofPrint() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg, AppTheme.spacingSm, AppTheme.spacingLg, AppTheme.spacingLg,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgWarm,
        boxShadow: [
          BoxShadow(
            color: AppTheme.dividerColor.withAlpha(100),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 1.15),
            duration: const Duration(milliseconds: 1200),
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            onEnd: () {},
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryWarm.withAlpha(30),
              ),
              child: const Center(
                child: Text('🐾', style: TextStyle(fontSize: 36)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '小象在专注走最后一段路',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            '距离到达还剩不到一天',
            style: TextStyle(fontSize: 12, color: AppTheme.primaryWarm.withAlpha(180)),
          ),
        ],
      ),
    );
  }

  /// 自定义页面过渡动画：地图页从下方滑入
  void _openMap(DayData dayData) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, animation, __) => MapScreen(
          allDays: _allDays!,
          currentDay: _viewedDay,
          hasArrived: _hasArrived,
          totalDays: _totalDays,
          profile: _elephantProfile,
          hasFedToday: _hasFedToday,
          hasChattedToday: _hasChattedToday,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0, 0.6, curve: Curves.easeOut),
              ),
              child: child,
            ),
          );
        },
      ),
    );
    // 从地图返回后刷新交互状态
    final todayStr = _todayStr;
    final fed = await _journeyService.hasFedToday(todayStr);
    final chatted = await _journeyService.hasChattedToday(todayStr);
    if (mounted) {
      setState(() {
        _hasFedToday = fed;
        _hasChattedToday = chatted;
      });
    }
  }
}

// ============================================================
//  带动画的消息列表
// ============================================================

class _AnimatedMessagesList extends StatefulWidget {
  final DayData dayData;
  final String? missedMessage;
  final int unlockedCount;
  const _AnimatedMessagesList({super.key, required this.dayData, this.missedMessage, this.unlockedCount = 3});

  @override
  State<_AnimatedMessagesList> createState() => _AnimatedMessagesListState();
}

class _AnimatedMessagesListState extends State<_AnimatedMessagesList> {
  int _revealed = 0;

  @override
  void initState() {
    super.initState();
    _animate();
  }

  @override
  void didUpdateWidget(covariant _AnimatedMessagesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayData.day != widget.dayData.day) {
      _revealed = 0;
      _animate();
    }
  }

  void _animate() {
    for (int i = 1; i <= widget.dayData.messages.length; i++) {
      Future.delayed(Duration(milliseconds: 180 * i), () {
        if (mounted) setState(() => _revealed = i);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgs = widget.dayData.messages;
    final showArrivalBanner = widget.dayData.day == 10;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      physics: const BouncingScrollPhysics(),
      children: [
        // 错过消息卡片
        if (widget.missedMessage != null) ...[
          _MissedDayCard(message: widget.missedMessage!),
          const SizedBox(height: AppTheme.spacingMd),
        ],
        if (showArrivalBanner) ...[
          _ArrivalBanner(visible: _revealed >= 1),
          const SizedBox(height: AppTheme.spacingMd),
        ],
        for (int i = 0; i < msgs.length; i++) ...[
          if (i < widget.unlockedCount)
            _MessageEntry(
              message: msgs[i],
              visible: i < _revealed,
              delayIndex: i,
            )
          else
            _LockedMessage(
              index: i,
              visible: i < _revealed,
              delayIndex: i,
            ),
          if (i < msgs.length - 1)
            const SizedBox(height: AppTheme.spacingSm),
        ],
        const SizedBox(height: AppTheme.spacingXl),
        Center(
          child: _revealed >= 3
              ? AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    widget.dayData.day == 10
                        ? '小象已经到了。但你可以随时回来看它。'
                        : '明天这个时候，小象会在路上给你写新的日记。',
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: AppTheme.spacingLg),
      ],
    );
  }
}

// ============================================================
//  消息入场动画
// ============================================================

class _MessageEntry extends StatelessWidget {
  final ElephantMessage message;
  final bool visible;
  final int delayIndex;

  const _MessageEntry({
    required this.message,
    required this.visible,
    required this.delayIndex,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        child: ElephantMessageCard(message: message, showDivider: true),
      ),
    );
  }
}

// ============================================================
//  错过消息卡片
// ============================================================

class _MissedDayCard extends StatelessWidget {
  final String message;
  const _MissedDayCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryWarm.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryWarm.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Text('💌', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  未解锁消息占位
// ============================================================

class _LockedMessage extends StatelessWidget {
  final int index;
  final bool visible;
  final int delayIndex;

  const _LockedMessage({
    required this.index,
    required this.visible,
    required this.delayIndex,
  });

  @override
  Widget build(BuildContext context) {
    final labels = ['晨间出发', '路途见闻', '傍晚安顿'];
    final emojis = ['🌅', '🚶', '🌙'];
    final label = index < labels.length ? labels[index] : '日记';
    final emoji = index < emojis.length ? emojis[index] : '📝';

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: Duration(milliseconds: 400 + delayIndex * 80),
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.08),
        duration: Duration(milliseconds: 400 + delayIndex * 80),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.dividerColor.withAlpha(40),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.dividerColor.withAlpha(80),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label · 待到达',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '小象还在赶路，这篇日记还没写完…',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  到达横幅
// ============================================================

class _ArrivalBanner extends StatelessWidget {
  final bool visible;
  const _ArrivalBanner({required this.visible});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -0.1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.primaryWarm.withAlpha(25),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.primaryWarm.withAlpha(80)),
          ),
          child: Row(
            children: [
              const Text('🐘', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('小象已经到啦！',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                                color: AppTheme.primaryWarm,
                                fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('这是它抵达那天写给你的日记。',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
