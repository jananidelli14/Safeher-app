import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  static const Color primaryPink = Color(0xFFE91E8C);
  static const Color lightPink = Color(0xFFFCE4F0);
  static const Color accentPurple = Color(0xFF9C27B0);
  static const Color textDark = Color(0xFF2D1B35);
  static const Color textGrey = Color(0xFF8C7B90);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter your email and password');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final res = await _api.loginWithEmail(
        email: _emailCtrl.text.trim(), password: _passCtrl.text);
    if (mounted) {
      setState(() => _loading = false);
      if (res['success'] == true) {
        widget.onLoginSuccess();
      } else {
        setState(() => _error = res['error'] ?? 'Login failed. Check your credentials.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF0F8), Color(0xFFF8F0FF), Color(0xFFFFF0F8)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),

                    // Logo + Brand
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFD6EC), Color(0xFFEDD6FF)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryPink.withOpacity(0.3),
                                  blurRadius: 24, offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/safeher_logo.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: primaryPink.withOpacity(0.1),
                                  child: const Icon(Icons.shield_rounded,
                                      color: primaryPink, size: 52),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          RichText(
                            text: const TextSpan(children: [
                              TextSpan(
                                text: 'Safe',
                                style: TextStyle(
                                  fontSize: 32, fontWeight: FontWeight.w900,
                                  color: textDark, letterSpacing: -1,
                                ),
                              ),
                              TextSpan(
                                text: 'Her',
                                style: TextStyle(
                                  fontSize: 32, fontWeight: FontWeight.w900,
                                  color: primaryPink, letterSpacing: -1,
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryPink.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "Tamil Nadu's Women Safety Companion 💜",
                              style: TextStyle(
                                color: primaryPink, fontSize: 12, fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: primaryPink.withOpacity(0.1),
                            blurRadius: 30, offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Welcome Back! 👋',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                                color: textDark, letterSpacing: -0.5)),
                          const SizedBox(height: 4),
                          const Text('Sign in to your account',
                            style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 24),

                          _buildField(controller: _emailCtrl, label: 'Email Address',
                              icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 14),
                          _buildField(controller: _passCtrl, label: 'Password',
                              icon: Icons.lock_outline_rounded, isPassword: true),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text('Forgot Password?',
                                style: TextStyle(color: primaryPink, fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ),

                          if (_error != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFCDD2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_error!,
                                    style: const TextStyle(color: Color(0xFFE53935), fontSize: 13, fontWeight: FontWeight.w600))),
                                ],
                              ),
                            ),

                          _buildGradientButton(
                              label: _loading ? 'Signing in...' : 'Login →',
                              onTap: _loading ? null : _login,
                              isLoading: _loading),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? ",
                            style: TextStyle(color: textGrey, fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => SignupPage(onSignupSuccess: widget.onLoginSuccess))),
                          child: const Text('Sign Up',
                              style: TextStyle(color: primaryPink, fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B9D), Color(0xFFE91E8C)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emergency_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text('Emergency? Call 100 | Women Helpline: 1091',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE91E8C).withOpacity(0.15)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword ? _obscurePassword : false,
        style: const TextStyle(color: textDark, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: textGrey, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFFE91E8C).withOpacity(0.7), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: textGrey, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword))
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildGradientButton({required String label, required VoidCallback? onTap, bool isLoading = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: onTap != null
              ? const LinearGradient(colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)])
              : const LinearGradient(colors: [Colors.grey, Colors.grey]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap != null
              ? [BoxShadow(color: const Color(0xFFE91E8C).withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5))]
              : [],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
        ),
      ),
    );
  }
}
