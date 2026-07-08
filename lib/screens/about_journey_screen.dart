import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// 关于这段旅程 —— 背景理念 & 心理支持资源
class AboutJourneyScreen extends StatelessWidget {
  const AboutJourneyScreen({super.key});

  static const Color bgColor = Color(0xFFFFF8F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '关于这段旅程',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Column(
            children: [
              // 小象
              const Text('🐘', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 24),

              // 正文
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(180),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Text(
                  '这段10天的旅程，借鉴了"哀伤五阶段"和"正念自我关怀"的理念。'
                  '它不是治疗，而是一次有陪伴的自我整理。\n\n'
                  '每天，大象从南宁出发，一步步走向桂林——它走得很慢，'
                  '每走一步都会给你写一段日记。你可以把它看作一种节奏：'
                  '每天停下来几分钟，看看一头小象走到了哪里，'
                  '也看看自己走到了哪里。\n\n'
                  '如果你正在经历严重的情绪困扰，'
                  '建议同时寻求专业心理帮助。',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.8,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 心理援助热线按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _showHotlineDialog(context),
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: const Text('全国心理援助热线'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryWarm,
                    side: const BorderSide(color: AppTheme.primaryWarm),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 关闭按钮
              SizedBox(
                width: 200,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '我知道了',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showHotlineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Row(
          children: [
            Icon(Icons.phone_outlined,
                size: 20, color: AppTheme.primaryWarm),
            SizedBox(width: 8),
            Text(
              '心理援助热线',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _hotlineRow('希望24热线', '400-161-9995'),
            const SizedBox(height: 4),
            const Text(
              '（24小时·全国·免费）',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _hotlineRow('北京心理危机干预', '010-82951332'),
            const SizedBox(height: 12),
            _hotlineRow('上海心理援助', '021-12320-5'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(
                  const ClipboardData(text: '400-161-9995'));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('希望24热线已复制到剪贴板'),
                  duration: Duration(seconds: 2),
                  backgroundColor: AppTheme.primaryWarm,
                ),
              );
            },
            child: const Text('复制热线号码',
                style: TextStyle(color: AppTheme.primaryWarm)),
          ),
        ],
      ),
    );
  }

  Widget _hotlineRow(String name, String number) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          number,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryWarm,
          ),
        ),
      ],
    );
  }
}
