import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final LocationService _locationService = LocationService();
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  Position? _userPos;
  List<Marker> _markers = [];
  String _activeFilter = 'all';
  bool _isLoading = true;
  bool _autoFollow = true;
  StreamSubscription<Position>? _positionStream;
  final TextEditingController _searchCtrl = TextEditingController();

  static const String _mapillaryToken = 'MLY|26777390158530578|6654db54de5283fe05ba26443c77290f';

  @override
  void initState() {
    super.initState();
    _startLiveTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _startLiveTracking() async {
    setState(() => _isLoading = true);

    // Get fresh position via LocationService (uses JS on web, Geolocator on native)
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        _onLocationUpdate(pos);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }

    // Keep updating on significant movement (native only, web GPS stream is unreliable)
    if (!kIsWeb) {
      const LocationSettings settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 200,
      );
      _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen(
        (Position position) {
          if (position.accuracy < 150) _onLocationUpdate(position);
        },
      );
    }
  }

  void _onLocationUpdate(Position pos) {
    if (!mounted) return;
    
    final isSignificantMove = _userPos == null || 
        Geolocator.distanceBetween(_userPos!.latitude, _userPos!.longitude, pos.latitude, pos.longitude) > 100;

    setState(() {
      _userPos = pos;
      _isLoading = false;
    });

    if (isSignificantMove) {
      _loadNearbyPlaces(pos.latitude, pos.longitude);
    }

    if (_autoFollow) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), _mapController.camera.zoom);
    }
  }

  Future<void> _init() async {
    // Redundant now, replaced by _startLiveTracking
  }

  Future<void> _loadNearbyPlaces(double lat, double lng) async {
    final markers = <Marker>[];
    markers.add(_buildUserLocationMarker(lat, lng));

    bool gotPolice = false, gotHospitals = false;

    // Try backend first for police
    if (_activeFilter == 'all' || _activeFilter == 'police') {
      try {
        final policeRes = await _apiService.getNearbyPolice(lat, lng)
            .timeout(const Duration(seconds: 8));
        final stations = policeRes['stations'] ?? [];
        for (var s in stations) {
          if (s['lat'] != null && s['lng'] != null) {
            markers.add(_buildMarker(s['lat'].toDouble(), s['lng'].toDouble(),
                const Color(0xFF3A86FF), Icons.shield_rounded,
                "🚔 ${s['name']} - ${s['distance_km']} km"));
            gotPolice = true;
          }
        }
      } catch (_) {}
    }

    // Try backend for hospitals
    if (_activeFilter == 'all' || _activeFilter == 'hospital') {
      try {
        final hospRes = await _apiService.getNearbyHospitals(lat, lng)
            .timeout(const Duration(seconds: 8));
        final hospitals = hospRes['hospitals'] ?? [];
        for (var h in hospitals) {
          if (h['lat'] != null && h['lng'] != null) {
            markers.add(_buildMarker(h['lat'].toDouble(), h['lng'].toDouble(),
                const Color(0xFFFF006E), Icons.local_hospital_rounded,
                "🏥 ${h['name']} - ${h['distance_km']} km"));
            gotHospitals = true;
          }
        }
      } catch (_) {}
    }

    // Hotels from backend
    if (_activeFilter == 'all' || _activeFilter == 'hotel') {
      try {
        final hotelRes = await _apiService.getNearbyHotels(lat, lng)
            .timeout(const Duration(seconds: 8));
        final hotels = hotelRes['accommodations'] ?? [];
        for (var h in hotels) {
          if (h['lat'] != null && h['lng'] != null) {
            markers.add(_buildMarker(h['lat'].toDouble(), h['lng'].toDouble(),
                const Color(0xFFFFB703), Icons.hotel_rounded, "🏨 ${h['name']}"));
          }
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _markers = markers);

    // If backend gave nothing, query OSM Overpass directly
    if (!gotPolice && !gotHospitals) {
      await _loadOSMFallback(lat, lng, markers);
    }
  }

  Future<void> _loadOSMFallback(double lat, double lng, List<Marker> markers) async {
    try {
      final bbox = '${lat - 0.08},${lng - 0.08},${lat + 0.08},${lng + 0.08}';
      final query = '[out:json][timeout:20];('
          'node[amenity=police]($bbox);'
          'node[amenity=hospital]($bbox);'
          'node[amenity=clinic]($bbox);'
          ');out body;';
      final res = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final elements = data['elements'] as List? ?? [];
        for (final e in elements) {
          final tags = e['tags'] as Map? ?? {};
          final eLat = (e['lat'] as num?)?.toDouble();
          final eLng = (e['lon'] as num?)?.toDouble();
          if (eLat == null || eLng == null) continue;
          final amenity = tags['amenity'] ?? '';
          final name = tags['name'] ?? tags['name:en'] ?? amenity;
          if (amenity == 'police' && (_activeFilter == 'all' || _activeFilter == 'police')) {
            markers.add(_buildMarker(eLat, eLng, const Color(0xFF3A86FF),
                Icons.shield_rounded, "🚔 $name"));
          } else if ((amenity == 'hospital' || amenity == 'clinic') &&
                     (_activeFilter == 'all' || _activeFilter == 'hospital')) {
            markers.add(_buildMarker(eLat, eLng, const Color(0xFFFF006E),
                Icons.local_hospital_rounded, "🏥 $name"));
          }
        }
        if (mounted) setState(() => _markers = markers);
      }
    } catch (_) {}
  }

  Marker _buildUserLocationMarker(double lat, double lng) {
    return Marker(
      point: LatLng(lat, lng),
      width: 60,
      height: 60,
      child: GestureDetector(
        onTap: () => _showTooltip("📍 Your current location"),
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0077B6).withOpacity(0.2)),
          ),
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0077B6).withOpacity(0.35),
              border: Border.all(color: const Color(0xFF0077B6), width: 2)),
          ),
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0077B6),
              boxShadow: [BoxShadow(color: Color(0xFF0077B6), blurRadius: 8, spreadRadius: 2)]),
            child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 14),
          ),
        ]),
      ),
    );
  }

  Marker _buildMarker(double lat, double lng, Color color, IconData icon, String tooltip) {
    return Marker(
      point: LatLng(lat, lng),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showTooltip(tooltip),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  void _showTooltip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _setFilter(String filter) {
    setState(() => _activeFilter = filter);
    if (_userPos != null) {
      _loadNearbyPlaces(_userPos!.latitude, _userPos!.longitude);
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      // Use Nominatim OpenStreetMap geocoding (free)
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query + ", Tamil Nadu")}&format=json&limit=1'
      );
      final response = await http.get(uri, headers: {'User-Agent': 'SafeHerApp/1.0'});
      if (response.statusCode == 200) {
        final List results = jsonDecode(response.body);
        if (results.isNotEmpty) {
          final lat = double.parse(results[0]['lat']);
          final lng = double.parse(results[0]['lon']);
          final newPos = Position(latitude: lat, longitude: lng, timestamp: DateTime.now(), accuracy: 1, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0);
          setState(() => _userPos = newPos);
          await _loadNearbyPlaces(lat, lng);
          _mapController.move(LatLng(lat, lng), 14);
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location not found. Try a city name like Chennai or Madurai.")));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Search failed. Please check your connection.")));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Map
          _userPos == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF5D3891)))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_userPos!.latitude, _userPos!.longitude),
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.safe_her_travel',
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),

          // Top App Bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                        child: const Icon(Icons.map_rounded, color: Color(0xFF5D3891), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Safety Radar",
                        style: TextStyle(color: Color(0xFF1F1F1F), fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
                      ),
                      const Spacer(),
                      _buildMapSourceBadge(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Search Bar
          Positioned(
            top: 100, left: 24, right: 24,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4))],
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: "Search city (e.g. Chennai, Madurai)",
                  hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF5D3891)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF5D3891), size: 18),
                    onPressed: _searchLocation,
                  ),
                ),
                onSubmitted: (_) => _searchLocation(),
              ),
            ),
          ),

          // Filter chips
          Positioned(
            top: 165, left: 0, right: 0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _filterChip('all', 'All Nearby', Icons.explore_rounded),
                  const SizedBox(width: 12),
                  _filterChip('police', 'Security', Icons.shield_rounded),
                  const SizedBox(width: 12),
                  _filterChip('hospital', 'Emergency', Icons.local_hospital_rounded),
                  const SizedBox(width: 12),
                  _filterChip('hotel', 'Verified Stays', Icons.hotel_rounded),
                ],
              ),
            ),
          ),

          // Legend
          Positioned(
            bottom: 32, right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _legendItem(const Color(0xFF2D31FA), "Police Stations"),
                const SizedBox(height: 8),
                _legendItem(const Color(0xFFE71C23), "Hospitals"),
                const SizedBox(height: 8),
                _legendItem(const Color(0xFFF9A826), "Safe Hotels"),
              ],
            ),
          ),

          // Recenter & Refresh FABs
          Positioned(
            bottom: 32, left: 24,
            child: Column(
              children: [
                _mapActionButton(
                  icon: _autoFollow ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                  color: _autoFollow ? const Color(0xFF5D3891) : Colors.grey,
                  onTap: () {
                    setState(() => _autoFollow = !_autoFollow);
                    if (_autoFollow && _userPos != null) {
                      _mapController.move(LatLng(_userPos!.latitude, _userPos!.longitude), 14);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _mapActionButton(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    if (_userPos != null) _loadNearbyPlaces(_userPos!.latitude, _userPos!.longitude);
                  },
                ),
              ],
            ),
          ),

          if (_isLoading)
            Positioned(
              bottom: 120, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5D3891))),
                      SizedBox(width: 12),
                      Text("Updating Radar...", style: TextStyle(color: Color(0xFF1F1F1F), fontSize: 13, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapSourceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: const Row(
        children: [
          Icon(Icons.layers_rounded, color: Color(0xFF8E8E93), size: 14),
          SizedBox(width: 6),
          Text("Mapillary", style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _mapActionButton({required IconData icon, Color? color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: color ?? const Color(0xFF5D3891), size: 22),
      ),
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final isActive = _activeFilter == value;
    return GestureDetector(
      onTap: () => _setFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF5D3891) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : const Color(0xFF5D3891)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isActive ? Colors.white : const Color(0xFF1F1F1F), fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
        ],
      ),
    );
  }
}
