// lib/features/ads/presentation/screens/map_location_picker.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';

class MapLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;
  const MapLocationPicker({super.key, this.initialLocation});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.neutralGray900,
        title: const Text(
          'تحديد الموقع على الخريطة',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_picked != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _picked),
              child: const Text(
                'تأكيد',
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'اختر موقعاً',
                  style: TextStyle(
                    color: AppTheme.neutralGray400,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initialLocation ?? const LatLng(24.6877, 46.7219),
              initialZoom: widget.initialLocation != null ? 13.0 : 6.0,
              onTap: (_, point) => setState(() => _picked = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.barqwadih.app',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Instruction banner at top
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 18,
                    color: _picked != null ? AppTheme.primaryBlue : AppTheme.neutralGray500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _picked == null
                          ? 'اضغط على الخريطة لتحديد موقعك بدقة'
                          : 'تم تحديد الموقع — يمكنك تغييره بالضغط مجدداً',
                      style: TextStyle(
                        fontSize: 13,
                        color: _picked == null
                            ? AppTheme.neutralGray700
                            : AppTheme.primaryBlue,
                        fontWeight:
                            _picked != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confirm button at bottom
          if (_picked != null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: GestureDetector(
                onTap: () => Navigator.pop(context, _picked),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: .35),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'تأكيد الموقع',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
