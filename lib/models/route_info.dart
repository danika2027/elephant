/// 路线信息
class RouteInfo {
  final String id; // "nanning_guilin"
  final String name; // "南宁 → 桂林"
  final String from;
  final String to;
  final int days;
  final double distanceKm;
  final String description;
  final String assetPath;

  const RouteInfo({
    required this.id,
    required this.name,
    required this.from,
    required this.to,
    required this.days,
    required this.distanceKm,
    required this.description,
    required this.assetPath,
  });
}

/// 路线注册表 —— 城市自由组合
class RouteRegistry {
  RouteRegistry._();

  /// 所有已实现的路线
  static const List<RouteInfo> routes = [
    RouteInfo(
      id: 'nanning_guilin',
      name: '南宁 → 桂林',
      from: '南宁',
      to: '桂林',
      days: 10,
      distanceKm: 380,
      description: '沿G322国道北上，穿过甘蔗海与喀斯特峰林，慢行至山水甲天下。',
      assetPath: 'assets/data/journey_data.json',
    ),
    // 未来扩展只需加条目：
    // RouteInfo(id:'guilin_yangshuo', from:'桂林', to:'阳朔', days:5, distanceKm:85, ...),
    // RouteInfo(id:'chengdu_lhasa',  from:'成都', to:'拉萨', days:30, distanceKm:2100, ...),
  ];

  /// 从所有路线中提取出发城市列表（去重）
  static List<String> get departureCities {
    return routes.map((r) => r.from).toSet().toList()..sort();
  }

  /// 从所有路线中提取目的地城市列表（去重）
  static List<String> get destinationCities {
    return routes.map((r) => r.to).toSet().toList()..sort();
  }

  /// 给定出发城市，返回可到达的目的地列表
  static List<String> destinationsFor(String from) {
    return routes.where((r) => r.from == from).map((r) => r.to).toList()..sort();
  }

  /// 查找匹配的路线
  static RouteInfo? findPair(String from, String to) {
    try {
      return routes.firstWhere((r) => r.from == from && r.to == to);
    } catch (_) {
      return null;
    }
  }

  /// 根据 id 查找
  static RouteInfo? find(String id) {
    try {
      return routes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  static RouteInfo get defaultRoute => routes.first;
}
