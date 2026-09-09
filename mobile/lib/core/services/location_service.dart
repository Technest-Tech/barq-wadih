// lib/core/services/location_service.dart

import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../../features/regions/domain/region_model.dart';

/// Raised when the device location can't be resolved. [message] is user-facing
/// Arabic copy, matching the wording used by the web "القريب مني" toggle.
class LocationFailure implements Exception {
  final String message;

  /// True when the user denied permission permanently — the caller should
  /// offer to open the app settings rather than just retrying.
  final bool permanentlyDenied;

  const LocationFailure(this.message, {this.permanentlyDenied = false});

  @override
  String toString() => message;
}

/// Great-circle distance in kilometres between two lat/lng points.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  double toRad(double deg) => deg * math.pi / 180.0;

  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.sqrt(a));
}

/// Nearest city to [lat]/[lng], ignoring cities the backend has no
/// coordinates for. Returns null when no city has coordinates.
CityModel? findNearestCity(List<CityModel> cities, double lat, double lng) {
  CityModel? best;
  var bestDist = double.infinity;

  for (final city in cities) {
    final cLat = city.latitude;
    final cLng = city.longitude;
    if (cLat == null || cLng == null) continue;

    final dist = haversineKm(lat, lng, cLat, cLng);
    if (dist < bestDist) {
      bestDist = dist;
      best = city;
    }
  }
  return best;
}

/// Resolves the device's current position, requesting permission if needed.
/// Throws [LocationFailure] with user-facing Arabic copy on every failure path.
Future<Position> getCurrentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationFailure('يرجى تفعيل خدمة الموقع في جهازك');
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    throw const LocationFailure(
      'تم رفض إذن الموقع. يمكنك السماح به من إعدادات التطبيق',
      permanentlyDenied: true,
    );
  }
  if (permission == LocationPermission.denied) {
    throw const LocationFailure('يجب السماح بالوصول للموقع');
  }

  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
  } on LocationFailure {
    rethrow;
  } catch (_) {
    // Timeout, or no fix available (common indoors / on emulators).
    throw const LocationFailure('تعذّر تحديد موقعك، حاول مرة أخرى');
  }
}
