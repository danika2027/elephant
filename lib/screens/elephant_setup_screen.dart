import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/elephant_profile.dart';
import '../services/elephant_service.dart';

/// 小象定制页 —— 选性格、配外观、起名字
class ElephantSetupScreen extends StatefulWidget {
  const ElephantSetupScreen({super.key});

  @override
  State<ElephantSetupScreen> createState() => _ElephantSetupScreenState();
}

class _ElephantSetupScreenState extends State<ElephantSetupScreen> {
  final ElephantService _elephantService = ElephantService();

  int _step = 0; // 0=性格, 1=外观, 2=名字

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await _elephantService.loadProfile();
    _nameCtrl.text = p.name;
    _wishCtrl.text = p.wish;
    _personality = p.personality;
    _accessory = p.accessory;
    _colorName = p.colorName;
    if (mounted) setState(() {});
  }
  String _personality = 'gentle';
  String _accessory = 'none';
  String _colorName = '暖灰';
  final TextEditingController _nameCtrl = TextEditingController(text: '小象');
  final TextEditingController _wishCtrl = TextEditingController();
  bool _saving = false;

  static const _personalities = [
    {'id': 'gentle', 'label': '温柔型', 'emoji': '🌸', 'desc': '走得慢，但每一步都稳。\n喜欢在路边停下来看花。'},
    {'id': 'curious', 'label': '好奇型', 'emoji': '🔍', 'desc': '什么都想闻一闻。\n日记里写满奇怪的发现。'},
    {'id': 'playful', 'label': '活泼型', 'emoji': '💫', 'desc': '遇到水坑一定踩。\n用鼻子喷水逗你开心。'},
    {'id': 'calm', 'label': '沉稳型', 'emoji': '🏔️', 'desc': '话不多，每句都到心里。\n默默陪着你，像一座山。'},
  ];

  static const _accessories = [
    {'id': 'none', 'emoji': '', 'label': '无配饰'},
    {'id': 'flower', 'emoji': '🌸', 'label': '小花'},
    {'id': 'hat', 'emoji': '👒', 'label': '草帽'},
    {'id': 'scarf', 'emoji': '🧣', 'label': '围巾'},
    {'id': 'leaf', 'emoji': '🍃', 'label': '树叶'},
  ];

  static const _colors = ['暖灰', '软棕', '粉白'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _wishCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);

    final profile = ElephantProfile(
      name: _nameCtrl.text.trim().isEmpty ? '小象' : _nameCtrl.text.trim(),
      wish: _wishCtrl.text.trim(),
      personality: _personality,
      accessory: _accessory,
      colorName: _colorName,
    );
    await _elephantService.saveProfile(profile);

    if (!mounted) return;
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgWarm,
      body: SafeArea(
        child: Column(
          children: [
            // 步骤条
            _buildStepIndicator(),
            const SizedBox(height: AppTheme.spacingMd),
            // 内容（可滚动）
            Expanded(
              child: _wrappedStepContent(),
            ),
            // 底部按钮
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  // ---- 步骤条 ----

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, 0,
      ),
      child: Row(
        children: [
          _stepDot(0, '性格'),
          _stepLine(),
          _stepDot(1, '外观'),
          _stepLine(),
          _stepDot(2, '名字'),
        ],
      ),
    );
  }

  Widget _stepDot(int index, String label) {
    final active = _step >= index;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppTheme.primaryWarm : AppTheme.dividerColor,
            ),
            child: Center(
              child: active
                  ? Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: active ? AppTheme.primaryWarm : AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _stepLine() {
    return Container(width: 20, height: 2, color: AppTheme.dividerColor);
  }

  // ---- 步骤内容 ----

  Widget _buildStepContent() {
    return switch (_step) {
      0 => _buildPersonalityStep(),
      1 => _buildAppearanceStep(),
      2 => _buildNameStep(),
      _ => const SizedBox.shrink(),
    };
  }

  // 包一层 SingleChildScrollView 防止溢出
  Widget _wrappedStepContent() {
    return SingleChildScrollView(
      key: ValueKey('scroll_step$_step'),
      child: _buildStepContent(),
    );
  }

  // 步骤0：选性格
  Widget _buildPersonalityStep() {
    return Padding(
      key: const ValueKey('step0'),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('你的小象是什么性格？', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('不同性格的小象，日记的语气会不一样', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: AppTheme.spacingLg),
          ..._personalities.map((p) => _personalityCard(p)),
        ],
      ),
    );
  }

  Widget _personalityCard(Map<String, String> p) {
    final selected = _personality == p['id'];
    return GestureDetector(
      onTap: () => setState(() => _personality = p['id']!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryWarm.withAlpha(25) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: selected ? AppTheme.primaryWarm : AppTheme.dividerColor, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Text(p['emoji']!, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['label']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(p['desc']!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppTheme.primaryWarm, size: 22),
          ],
        ),
      ),
    );
  }

  // 步骤1：选外观
  Widget _buildAppearanceStep() {
    return Padding(
      key: const ValueKey('step1'),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('给它打扮一下', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('选一个配饰和毛色', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: AppTheme.spacingLg),

          // 小象预览
          Center(
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(70),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text('🐘', style: TextStyle(fontSize: 52)),
                  if (_accessoryEmoji.isNotEmpty)
                    Positioned(
                      top: 14,
                      right: 18,
                      child: Text(
                        _accessoryEmoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // 配饰选择
          const Text('配饰', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _accessories.map((a) {
              final sel = _accessory == a['id'];
              return GestureDetector(
                onTap: () => setState(() => _accessory = a['id']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.primaryWarm.withAlpha(25) : AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? AppTheme.primaryWarm : AppTheme.dividerColor),
                  ),
                  child: Text(
                    '${a['emoji']} ${a['label']}',
                    style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppTheme.spacingLg),

          // 毛色选择
          const Text('毛色', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: _colors.map((c) {
              final sel = _colorName == c;
              final colorMap = {'暖灰': Color(0xFFB8A99A), '软棕': Color(0xFFC9A689), '粉白': Color(0xFFE8D5C4)};
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _colorName = c),
                  child: Column(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorMap[c],
                          border: Border.all(color: sel ? AppTheme.primaryWarm : Colors.transparent, width: 3),
                          boxShadow: sel ? [BoxShadow(color: AppTheme.primaryWarm.withAlpha(60), blurRadius: 8)] : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(c, style: TextStyle(fontSize: 12, color: sel ? AppTheme.primaryWarm : AppTheme.textSecondary)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 步骤2：起名字
  Widget _buildNameStep() {
    return Padding(
      key: const ValueKey('step2'),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Text(
            '🐘${_accessoryEmoji}',
            style: const TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 24),
          const Text('给你的小象起个名字吧', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _nameCtrl,
              textAlign: TextAlign.center,
              maxLength: 8,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: '小象',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withAlpha(150)),
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.dividerColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryWarm, width: 2)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('沿途有什么想替你看的？', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _wishCtrl,
              textAlign: TextAlign.center,
              maxLength: 20,
              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: '比如：替我看山',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withAlpha(120), fontSize: 14),
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.dividerColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryWarm, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _personalities.firstWhere((p) => p['id'] == _personality)['label'] ?? '',
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          Text(
            '$_colorName · ${_accessories.firstWhere((a) => a['id'] == _accessory)['label']}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  String get _accessoryEmoji =>
      _accessories.firstWhere((a) => a['id'] == _accessory)['emoji'] ?? '';

  // ---- 底部按钮 ----

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.bgWarm,
        boxShadow: [BoxShadow(color: AppTheme.dividerColor.withAlpha(80), blurRadius: 6, offset: const Offset(0, -1))],
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.dividerColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('上一步'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _step < 2
                  ? () => setState(() => _step++)
                  : _saving ? null : _finish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryWarm,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_step < 2 ? '下一步' : '🐘 完成'),
            ),
          ),
        ],
      ),
    );
  }
}
