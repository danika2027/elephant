import 'package:flutter/material.dart';
import '../models/day_data.dart';
import '../theme/app_theme.dart';

/// 小象消息卡片 —— 可复用的日记消息展示组件
class ElephantMessageCard extends StatelessWidget {
  final ElephantMessage message;
  final bool showDivider;

  const ElephantMessageCard({
    super.key,
    required this.message,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签行
          Row(
            children: [
              Text(
                _timeIcon,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                message.timeOfDay,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.primaryWarm,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                message.location,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 日记正文
          Text(
            message.content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 6),
          // 落款
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              message.signature,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          if (showDivider) ...[
            const SizedBox(height: 12),
            Divider(color: AppTheme.dividerColor.withAlpha(128)),
          ],
        ],
      ),
    );
  }

  String get _timeIcon => switch (message.type) {
        'morning' => '🌅',
        'journey' => '🚶',
        'evening' => '🌙',
        _ => '📍',
      };
}
