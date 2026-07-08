import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 新旅程选择页 —— 完成一段旅程后，温柔地问用户想怎么继续
class NewJourneyScreen extends StatelessWidget {
  final String lastRouteName;
  final String elephantName;

  const NewJourneyScreen({
    super.key,
    required this.lastRouteName,
    required this.elephantName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.bgWarm,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // 小象
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutBack,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: const Text('🐘', style: TextStyle(fontSize: 56)),
              ),

              const SizedBox(height: 24),

              // 提示文字
              Text(
                '你已经陪$elephantName走过了\n$lastRouteName',
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.6,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              const Text(
                '这次，你想选择哪段路？',
                style: TextStyle(
                  fontSize: 17,
                  height: 1.6,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // 三个选项卡片
              _OptionCard(
                emoji: '🌿',
                title: '继续探索',
                subtitle: '更深的整理',
                description: '走一段和上次相似的路，\n但这一次，看得更仔细一些。',
                onTap: () => Navigator.of(context).pop('continue'),
              ),

              const SizedBox(height: 14),

              _OptionCard(
                emoji: '🛤️',
                title: '换一段路',
                subtitle: '新的方向',
                description: '从另一座城市出发，\n走向另一个终点。风景不同，心事也不同。',
                onTap: () => Navigator.of(context).pop('new_route'),
              ),

              const SizedBox(height: 14),

              _OptionCard(
                emoji: '🔄',
                title: '再走一次同样的路',
                subtitle: '每一次走，感受都不同',
                description: '从南宁到桂林，同样的380公里。\n但你已经不是上次那个你了。',
                onTap: () => Navigator.of(context).pop('repeat'),
              ),

              const SizedBox(height: 32),

              // 底部取消
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text(
                  '还没想好，先不出发',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个选项卡片
class _OptionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final VoidCallback onTap;

  const _OptionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            // 左侧 emoji
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            // 右侧文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryWarm,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 20, color: AppTheme.dividerColor),
          ],
        ),
      ),
    );
  }
}
