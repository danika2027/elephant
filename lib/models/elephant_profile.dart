/// 小象个性化档案
class ElephantProfile {
  String name;
  String personality; // gentle | curious | playful | calm
  String accessory; // none | flower | hat | scarf | leaf
  String colorName; // 暖灰 | 软棕 | 粉白
  String wish; // 用户心愿，如"替我看山"

  ElephantProfile({
    this.name = '小象',
    this.personality = 'gentle',
    this.accessory = 'none',
    this.colorName = '暖灰',
    this.wish = '',
  });

  // ---- 性格映射 ----

  String get personalityLabel => switch (personality) {
        'gentle' => '温柔型',
        'curious' => '好奇型',
        'playful' => '活泼型',
        'calm' => '沉稳型',
        _ => '温柔型',
      };

  String get personalityDesc => switch (personality) {
        'gentle' => '走得很慢，但每步都很稳。\n喜欢在路边停下来看花。',
        'curious' => '什么都想闻一闻。\n日记里会写很多奇怪的小发现。',
        'playful' => '路上遇到水坑一定会踩。\n会用鼻子给自己喷水玩。',
        'calm' => '话不多，但每句都说到心里。\n喜欢安静地看着远方。',
        _ => '',
      };

  // ---- 外观映射 ----

  String get accessoryEmoji => switch (accessory) {
        'flower' => '🌸',
        'hat' => '👒',
        'scarf' => '🧣',
        'leaf' => '🍃',
        _ => '',
      };

  String get colorEmoji => switch (colorName) {
        '暖灰' => '🐘',
        '软棕' => '🐘',
        '粉白' => '🐘',
        _ => '🐘',
      };

  // ---- 序列化 ----

  Map<String, dynamic> toJson() => {
        'name': name,
        'personality': personality,
        'accessory': accessory,
        'colorName': colorName,
        'wish': wish,
      };

  factory ElephantProfile.fromJson(Map<String, dynamic> json) {
    return ElephantProfile(
      name: json['name'] as String? ?? '小象',
      personality: json['personality'] as String? ?? 'gentle',
      accessory: json['accessory'] as String? ?? 'none',
      colorName: json['colorName'] as String? ?? '暖灰',
      wish: json['wish'] as String? ?? '',
    );
  }
}

/// 小象实时状态（喂食、互动影响）
class ElephantState {
  int hunger; // 0-100，值越低越饿
  int mood; // 0-100
  int energy; // 0-100

  ElephantState({
    this.hunger = 80,
    this.mood = 90,
    this.energy = 85,
  });

  String get hungerLabel {
    if (hunger > 70) return '很饱 🍌';
    if (hunger > 40) return '有点饿 🍌';
    return '好饿 🍌🍌';
  }

  String get moodLabel {
    if (mood > 70) return '开心 😊';
    if (mood > 40) return '还行 🙂';
    return '低落 😔';
  }

  String get energyLabel {
    if (energy > 70) return '精力充沛 ⚡';
    if (energy > 40) return '有点累了 🚶';
    return '需要休息 💤';
  }

  void feed() {
    hunger = (hunger + 25).clamp(0, 100);
    mood = (mood + 5).clamp(0, 100);
  }

  void pet() {
    mood = (mood + 20).clamp(0, 100);
  }

  void talk() {
    mood = (mood + 10).clamp(0, 100);
  }

  void dailyDecay(int day) {
    // 每天自然衰减
    hunger = (hunger - 8).clamp(0, 100);
    energy = (energy - 6 + (day > 7 ? 2 : 0)).clamp(0, 100);
    mood = (mood - 3 + (day > 7 ? 5 : 0)).clamp(0, 100); // 快到了心情好
  }

  Map<String, dynamic> toJson() => {
        'hunger': hunger,
        'mood': mood,
        'energy': energy,
      };

  factory ElephantState.fromJson(Map<String, dynamic> json) {
    return ElephantState(
      hunger: json['hunger'] as int? ?? 80,
      mood: json['mood'] as int? ?? 90,
      energy: json['energy'] as int? ?? 85,
    );
  }
}
