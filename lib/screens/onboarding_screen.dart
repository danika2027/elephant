import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/journey_service.dart';
import '../models/route_info.dart';
import 'elephant_setup_screen.dart';
import 'safety_agreement_screen.dart';

/// 首次启动引导页
/// —— 温柔的开场，让用户选择出发日期
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final JourneyService _journeyService = JourneyService();
  late DateTime _selectedDate;
  String _selectedFrom = RouteRegistry.departureCities.first;
  String _selectedTo = RouteRegistry.destinationsFor(RouteRegistry.departureCities.first).first;
  late AnimationController _fadeController;
  late Animation<double> _fadeIn;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _startJourney() async {
    if (_saving) return;
    setState(() => _saving = true);

    await _journeyService.setStartDate(_selectedDate);
    final route = RouteRegistry.findPair(_selectedFrom, _selectedTo) ?? RouteRegistry.defaultRoute;
    await _journeyService.setRouteId(route.id);

    if (!mounted) return;
    setState(() => _saving = false);

    // 进入小象定制
    final profile = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(builder: (_) => const ElephantSetupScreen()),
    );

    if (!mounted) return;
    setState(() => _saving = true);

    // 心理安全约定（仅首次显示）
    final prefs = await SharedPreferences.getInstance();
    final hasSeenSafety = prefs.getBool('has_seen_safety_agreement') ?? false;
    if (!hasSeenSafety) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SafetyAgreementScreen()),
      );
      await prefs.setBool('has_seen_safety_agreement', true);
    }

    // 完成引导
    await _journeyService.completeOnboarding();

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _showPreviewSample() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.55,
        decoration: const BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // 拖拽指示器
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 标题
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    const Text('🐘', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('小象日记 · 样张预览',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryWarm.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('预览',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryWarm,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              // 样张日记内容
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // 旅程信息
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryWarm.withAlpha(12),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Row(
                        children: [
                          const Text('📅', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('南宁 → 桂林 · 10天旅程',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                              const SizedBox(height: 2),
                              Text('约380公里 · 每天3则日记',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary
                                          .withAlpha(200))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 样张卡片 - Day 4 晨间
                    _sampleCard(
                      emoji: '🌅',
                      label: '晨间出发',
                      location: '思陇镇·稻田边',
                      body: '早上踩到田埂上，差点滑进水田。\n\n我已经是一只成熟的小象了，不该犯这种错误。但我还是犯了。\n\n田里的鹭鸶看了我一眼，然后继续站在牛背上发呆。我突然想到一个问题：鹭鸶站在牛背上，那我可不可以让鹭鸶也站在我背上？\n\n下次问问它。',
                      signature: '——你的小象',
                    ),
                    const SizedBox(height: 8),
                    // 样张卡片 - Day 4 路途
                    _sampleCard(
                      emoji: '🚶',
                      label: '路途见闻',
                      location: '宾州镇·宾阳县城',
                      body: '到宾阳县城了！这里好热闹。\n\n我走在街上，有个小孩指着我说："妈妈你看，小象！"\n\n我很想跟他说：不是小象，是一头正在走向你的小象。\n\n宾阳的酸粉确实好吃。酸酸甜甜的，里面还有脆脆的东西。你在的城市有什么好吃的？等见面了你告诉我。',
                      signature: '——你的小象',
                    ),
                    const SizedBox(height: 16),
                    // 底部提示
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          '以上是第4天的样张。真实的旅程从南宁开始，\n每天3则，由小象亲"鼻"写成。',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary.withAlpha(180),
                              fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
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

  Widget _sampleCard({
    required String emoji,
    required String label,
    required String location,
    required String body,
    required String signature,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWarm,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryWarm,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(location,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Text(body,
              style: const TextStyle(
                  fontSize: 15,
                  height: 1.8,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(signature,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSelector() {
    // 当前选中的路线信息（如果存在）
    final route = RouteRegistry.findPair(_selectedFrom, _selectedTo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('🗺️ 选择路线',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 10),

        // 出发 → 到达
        Row(
          children: [
            Expanded(child: _cityPicker('📍 出发', _selectedFrom,
                RouteRegistry.departureCities, (v) {
              setState(() {
                _selectedFrom = v;
                // 切换出发城市时，自动选第一个可用目的地
                final dests = RouteRegistry.destinationsFor(v);
                if (!dests.contains(_selectedTo)) {
                  _selectedTo = dests.first;
                }
              });
            })),
            const SizedBox(width: 8),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryWarm.withAlpha(30),
              ),
              child: const Icon(Icons.arrow_forward, size: 16, color: AppTheme.primaryWarm),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: _cityPicker('🏁 到达', _selectedTo,
                    RouteRegistry.destinationsFor(_selectedFrom), (v) {
              setState(() => _selectedTo = v);
            })),
          ],
        ),

        // 路线详情（如果匹配到）
        if (route != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryWarm.withAlpha(15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              children: [
                const Text('🐘', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route.description,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3)),
                      const SizedBox(height: 3),
                      Text('${route.days}天 · ${route.distanceKm.toInt()}km',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryWarm)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _cityPicker(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return GestureDetector(
      onTap: () => _showCityPicker(label, value, options, onChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  void _showCityPicker(String title, String current, List<String> options, ValueChanged<String> onChanged) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.only(top: AppTheme.spacingMd),
        decoration: const BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.dividerColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: AppTheme.spacingMd),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: AppTheme.spacingSm),
              ...options.map((city) {
                final selected = city == current;
                return ListTile(
                  title: Text(city,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? AppTheme.primaryWarm : AppTheme.textPrimary)),
                  trailing: selected ? const Icon(Icons.check, color: AppTheme.primaryWarm) : null,
                  onTap: () {
                    onChanged(city);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: AppTheme.spacingMd),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 1)),
      helpText: '选择出发日期',
      cancelText: '取消',
      confirmText: '确定',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.primaryWarm,
              primary: AppTheme.primaryWarm,
              surface: AppTheme.cardBg,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    final dateLabel =
        '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日 ${weekDays[_selectedDate.weekday - 1]}';

    return Scaffold(
      backgroundColor: AppTheme.bgWarm,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
            child: Column(
              children: [
                const SizedBox(height: AppTheme.spacingXl),

                // 小象
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1.0),
                  duration: const Duration(milliseconds: 1600),
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: const Text('🐘', style: TextStyle(fontSize: 72)),
                ),

                const SizedBox(height: 20),

                // 标题
                const Text(
                  '有一头小象\n在走向你',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary, height: 1.4),
                ),

                const SizedBox(height: 12),

                // 副标题
                const Text(
                  '从南宁出发，一步一步走向你\n每天写来沿途的日记',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6),
                ),

                const SizedBox(height: AppTheme.spacingLg),

              // 日期选择
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📅', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      const Text(
                        '出发日期',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ---- 路线选择 ----
              _buildRouteSelector(),

              const SizedBox(height: 20),

              // 开始按钮
              SizedBox(
                width: 220,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _startJourney,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryWarm,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('🐘  开始旅程'),
                ),
              ),

              const SizedBox(height: AppTheme.spacingSm),

              Text(
                '让等待变成期待',
                style: Theme.of(context).textTheme.labelSmall,
              ),

              const SizedBox(height: AppTheme.spacingLg),

              // 样张预览入口
              GestureDetector(
                onTap: _showPreviewSample,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👀', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Text(
                        '先看看小象的日记',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
