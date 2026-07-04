import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/day_data.dart';
import '../models/elephant_profile.dart';
import '../services/elephant_service.dart';
import '../theme/app_theme.dart';
import '../widgets/elephant_interaction.dart';

/// 全局路线地图页
/// —— 南宁→桂林完整路线，橙灰分段显示小象的足迹
class MapScreen extends StatefulWidget {
  final List<DayData> allDays;
  final int currentDay;
  final bool hasArrived;
  final int totalDays;
  final ElephantProfile profile;
  final bool hasFedToday;
  final bool hasChattedToday;

  const MapScreen({
    super.key,
    required this.allDays,
    required this.currentDay,
    required this.hasArrived,
    required this.totalDays,
    required this.profile,
    this.hasFedToday = false,
    this.hasChattedToday = false,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;

  // ---- 派生数据 ----

  List<DayData> get _days => widget.allDays;
  int get _day => widget.currentDay.clamp(1, _days.length);
  bool get _arrived => widget.hasArrived;

  /// 完整路线：起点 + 每天终点（共11个点）
  List<LatLng> get _fullRoute {
    final pts = <LatLng>[];
    pts.add(_coord(_days.first.startCoord));
    for (final d in _days) {
      pts.add(_coord(d.endCoord));
    }
    return pts;
  }

  /// 已走路线：起点 → 当前天数终点
  List<LatLng> get _traveled {
    final end = _arrived ? _fullRoute.length : (_day + 1);
    return _fullRoute.sublist(0, end.clamp(1, _fullRoute.length));
  }

  /// 未走路线：当前天数终点 → 最终目的地
  List<LatLng> get _untraveled {
    if (_arrived) return [];
    final start = _day;
    return _fullRoute.sublist(
      start.clamp(0, _fullRoute.length - 1),
      _fullRoute.length,
    );
  }

  /// 小象当前位置
  LatLng get _elephantPos {
    if (_arrived) return _fullRoute.last;
    return _coord(_days[_day - 1].endCoord);
  }

  /// 累计已走里程（估算）
  int get _traveledKm {
    double sum = 0;
    for (int i = 0; i < (_arrived ? _days.length : _day); i++) {
      sum += _parseDistance(_days[i].distance);
    }
    return sum.round();
  }

  /// 剩余里程
  int get _remainingKm {
    final total = 380; // 南宁→桂林总里程
    return (total - _traveledKm).clamp(0, total);
  }

  /// 行程进度 0.0-1.0
  double get _progress {
    if (_arrived) return 1.0;
    return _day / widget.totalDays;
  }

  // ---- 地图拟合 ----

  LatLngBounds get _routeBounds {
    return LatLngBounds.fromPoints(_fullRoute);
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // 在地图就绪后自动缩放至路线全貌
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitRoute();
    });
  }

