import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 骨架屏加载卡片 —— 用于内容加载中的占位动画
class SkeletonCard extends StatefulWidget {
  final double height;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.height = 140,
    this.borderRadius = AppTheme.radiusMedium,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmer = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        final gradient = LinearGradient(
          begin: Alignment(-1.0 + _shimmer.value * 2, 0),
          end: Alignment(-0.5 + _shimmer.value * 2, 0),
          colors: const [
            Color(0xFFF0E8DC),
            Color(0xFFF8F2EB),
            Color(0xFFF0E8DC),
          ],
        );
        return Container(
          height: widget.height,
          margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: gradient,
          ),
        );
      },
    );
  }
}

/// 主页面骨架屏 —— 模拟完整的页面加载状态
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg,
        AppTheme.spacingMd,
        AppTheme.spacingLg,
        AppTheme.spacingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签模拟
          Container(
            width: 120,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8DC),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          // 标题模拟
          Container(
            width: 160,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8DC),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EFE5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          // 位置模拟
          Container(
            width: 260,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8DC),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          // 进度条模拟
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          // 三张骨架卡片
          const SkeletonCard(height: 150),
          const SizedBox(height: AppTheme.spacingSm),
          const SkeletonCard(height: 150),
          const SizedBox(height: AppTheme.spacingSm),
          const SkeletonCard(height: 150),
        ],
      ),
    );
  }
}
