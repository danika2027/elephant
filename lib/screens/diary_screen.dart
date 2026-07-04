import 'package:flutter/material.dart';
import '../models/day_data.dart';
import '../theme/app_theme.dart';

/// 日记详情页 —— 一天的完整内容
class DiaryScreen extends StatelessWidget {
  final DayData dayData;

  const DiaryScreen({super.key, required this.dayData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('第${dayData.day}天 · ${dayData.destination}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          _RouteHeader(dayData: dayData),
          const SizedBox(height: AppTheme.spacingLg),
          _MapPlaceholder(dayData: dayData),
          const SizedBox(height: AppTheme.spacingLg),
          ...dayData.messages.map((msg) => _MessageCard(message: msg)),
        ],
      ),
    );
  }
}

class _RouteHeader extends StatelessWidget {
  final DayData dayData;
  const _RouteHeader({required this.dayData});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            const Text('🐘', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${dayData.departure} → ${dayData.destination}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dayData.date} · ${dayData.distance}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  final DayData dayData;
  const _MapPlaceholder({required this.dayData});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.dividerColor.withAlpha(80),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗺️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              '${dayData.startCoord.lat.toStringAsFixed(4)}, ${dayData.startCoord.lng.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const Text('↓', style: TextStyle(fontSize: 12)),
            Text(
              '${dayData.endCoord.lat.toStringAsFixed(4)}, ${dayData.endCoord.lng.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final ElephantMessage message;
  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final isLast = message.type == 'evening';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TimeIcon(type: message.type),
              const SizedBox(width: 6),
              Text(
                message.timeOfDay,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.primaryWarm,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              Text(message.location, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(message.content, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              message.signature,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          if (!isLast) ...[
            const SizedBox(height: 12),
            Divider(color: AppTheme.dividerColor.withAlpha(128)),
          ],
        ],
      ),
    );
  }
}

class _TimeIcon extends StatelessWidget {
  final String type;
  const _TimeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    return Text(
      switch (type) {
        'morning' => '🌅',
        'journey' => '🚶',
        'evening' => '🌙',
        _ => '📍',
      },
      style: const TextStyle(fontSize: 16),
    );
  }
}