  void _fitRoute() {
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: _routeBounds,
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ==========================================================
  //  Build
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ═══ 地图 ═══
          _buildMap(),

          // ═══ 顶部渐变遮罩 + 返回按钮 ═══
          _buildTopBar(context),

          // ═══ 图例 ═══
          _buildLegend(),

          // ═══ 底部信息面板 ═══
          _buildBottomPanel(context),
        ],
      ),
    );
  }

  // ==========================================================
  //  地图
  // ==========================================================

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _elephantPos,
        initialZoom: 9.0,
        minZoom: 7.0,
        maxZoom: 16.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // ---- OSM 瓦片 ----
        TileLayer(
          urlTemplate:
              'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
          subdomains: const ['1', '2', '3', '4'],
          userAgentPackageName: 'com.elephant.journey',
        ),

        // ---- 未走路线：灰色虚线 ----
        if (_untraveled.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _untraveled,
                color: const Color(0xFFBDBDBD),
                strokeWidth: 3.5,
                isDotted: true,
              ),
            ],
          ),

        // ---- 已走路线：橙色实线 ----
        if (_traveled.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _traveled,
                color: AppTheme.mapRouteColor,
                strokeWidth: 5,
              ),
            ],
          ),

        // ---- 标记层 ----
        MarkerLayer(
          markers: [
            // 起点：南宁
            _buildMarker(
              _fullRoute.first,
              '📍',
              '南宁',
              isLabelLeft: true,
            ),

            // 终点：桂林
            _buildMarker(
              _fullRoute.last,
              _arrived ? '🏁' : '🏳️',
              '桂林',
            ),

            // 每日落脚点小圆点（不包含起点和终点）
            ..._buildDayDots(),

            // 小象当前位置
            _buildElephantMarker(),
          ],
        ),
      ],
    );
  }

  // ---- 标记构建 ----

  Marker _buildMarker(LatLng point, String emoji, String label,
      {bool isLabelLeft = false}) {
    return Marker(
      point: point,
      width: 100,
      height: 50,
      alignment: isLabelLeft ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(220),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 每日落脚点小圆点
  List<Marker> _buildDayDots() {
    final markers = <Marker>[];
    for (int i = 1; i < _fullRoute.length - 1; i++) {
      final day = i; // day 1..9 的终点
      final isPassed = _arrived || day <= _day;
      markers.add(
        Marker(
          point: _fullRoute[i],
          width: 14,
          height: 14,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPassed
                  ? AppTheme.mapRouteColor
                  : const Color(0xFFBDBDBD),
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return markers;
  }

  /// 小象标记（带动画呼吸感 + 点击互动）
  Marker _buildElephantMarker() {
    return Marker(
      point: _elephantPos,
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () => _openInteraction(),
        child: _ElephantMarker(
          label: _arrived ? '我到了！' : _days[_day - 1].destination,
        ),
      ),
    );
  }

  void _openInteraction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ElephantInteractionSheet(
        profile: widget.profile,
        currentDay: _day,
        location: _days[_day - 1].destination,
        departure: _days[_day - 1].departure,
        destination: _days[_day - 1].destination,
        distance: _days[_day - 1].distance,
        hasFedToday: widget.hasFedToday,
        hasChattedToday: widget.hasChattedToday,
      ),
    );
  }

  // ==========================================================
  //  顶部
  // ==========================================================

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              // 返回按钮
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 标题卡片
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Hero(
                        tag: 'elephant',
                        child: const Text('🐘', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _arrived ? '旅程完成 · 桂林' : '第$_day/${widget.totalDays}天 · ${_days[_day - 1].destination}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  图例
  // ==========================================================

  Widget _buildLegend() {
    return Positioned(
      right: AppTheme.spacingMd,
      top: MediaQuery.of(context).padding.top + 100,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(230),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendRow(const Color(0xFFE8A87C), '已走过'),
            const SizedBox(height: 4),
            _legendRow(const Color(0xFFBDBDBD), '未走过', dashed: true),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(Color color, String text, {bool dashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 6,
          child: CustomPaint(
            painter: _LegendLinePainter(
              color: color,
              dashed: dashed,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  // ==========================================================
  //  底部面板
  // ==========================================================

  Widget _buildBottomPanel(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(AppTheme.spacingMd),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- 出行信息 ----
              Row(
                children: [
                  _infoItem('已走', '${_traveledKm}km'),
                  _buildMiniProgress(),
                  _infoItem('剩余', '${_remainingKm}km'),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // ---- 返回按钮 ----
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('返回首页'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryWarm,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgress() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
            backgroundColor: AppTheme.dividerColor,
            valueColor:
                const AlwaysStoppedAnimation(AppTheme.mapRouteColor),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  工具
  // ==========================================================

  LatLng _coord(Coordinates c) => LatLng(c.lat, c.lng);

  double _parseDistance(String d) {
    // "~25km" → 25.0
    final num = d.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(num) ?? 30.0;
  }
}

// ============================================================
//  呼吸感小象标记
// ============================================================

class _ElephantMarker extends StatefulWidget {
  final String label;
  const _ElephantMarker({required this.label});

  @override
  State<_ElephantMarker> createState() => _ElephantMarkerState();
}

class _ElephantMarkerState extends State<_ElephantMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.15).animate(
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
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🐘', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryWarm,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryWarm.withAlpha(80),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
//  虚线绘制器（用于图例）
// ============================================================

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;
  _LegendLinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = dashed ? 1.5 : 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (!dashed) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    const dashW = 4.0;
    const gap = 3.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dashW).clamp(0, size.width), y),
        paint,
      );
      x += dashW + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
