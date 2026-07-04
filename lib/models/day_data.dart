/// 小象旅程 - 核心数据模型

/// 一天的完整旅程数据
class DayData {
  int day;
  final String date;
  final String departure;
  final String destination;
  final String lodging;
  final String distance;
  final Coordinates startCoord;
  final Coordinates endCoord;
  List<ElephantMessage> messages;
  final Map<String, dynamic>? rawJson;

  DayData({
    required this.day,
    required this.date,
    required this.departure,
    required this.destination,
    required this.lodging,
    required this.distance,
    required this.startCoord,
    required this.endCoord,
    required this.messages,
    this.rawJson,
  });

  void shiftDay() => day++;

  factory DayData.fromJson(Map<String, dynamic> json) {
    return DayData(
      day: json['day'] as int,
      date: json['date'] as String,
      departure: json['departure'] as String,
      destination: json['destination'] as String,
      lodging: json['lodging'] as String,
      distance: json['distance'] as String,
      startCoord: Coordinates.fromJson(
          json['coordinates']['start'] as Map<String, dynamic>),
      endCoord: Coordinates.fromJson(
          json['coordinates']['end'] as Map<String, dynamic>),
      messages: (json['messages'] as List<dynamic>)
          .map((m) => ElephantMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'date': date,
        'departure': departure,
        'destination': destination,
        'lodging': lodging,
        'distance': distance,
        'coordinates': {
          'start': startCoord.toJson(),
          'end': endCoord.toJson(),
        },
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}

/// GPS坐标 (WGS-84)
class Coordinates {
  final double lat;
  final double lng;

  const Coordinates({required this.lat, required this.lng});

  factory Coordinates.fromJson(Map<String, dynamic> json) {
    return Coordinates(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

/// 小象的一条消息
class ElephantMessage {
  final String type;
  final String timeOfDay;
  final String location;
  final String content;
  final String signature;
  final String? scenery; // 现实中的风景事物描述
  final String? photoUrl; // 风景照片 URL

  const ElephantMessage({
    required this.type,
    required this.timeOfDay,
    required this.location,
    required this.content,
    required this.signature,
    this.scenery,
    this.photoUrl,
  });

  factory ElephantMessage.fromJson(Map<String, dynamic> json) {
    return ElephantMessage(
      type: json['type'] as String,
      timeOfDay: json['timeOfDay'] as String,
      location: json['location'] as String,
      content: json['content'] as String,
      signature: json['signature'] as String,
      scenery: json['scenery'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'timeOfDay': timeOfDay,
        'location': location,
        'content': content,
        'signature': signature,
        if (scenery != null) 'scenery': scenery,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };
}

/// 整个旅程的元数据
class JourneyMeta {
  final String title;
  final String subtitle;
  final String route;
  final int totalDays;
  final double totalDistanceKm;

  const JourneyMeta({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.totalDays,
    required this.totalDistanceKm,
  });

  factory JourneyMeta.fromJson(Map<String, dynamic> json) {
    return JourneyMeta(
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      route: json['route'] as String,
      totalDays: json['totalDays'] as int,
      totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
    );
  }
}

/// 完整的旅程数据
class JourneyData {
  final JourneyMeta meta;
  final List<DayData> days;

  const JourneyData({required this.meta, required this.days});

  factory JourneyData.fromJson(Map<String, dynamic> json) {
    return JourneyData(
      meta: JourneyMeta.fromJson(json['meta'] as Map<String, dynamic>),
      days: (json['days'] as List<dynamic>)
          .map((d) => DayData.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  DayData getDay(int day) => days[day - 1];

  int? getCurrentDay(DateTime date, DateTime startDate) {
    final diff = date.difference(startDate).inDays + 1;
    return (diff >= 1 && diff <= days.length) ? diff : null;
  }
}
