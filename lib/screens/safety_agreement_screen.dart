import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'about_journey_screen.dart';

/// 心理安全约定页
/// —— 在旅程正式开始前，给用户一个温柔的承诺
class SafetyAgreementScreen extends StatelessWidget {
  const SafetyAgreementScreen({super.key});

  static const Color bgColor = Color(0xFFFFF8F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 小象图标
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: const Text('🐘', style: TextStyle(fontSize: 64)),
                ),

                const SizedBox(height: 28),

                // 标题
                const Text(
                  '我们之间的约定',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 36),

                // 四条约定
                ..._agreements.map((item) => _AgreementRow(text: item)),

                const SizedBox(height: 40),

                // 底部小字
                const Text(
                  '如果过程中有任何不舒服，随时可以离开',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                // "我准备好了" 按钮
                SizedBox(
                  width: 220,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryWarm,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('我准备好了'),
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
        // 右上角问号入口
        Positioned(
          top: 4,
          right: 12,
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const AboutJourneyScreen()),
            ),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryWarm.withAlpha(20),
              ),
              child: const Icon(Icons.help_outline,
                  size: 18, color: AppTheme.primaryWarm),
            ),
          ),
        ),
      ],
    ),
    ),
    );
  }
}

/// 单条约定行
class _AgreementRow extends StatelessWidget {
  final String text;
  const _AgreementRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 圆点装饰
          Container(
            margin: const EdgeInsets.only(top: 6, right: 14),
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: AppTheme.primaryWarm.withAlpha(180),
              shape: BoxShape.circle,
            ),
          ),
          // 约定文字
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 四条约定的文案
const _agreements = [
  '这里发生的一切，只留在你的手机里',
  '没有评判，没有建议，没有"你应该"',
  '你可以随时停下来，不需要任何理由',
  '大象只是陪着你，它不会催促你',
];
