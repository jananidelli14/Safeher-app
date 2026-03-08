import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js;

class LocationService {
  /// Get current location. On Web uses JS navigator.geolocation with
  /// maximumAge:0 (never cache) and enableHighAccuracy:true for real GPS.
  Future<Position?> getCurrentLocation() async {
    if (kIsWeb) {
      return _getWebLocation();
    }
    return _getNativeLocation();
  }

  /// Web: use JS bridge to force fresh high-accuracy GPS
  Future<Position?> _getWebLocation() async {
    try {
      final completer = Completer<Position?>();
      js.context.callMethod('getAccurateLocation', [
        js.allowInterop((result, error) {
          if (result != null) {
            final lat = (result['lat'] as num).toDouble();
            final lng = (result['lng'] as num).toDouble();
            final accuracy = (result['accuracy'] as num?)?.toDouble() ?? 0.0;
            // Create a fake Position-compatible object via Geolocator
            completer.complete(_makePosition(lat, lng, accuracy));
          } else {
            completer.complete(null);
          }
        })
      ]);
      return await completer.future.timeout(const Duration(seconds: 25), onTimeout: () => null);
    } catch (e) {
      return _getNativeLocation();
    }
  }

  Position _makePosition(double lat, double lng, double accuracy) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  Future<Position?> _getNativeLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
  }

  Stream<Position> getLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 500,
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
