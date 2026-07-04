import 'package:flutter/material.dart';
import '../models/day_data.dart';
import '../models/elephant_profile.dart';
import '../theme/app_theme.dart';

/// 到达仪式 —— 全屏卡片 + 3-2-1 倒计时 + 象鸣
class ArrivalCeremony extends StatefulWidget {
  final ElephantProfile profile;
  final List<DayData> allDays;
  final String quote;
  final VoidCallback onComplete;

  const ArrivalCeremony({
    super.key,
    required this.profile,
    required this.allDays,
    required this.quote,
    required this.onComplete,
  });

  @override
  State<ArrivalCeremony> createState() => _ArrivalCeremonyState();
}

class _ArrivalCeremonyState extends State<ArrivalCeremony>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _phase = 0; // 0=卡片展示, 1=3, 2=2, 3=1, 4=最终文字

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _playSound();
    Future.delayed(const Duration(seconds: 2), _startCountdown);
  }

  void _playSound() {
    // audioplayers 在 Web 上受限，跳过音效
  }

  void _startCountdown() {
    if (!mounted) return;
    setState(() => _phase = 1); // 3
    _ctrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() => _phase = 2); // 2
      _ctrl.forward(from: 0).then((_) {
        if (!mounted) return;
        setState(() => _phase = 3); // 1
        _ctrl.forward(from: 0).then((_) {
          if (!mounted) return;
          setState(() => _phase = 4); // 最终文字
          _ctrl.forward(from: 0);
        });
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // 统计
  int get _totalKm {
    double sum = 0;
    for (final d in widget.allDays) {
      final num = d.distance.replaceAll(RegExp(r'[^0-9.]'), '');
      sum += double.tryParse(num) ?? 30;
    }
    return sum.round();
  }

  int get _townCount {
    final towns = <String>{};
    for (final d in widget.allDays) {
      towns.add(d.departure);
      towns.add(d.destination);
    }
    return towns.length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bgWarm,
      child: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 倒计时数字（3-2-1）
            if (_phase >= 1 && _phase <= 3)
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final numbers = ['3', '2', '1'];
                  final num = numbers[_phase - 1];
                  return Opacity(
                    opacity: 1.0 - _ctrl.value,
                    child: Transform.scale(
                      scale: 1.0 + _ctrl.value * 3.0,
                      child: Text(
                        num,
                        style: TextStyle(
                          fontSize: 140,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryWarm.withAlpha((255 * (1 - _ctrl.value)).toInt()),
                          height: 1,
                        ),
                      ),
                    ),
                  );
                },
              ),

            // 主卡片
            if (_phase == 0)
              _buildCard(),

            // 最终文字
            if (_phase == 4)
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  return Opacity(
                    opacity: _ctrl.value,
                    child: Transform.scale(
                      scale: 0.8 + _ctrl.value * 0.2,
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingLg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🐘', style: TextStyle(fontSize: 80)),
                            const SizedBox(height: 24),
                            const Text(
                              '这头小象，\n现在正式属于你。',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: 200,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: widget.onComplete,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryWarm,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: const Text('嗯，我的小象',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    final name = widget.profile.name;
    final label = widget.profile.personalityLabel;
    final emoji = widget.profile.accessoryEmoji;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🐘$emoji', style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            '$name 到了',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '一头$label小象，走到了你面前',
            style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          // 统计
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat('${widget.allDays.length}', '天旅程'),
                _stat('${_totalKm}', '公里'),
                _stat('${_townCount}', '个城镇'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 性格金句
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryWarm.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '「${widget.quote}」',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimary,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            '等待倒计时',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withAlpha(150)),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.primaryWarm)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}
