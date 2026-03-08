import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'settings_page.dart';
import '../services/location_service.dart';

class DashboardPage extends StatefulWidget {
  final Function(int) onNavigate;
  const DashboardPage({super.key, required this.onNavigate});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _initialLoad = true;
  bool _sosSent = false;
  bool _sosActivating = false;
  int _sosCountdown = 3;
  Timer? _sosTimer;

  int? _policeCount;
  int? _hospitalCount;
  bool _fetchingNearby = false;

  Position? _currentPos;
  StreamSubscription<Position>? _positionStream;
  final ApiService _api = ApiService();
  final LocationService _locationService = LocationService();

  late AnimationController _pulseCtrl;
  late AnimationController _heroCtrl;
  late Animation<double> _heroAnim;

  static const Color primary  = Color(0xFF0077B6);
  static const Color accent   = Color(0xFF00B4D8);
  static const Color sosRed   = Color(0xFFE53935);
  static const Color sosRedDk = Color(0xFFB71C1C);
  static const Color green    = Color(0xFF00C853);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _heroCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _heroAnim  = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic);
    _heroCtrl.forward();
    _loadData();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _heroCtrl.dispose();
    _positionStream?.cancel();
    _sosTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = await AuthService.getUser();
    if (mounted) setState(() { _user = user; _initialLoad = false; });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
        _startLocationStream();
      }
    } catch (_) {}
  }

  Future<void> refreshUser() async {
    final user = await AuthService.getUser();
    if (mounted) setState(() => _user = user);
  }

  void _startLocationStream() async {
    try {
      // LocationService uses JS bridge on web (maximumAge:0 = no cache, real GPS)
      final pos = await _locationService.getCurrentLocation();
      if (pos != null && mounted) {
        setState(() => _currentPos = pos);
        _fetchNearby(pos);
      }
    } catch (_) {}

    // Native: keep streaming for movement updates
    if (!kIsWeb) {
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 200,
        ),
      ).listen((pos) {
        if (mounted && pos.accuracy < 100) {
          setState(() => _currentPos = pos);
        }
      });
    }
  }

  Future<void> _fetchNearby(Position pos) async {
    if (_fetchingNearby || !mounted) return;
    setState(() => _fetchingNearby = true);
    try {
      // Try backend first
      final pRes = await _api.getNearbyPolice(pos.latitude, pos.longitude)
          .timeout(const Duration(seconds: 8));
      final hRes = await _api.getNearbyHospitals(pos.latitude, pos.longitude)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final newP = pRes['success'] == true
          ? (pRes['count'] as int?) ??
            (pRes['stations'] as List?)?.length ??
            (pRes['police_stations'] as List?)?.length
          : null;
      final newH = hRes['success'] == true
          ? (hRes['count'] as int?) ??
            (hRes['hospitals'] as List?)?.length
          : null;
      if (mounted) {
        setState(() {
          if (newP != null) _policeCount   = newP;
          if (newH != null) _hospitalCount = newH;
          _fetchingNearby = false;
        });
      }
      // If backend returned 0 or null, try OSM directly
      if ((newP == null || newP == 0) || (newH == null || newH == 0)) {
        _fetchNearbyOSM(pos);
      }
    } catch (_) {
      // Backend unreachable — query OSM Overpass directly
      _fetchNearbyOSM(pos);
    }
  }

  Future<void> _fetchNearbyOSM(Position pos) async {
    try {
      final lat = pos.latitude;
      final lng = pos.longitude;
      final bbox = '${lat - 0.1},${lng - 0.1},${lat + 0.1},${lng + 0.1}';
      final query = '[out:json][timeout:15];('
          'node[amenity=police]($bbox);'
          'node[amenity=hospital]($bbox);'
          'node[amenity=clinic]($bbox);'
          ');out body;';
      final res = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final elements = data['elements'] as List? ?? [];
        int police = 0, hospitals = 0;
        for (final e in elements) {
          final tags = e['tags'] as Map? ?? {};
          final amenity = tags['amenity'] ?? '';
          if (amenity == 'police') police++;
          if (amenity == 'hospital' || amenity == 'clinic') hospitals++;
        }
        if (mounted) {
          setState(() {
            if (police > 0 || _policeCount == null) _policeCount = police;
            if (hospitals > 0 || _hospitalCount == null) _hospitalCount = hospitals;
            _fetchingNearby = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _fetchingNearby = false);
    }
  }

  void _startSOS() {
    HapticFeedback.heavyImpact();
    setState(() { _sosActivating = true; _sosCountdown = 3; });
    _sosTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_sosCountdown > 1) {
        setState(() => _sosCountdown--);
        HapticFeedback.mediumImpact();
      } else {
        t.cancel();
        _fireSOS();
      }
    });
  }

  void _cancelSOS() {
    _sosTimer?.cancel();
    setState(() { _sosActivating = false; _sosCountdown = 3; });
  }

  Future<void> _fireSOS() async {
    HapticFeedback.heavyImpact();
    final pos = _currentPos;
    if (pos != null) {
      await _api.triggerSOS(lat: pos.latitude, lng: pos.longitude);
      await _sendWhatsAppAlerts(pos);
    }
    if (mounted) setState(() { _sosActivating = false; _sosSent = true; });
  }

  Future<void> _sendWhatsAppAlerts(Position pos) async {
    final contacts = _user?['emergency_contacts'];
    if (contacts is! List || contacts.isEmpty) return;
    final name = _user?['name'] ?? 'SafeHer User';
    final mapLink = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    final message = Uri.encodeComponent(
      'EMERGENCY ALERT from SafeHer!\n\n$name needs immediate help!\n\nLocation: $mapLink\n\nPolice: 100 | Emergency: 112 | Women Helpline: 1091'
    );
    for (final contact in contacts) {
      final clean = contact.toString().replaceAll(RegExp(r'[\s\-()]'), '');
      final phone = clean.startsWith('+') ? clean : '+91$clean';
      final waUrl = Uri.parse('https://wa.me/${phone.replaceAll("+", "")}?text=$message');
      try { await launchUrl(waUrl, mode: LaunchMode.externalApplication); } catch (_) {}
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    if (h < 21) return 'Good Evening';
    return 'Good Night';
  }

  String get _greetEmoji {
    final h = DateTime.now().hour;
    if (h < 12) return '🌅';
    if (h < 17) return '☀️';
    if (h < 21) return '🌆';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF0F4F8);
    final cardBg  = isDark ? const Color(0xFF151B2E) : Colors.white;
    final txtDark = isDark ? Colors.white : const Color(0xFF0D1B2A);
    final txtGrey = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF607D8B);
    final name    = (_user?['name'] as String? ?? 'Traveller').split(' ').first;

    if (_sosSent) return _buildSOSSentScreen(isDark, cardBg, txtDark);

    return Scaffold(
      backgroundColor: bgColor,
      body: FadeTransition(
        opacity: _heroAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(name, isDark, cardBg, txtDark, txtGrey),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 18),
                    _buildBigSOSSection(isDark),
                    const SizedBox(height: 22),
                    _sectionLabel('Quick Actions', txtDark),
                    const SizedBox(height: 12),
                    _buildQuickActions(isDark, cardBg),
                    const SizedBox(height: 22),
                    _sectionLabel('Nearby Safety', txtDark),
                    const SizedBox(height: 12),
                    _buildNearbyRow(isDark, cardBg, txtDark, txtGrey),
                    const SizedBox(height: 22),
                    _sectionLabel('Emergency Dial', txtDark),
                    const SizedBox(height: 12),
                    _buildEmergencyGrid(isDark, cardBg),
                    const SizedBox(height: 22),
                    _buildSafetyTip(isDark, cardBg, txtDark, txtGrey),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name, bool isDark, Color cardBg, Color txtDark, Color txtGrey) {
    return SliverAppBar(
      expandedHeight: 185,
      pinned: true,
      floating: false,
      backgroundColor: primary,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF023E8A), Color(0xFF0077B6), Color(0xFF0096C7)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2)),
                      child: ClipOval(child: Image.asset('assets/images/safeher_logo.jpg', fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, color: Colors.white, size: 20))),
                    ),
                    const SizedBox(width: 10),
                    const Text('SafeHer', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  ]),
                  Row(children: [
                    _headerBtn(Icons.notifications_outlined, () {}),
                    const SizedBox(width: 6),
                    _headerBtn(Icons.settings_rounded, () async {
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SettingsPage(onLogout: () => widget.onNavigate(-1))));
                      await refreshUser();
                    }),
                  ]),
                ]),
                const SizedBox(height: 18),
                Text('$_greetEmoji $_greeting,', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                const SizedBox(height: 6),
                Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF69FF47), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('Protection Active', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }

  Widget _buildBigSOSSection(bool isDark) {
    if (_sosActivating) return _buildSOSCountdown();
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
            Color.lerp(sosRedDk, const Color(0xFF7B0000), _pulseCtrl.value)!,
            Color.lerp(sosRed,   const Color(0xFFC62828), _pulseCtrl.value)!,
          ]),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: sosRed.withOpacity(0.38 + _pulseCtrl.value * 0.2), blurRadius: 28 + _pulseCtrl.value * 12, offset: const Offset(0, 10))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(children: [
            Row(children: [
              Stack(alignment: Alignment.center, children: [
                Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08 + _pulseCtrl.value * 0.08))),
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15), border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)),
                  child: const Icon(Icons.sos_rounded, color: Colors.white, size: 30),
                ),
              ]),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Emergency SOS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                SizedBox(height: 4),
                Text('Swipe below to instantly alert\nyour contacts & services', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              ])),
            ]),
            const SizedBox(height: 18),
            _buildSwipeSlider(),
          ]),
        ),
      ),
    );
  }

  Widget _buildSwipeSlider() {
    return Container(
      width: double.infinity,
      height: 62,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(31),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 60),
          const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
          const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          const Text('SWIPE TO SEND SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
        ]),
        Dismissible(
          key: const Key('sos_home_swipe'),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (dir) async { _startSOS(); return false; },
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 56, height: 56,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 3))]),
              child: const Icon(Icons.chevron_right_rounded, color: sosRed, size: 34),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildSOSCountdown() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7B0000), Color(0xFFE53935)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: sosRed.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
      child: Column(children: [
        const Text('SENDING SOS IN', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 16),
        Stack(alignment: Alignment.center, children: [
          SizedBox(width: 110, height: 110, child: CircularProgressIndicator(value: (3 - _sosCountdown + 1) / 3, strokeWidth: 8, color: Colors.white, backgroundColor: Colors.white24)),
          Text('$_sosCountdown', style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _cancelSOS,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(30)),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
          ),
        ),
      ]),
    );
  }

  Widget _buildSOSSentScreen(bool isDark, Color cardBg, Color txtDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: green.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: green, width: 3)),
                child: Icon(Icons.check_rounded, color: green, size: 60),
              ),
              const SizedBox(height: 28),
              Text('SOS Alert Sent!', style: TextStyle(color: txtDark, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text('Your location was sent to your emergency contacts and local police.',
                style: TextStyle(color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF607D8B), fontSize: 15, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _quickDial('100', 'Police'),
                _quickDial('108', 'Ambulance'),
                _quickDial('112', 'Emergency'),
                _quickDial('1091', 'Women'),
              ]),
              const SizedBox(height: 36),
              GestureDetector(
                onTap: () => setState(() => _sosSent = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(20)),
                  child: const Text('I AM SAFE NOW', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _quickDial(String num, String label) {
    return GestureDetector(
      onTap: () async { try { await launchUrl(Uri.parse('tel:$num')); } catch (_) {} },
      child: Column(children: [
        Container(width: 56, height: 56,
          decoration: BoxDecoration(color: sosRed.withOpacity(0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: sosRed.withOpacity(0.3))),
          child: Center(child: Text(num, style: const TextStyle(color: sosRed, fontWeight: FontWeight.w900, fontSize: 14)))),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildQuickActions(bool isDark, Color cardBg) {
    final actions = [
      _Action('AI Chat',    Icons.auto_awesome_rounded, const Color(0xFF7C3AED), const Color(0xFFF3F0FF), const Color(0xFF1A0A3E), 1),
      _Action('Safety Map', Icons.map_rounded,           const Color(0xFF0284C7), const Color(0xFFEFF6FF), const Color(0xFF0C2340), 3),
      _Action('Community',  Icons.people_alt_rounded,    const Color(0xFF059669), const Color(0xFFECFDF5), const Color(0xFF022C22), 6),
      _Action('Hotels',     Icons.king_bed_rounded,      const Color(0xFFD97706), const Color(0xFFFFFBEB), const Color(0xFF3D1900), 5),
    ];

    return Row(children: actions.asMap().entries.map((e) {
      final a = e.value;
      final isLast = e.key == actions.length - 1;
      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: isLast ? 0 : 10),
        child: GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); widget.onNavigate(a.idx); },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? a.darkBg : a.lightBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: a.color.withOpacity(isDark ? 0.2 : 0.1), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Column(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: a.color.withOpacity(isDark ? 0.25 : 0.14), borderRadius: BorderRadius.circular(13)),
                child: Icon(a.icon, color: a.color, size: 22)),
              const SizedBox(height: 7),
              Text(a.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: a.color), textAlign: TextAlign.center),
            ]),
          ),
        ),
      ));
    }).toList());
  }

  Widget _buildNearbyRow(bool isDark, Color cardBg, Color txtDark, Color txtGrey) {
    return Row(children: [
      Expanded(child: _nearbyCard(emoji: '🚔', label: 'Police Stations', count: _policeCount, loading: _fetchingNearby && _policeCount == null, color: const Color(0xFF1E3A8A), isDark: isDark, cardBg: cardBg, txtDark: txtDark, txtGrey: txtGrey)),
      const SizedBox(width: 14),
      Expanded(child: _nearbyCard(emoji: '🏥', label: 'Hospitals', count: _hospitalCount, loading: _fetchingNearby && _hospitalCount == null, color: const Color(0xFF065F46), isDark: isDark, cardBg: cardBg, txtDark: txtDark, txtGrey: txtGrey)),
    ]);
  }

  Widget _nearbyCard({required String emoji, required String label, required int? count, required bool loading, required Color color, required bool isDark, required Color cardBg, required Color txtDark, required Color txtGrey}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(isDark ? 0.18 : 0.09), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 10),
        if (loading)
          Container(width: 60, height: 18, decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5), borderRadius: BorderRadius.circular(6)))
        else
          Text(count == null ? '—' : count.toString(), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color, letterSpacing: -1.5)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: txtGrey, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text('within 10km', style: TextStyle(color: txtGrey.withOpacity(0.6), fontSize: 10)),
      ]),
    );
  }

  Widget _buildEmergencyGrid(bool isDark, Color cardBg) {
    final nums = [
      {'n': '100',  'label': 'Police',        'icon': '🚔', 'c': const Color(0xFF1D4ED8)},
      {'n': '112',  'label': 'Emergency',      'icon': '🆘', 'c': const Color(0xFFDC2626)},
      {'n': '1091', 'label': 'Women Helpline', 'icon': '💜', 'c': const Color(0xFF7C3AED)},
      {'n': '108',  'label': 'Ambulance',      'icon': '🏥', 'c': const Color(0xFF059669)},
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.6, crossAxisSpacing: 12, mainAxisSpacing: 12,
      children: nums.map((n) {
        final c = n['c'] as Color;
        return GestureDetector(
          onTap: () async { HapticFeedback.mediumImpact(); try { await launchUrl(Uri.parse('tel:${n['n']}')); } catch (_) {} },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? c.withOpacity(0.15) : c.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.withOpacity(isDark ? 0.3 : 0.15), width: 1),
            ),
            child: Row(children: [
              Text(n['icon'] as String, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(n['label'] as String, style: TextStyle(fontSize: 9, color: c, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                Text(n['n'] as String, style: TextStyle(fontSize: 17, color: c, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ]),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSafetyTip(bool isDark, Color cardBg, Color txtDark, Color txtGrey) {
    final tips = [
      '💡 Share live location with a trusted contact when traveling at night.',
      '🚖 Use Ola or Uber after 9 PM — avoid unmarked autos.',
      '📱 Keep your phone charged. Carry a power bank when traveling.',
      '👮 Chennai Metro has dedicated women\'s coaches — use them!',
      '🌟 Trust your instincts. If something feels wrong, leave immediately.',
    ];
    final tip = tips[DateTime.now().minute % tips.length];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: primary.withOpacity(isDark ? 0.25 : 0.12))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.lightbulb_rounded, color: primary, size: 18)),
          const SizedBox(width: 10),
          Text('Safety Tip', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: txtDark)),
        ]),
        const SizedBox(height: 12),
        Text(tip, style: TextStyle(color: txtGrey, fontSize: 13, height: 1.6)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => widget.onNavigate(1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [primary, accent]), borderRadius: BorderRadius.circular(20)),
            child: const Text('Ask SafeHer AI →', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String t, Color txtDark) => Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: txtDark, letterSpacing: -0.3));
}

class _Action {
  final String label;
  final IconData icon;
  final Color color;
  final Color lightBg;
  final Color darkBg;
  final int idx;
  const _Action(this.label, this.icon, this.color, this.lightBg, this.darkBg, this.idx);
}
