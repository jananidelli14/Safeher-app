import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/dashboard_page.dart';
import 'pages/chat_page.dart';
import 'pages/sos_page.dart';
import 'pages/resources_page.dart';
import 'pages/hotels_page.dart';
import 'pages/map_page.dart';
import 'pages/community_page.dart';
import 'pages/login_page.dart';
import 'pages/permissions_page.dart';
import 'pages/settings_page.dart';
import 'services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const SafeHerApp());
}

// ── Global theme notifier (persists dark/light mode) ─────────────────────────
class ThemeNotifier extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;

  ThemeNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('dark_mode') ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDark);
    notifyListeners();
  }
}

final themeNotifier = ThemeNotifier();

// ── Root App ──────────────────────────────────────────────────────────────────
class SafeHerApp extends StatefulWidget {
  const SafeHerApp({super.key});

  @override
  State<SafeHerApp> createState() => _SafeHerAppState();
}

class _SafeHerAppState extends State<SafeHerApp> {
  static const Color _pink   = Color(0xFFE91E8C);
  static const Color _purple = Color(0xFF9C27B0);

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  ThemeData _buildLight() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _pink, brightness: Brightness.light)
          .copyWith(primary: _pink, secondary: _purple, surface: Colors.white),
      scaffoldBackgroundColor: const Color(0xFFFFF0F8),
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _pink),
        titleTextStyle: TextStyle(
            color: Color(0xFF2D1B35), fontWeight: FontWeight.w900, fontSize: 20),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  ThemeData _buildDark() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _pink, brightness: Brightness.dark)
          .copyWith(primary: _pink, secondary: _purple, surface: const Color(0xFF1E1E2E)),
      scaffoldBackgroundColor: const Color(0xFF12121A),
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E2E),
        elevation: 0,
        iconTheme: IconThemeData(color: _pink),
        titleTextStyle: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeHer',
      debugShowCheckedModeBanner: false,
      themeMode: themeNotifier.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: _buildLight(),
      darkTheme: _buildDark(),
      home: const AuthGate(),
    );
  }
}

// ── Auth Gate ─────────────────────────────────────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with SingleTickerProviderStateMixin {
  bool _checking = true;
  bool _loggedIn = false;
  bool _permissionsNeeded = false;

  late AnimationController _splashCtrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _splashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fade  = CurvedAnimation(parent: _splashCtrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _splashCtrl, curve: Curves.easeOutBack));
    _splashCtrl.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _splashCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    final loggedIn = await AuthService.isLoggedIn();
    final prefs    = await SharedPreferences.getInstance();
    final permOk   = prefs.getBool('permissions_granted') ?? false;
    if (mounted) {
      setState(() {
        _loggedIn          = loggedIn;
        _permissionsNeeded = loggedIn && !permOk;
        _checking          = false;
      });
    }
  }

  void _onLogin() async {
    final prefs  = await SharedPreferences.getInstance();
    final permOk = prefs.getBool('permissions_granted') ?? false;
    setState(() {
      _loggedIn          = true;
      _permissionsNeeded = !permOk;
    });
  }

  void _onPermsDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_granted', true);
    if (mounted) setState(() => _permissionsNeeded = false);
  }

  void _doLogout() {
    AuthService.logout().then((_) {
      if (mounted) setState(() => _loggedIn = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking)          return _splash();
    if (!_loggedIn)         return LoginPage(onLoginSuccess: _onLogin);
    if (_permissionsNeeded) return PermissionsPage(onComplete: _onPermsDone);
    return MainShell(onLogout: _doLogout);
  }

  Widget _splash() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF0F8), Color(0xFFF8F0FF), Color(0xFFFFF0F8)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFD6EC), Color(0xFFEDD6FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE91E8C).withOpacity(0.3),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/safeher_logo.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield_rounded,
                          color: Color(0xFFE91E8C),
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Brand name
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Safe',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D1B35),
                            letterSpacing: -1.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Her',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFE91E8C),
                            letterSpacing: -1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tamil Nadu Women Safety',
                    style: TextStyle(
                      color: Color(0xFF8C7B90),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Color(0xFFE91E8C),
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Main Shell ────────────────────────────────────────────────────────────────
// PAGE INDICES (must match _pages list AND bottom nav):
//   0 = Home/Dashboard
//   1 = AI Chat
//   2 = SOS
//   3 = Map
//   4 = Safety/Resources
//   5 = Hotels
//   6 = Community

class MainShell extends StatefulWidget {
  final VoidCallback onLogout;
  const MainShell({super.key, required this.onLogout});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;
  late final List<Widget> _pages;

  static const Color _pink   = Color(0xFFE91E8C);
  static const Color _sosRed = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardPage(onNavigate: _navigate),   // 0
      const ChatPage(),                         // 1
      const SOSPage(),                          // 2
      const MapPage(),                          // 3
      const ResourcesPage(),                    // 4
      const HotelsPage(),                       // 5
      const CommunityPage(),                    // 6
    ];
  }

  void _navigate(int i) {
    if (i == -1) {
      // Logout signal from dashboard
      AuthService.logout().then((_) => widget.onLogout());
    } else {
      setState(() => _idx = i);
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(onLogout: widget.onLogout),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _idx, children: _pages),
          // Settings gear only visible on Home tab
          if (_idx == 0)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: IconButton(
                    onPressed: _openSettings,
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.settings_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
              color: _pink.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
        border: Border(
            top: BorderSide(color: _pink.withOpacity(0.15), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _tab(0, Icons.home_outlined,               Icons.home_rounded,          'Home'),
              _tab(1, Icons.chat_bubble_outline_rounded,  Icons.chat_bubble_rounded,  'AI Chat'),
              _sosTap(),
              _tab(3, Icons.map_outlined,                Icons.map_rounded,           'Map'),
              _tab(4, Icons.shield_outlined,             Icons.shield_rounded,        'Safety'),
              _tab(5, Icons.hotel_outlined,              Icons.hotel_rounded,         'Hotels'),
              _tab(6, Icons.people_outline_rounded,      Icons.people_rounded,        'Community'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int i, IconData icon, IconData activeIcon, String label) {
    final active = _idx == i;
    return GestureDetector(
      onTap: () => setState(() => _idx = i),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: active
                    ? _pink.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                active ? activeIcon : icon,
                color: active ? _pink : Colors.grey[400],
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                letterSpacing: -0.2,
                fontWeight:
                    active ? FontWeight.w800 : FontWeight.w500,
                color: active ? _pink : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sosTap() {
    final active = _idx == 2;
    return GestureDetector(
      onTap: () => setState(() => _idx = 2),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFB71C1C), _sosRed]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: _sosRed.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ],
              ),
              child: const Icon(Icons.sos_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              'SOS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: active ? _sosRed : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
