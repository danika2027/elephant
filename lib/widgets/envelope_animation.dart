import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 全屏拆信动画 —— 点击拆开后播放 3.5 秒不可跳过
class EnvelopeAnimation extends StatefulWidget {
  final int day;
  final String location;
  final String dateLabel;
  final VoidCallback onComplete;

  const EnvelopeAnimation({
    super.key,
    required this.day,
    required this.location,
    required this.dateLabel,
    required this.onComplete,
  });

  @override
  State<EnvelopeAnimation> createState() => _EnvelopeAnimationState();
}

class _EnvelopeAnimationState extends State<EnvelopeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // 三阶段区间
  static const _riseEnd = 0.26; // 0–26% 信封升起
  static const _openEnd = 0.57; // 26–57% 信纸展开
  // 57–100% 文字淡入

  late Animation<double> _rise;
  late Animation<double> _open;
  late Animation<double> _textFade;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _rise = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, _riseEnd, curve: Curves.easeOutBack),
      ),
    );

    _open = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(_riseEnd, _openEnd, curve: Curves.easeInOut),
      ),
    );

    _textFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(_openEnd, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  void _startAnimation() {
    setState(() => _started = true);
    _ctrl.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return _buildClosed();
    }
    return IgnorePointer(
      child: Container(
        color: AppTheme.bgWarm,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 信纸展开
            AnimatedBuilder(
              animation: _open,
              builder: (context, _) {
                return Opacity(
                  opacity: _open.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.7 + (_open.value * 0.3).clamp(0.0, 0.3),
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.dividerColor.withAlpha(120),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _textFade,
                        builder: (context, _) => _buildLetter(),
                      ),
                    ),
                  ),
                );
              },
            ),

            // 信封升起后淡出
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final t = _ctrl.value;
                final yOffset = (1 - _rise.value) * 300;
                final scale = 0.6 + _rise.value * 0.4;
                double opacity;
                if (t < _riseEnd) {
                  opacity = (t / _riseEnd).clamp(0.0, 1.0);
                } else if (t < _openEnd) {
                  opacity = 1.0 - ((t - _riseEnd) / (_openEnd - _riseEnd)).clamp(0.0, 1.0);
                } else {
                  opacity = 0.0;
                }
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, yOffset),
                    child: Transform.scale(
                      scale: scale,
                      child: const Text('✉️', style: TextStyle(fontSize: 80)),
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

  // ---- 未拆开状态：仪式感等待 ----

  Widget _buildClosed() {
    return GestureDetector(
      onTap: _startAnimation,
      child: Container(
        color: AppTheme.bgWarm,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 信封呼吸动画
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 1.05),
                  duration: const Duration(milliseconds: 1800),
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  onEnd: () {},
                  child: const Text('💌', style: TextStyle(fontSize: 72)),
                ),
                const SizedBox(height: 20),
                const Text(
                  '一封来自小象的信',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.dateLabel} · 第${widget.day}天',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryWarm,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    '👆 点击拆开',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLetter() {
    final dayStr = widget.day < 10 ? '第0${widget.day}天' : '第${widget.day}天';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: _textFade.value,
          child: Text(
            dayStr,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryWarm,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: (_textFade.value - 0.15).clamp(0.0, 1.0),
          child: Text(
            widget.dateLabel,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Opacity(
          opacity: (_textFade.value - 0.30).clamp(0.0, 1.0),
          child: Text(
            '📍 ${widget.location}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Opacity(
          opacity: (_textFade.value - 0.45).clamp(0.0, 1.0),
          child: Container(
            width: 40,
            height: 1,
            color: AppTheme.dividerColor,
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: (_textFade.value - 0.55).clamp(0.0, 1.0),
          child: const Text(
            '——你的小象',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
