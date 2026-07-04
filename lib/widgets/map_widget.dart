import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/day_data.dart';
import '../theme/app_theme.dart';

/// 地图组件骨架 —— 后续实现
/// 用于在日记页展示小象当天的行进路线
class JourneyMapWidget extends StatelessWidget {
  final DayData dayData;
  final double height;

  const JourneyMapWidget({
    super.key,
    required this.dayData,
    this.height = 250,
  });

  LatLng get _start => LatLng(dayData.startCoord.lat, dayData.startCoord.lng);
  LatLng get _end => LatLng(dayData.endCoord.lat, dayData.endCoord.lng);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _start,
            initialZoom: 11.0,
            minZoom: 8.0,
            maxZoom: 16.0,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
              subdomains: const ['1', '2', '3', '4'],
              userAgentPackageName: 'com.elephant.journey',
            ),
            // 小象当前位置标记
            MarkerLayer(
              markers: [
                Marker(
                  point: _end,
                  width: 60,
                  height: 60,
                  child: const Text('🐘', style: TextStyle(fontSize: 36)),
                ),
              ],
            ),
            // 当日路线
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [_start, _end],
                  color: AppTheme.mapRouteColor,
                  strokeWidth: 3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
