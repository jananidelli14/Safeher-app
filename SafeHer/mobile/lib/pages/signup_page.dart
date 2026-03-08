import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class SignupPage extends StatefulWidget {
  final VoidCallback onSignupSuccess;
  const SignupPage({super.key, required this.onSignupSuccess});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _loading = false;
  String? _error;
  bool _obscurePass = true;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _healthCtrl = TextEditingController();
  bool _consentAgreed = false;
  final List<TextEditingController> _contactCtrls = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;

  static const Color primaryPink = Color(0xFFE91E8C);
  static const Color accentPurple = Color(0xFF9C27B0);
  static const Color textDark = Color(0xFF2D1B35);
  static const Color textGrey = Color(0xFF8C7B90);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _passCtrl.dispose(); _cityCtrl.dispose(); _healthCtrl.dispose();
    for (final c in _contactCtrls) { c.dispose(); }
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passCtrl.text;
    final city = _cityCtrl.text.trim();

    if (name.isEmpty) { setState(() => _error = 'Please enter your full name'); return; }
    if (email.isEmpty) { setState(() => _error = 'Please enter your email'); return; }
    if (phone.isEmpty) { setState(() => _error = 'Please enter your phone number'); return; }
    if (password.length < 6) { setState(() => _error = 'Password must be at least 6 characters'); return; }
    if (city.isEmpty) { setState(() => _error = 'Please enter your city'); return; }
    if (!_consentAgreed) { setState(() => _error = 'Please agree to the terms to continue'); return; }

    final contacts = _contactCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (contacts.isEmpty) { setState(() => _error = 'Add at least one emergency contact'); return; }

    setState(() { _loading = true; _error = null; });

    final res = await _api.register(
      name: name, email: email, phone: phone, city: city,
      password: password, emergencyContacts: contacts,
      healthConditions: _healthCtrl.text.trim(), consentAgreed: _consentAgreed,
    );

    if (mounted) {
      setState(() => _loading = false);
      if (res['success'] == true) {
        widget.onSignupSuccess();
      } else {
        setState(() => _error = res['error'] ?? 'Registration failed. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFFFF0F8), Color(0xFFF8F0FF), Color(0xFFFFF0F8)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with back button and logo
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.1), blurRadius: 8)],
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: primaryPink, size: 18),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 48, height: 48,
                        child: ClipOval(
                          child: Image.asset('assets/images/safeher_logo.jpg', fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: primaryPink.withOpacity(0.1),
                              child: const Icon(Icons.shield_rounded, color: primaryPink, size: 24),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Title
                  RichText(
                    text: const TextSpan(children: [
                      TextSpan(text: 'Join ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5)),
                      TextSpan(text: 'SafeHer', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: -0.5)),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  const Text('Create your safety profile for Tamil Nadu',
                    style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 24),

                  // Personal Info Card
                  _buildCard(
                    title: '👤 Personal Information',
                    children: [
                      _buildField(_nameCtrl, 'Full Name', Icons.person_outline_rounded),
                      _buildField(_emailCtrl, 'Email Address', Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress),
                      _buildField(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
                          keyboardType: TextInputType.phone),
                      _buildField(_cityCtrl, 'City (Tamil Nadu)', Icons.location_city_outlined),
                      _buildPasswordField(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Emergency Contacts Card
                  _buildCard(
                    title: '🆘 Emergency Contacts',
                    subtitle: 'They\'ll be alerted when you trigger SOS',
                    children: List.generate(3, (i) => _buildField(
                      _contactCtrls[i],
                      'Contact ${i + 1} Phone Number',
                      Icons.contact_phone_outlined,
                      keyboardType: TextInputType.phone,
                      isRequired: i == 0,
                    )),
                  ),
                  const SizedBox(height: 16),

                  // Health Card
                  _buildCard(
                    title: '💊 Health Information (Optional)',
                    subtitle: 'Helps emergency responders',
                    children: [
                      _buildField(_healthCtrl, 'Any health conditions, allergies...',
                          Icons.medical_information_outlined, maxLines: 2),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Consent
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _consentAgreed ? primaryPink : Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.06), blurRadius: 16)],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _consentAgreed,
                          onChanged: (v) => setState(() => _consentAgreed = v ?? false),
                          activeColor: primaryPink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        const Expanded(
                          child: Text(
                            'I agree to SafeHer\'s Terms of Service and Privacy Policy. I understand my location may be shared with emergency contacts and services when SOS is triggered.',
                            style: TextStyle(color: textGrey, fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

                  // Create Account Button
                  GestureDetector(
                    onTap: _loading ? null : _register,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [primaryPink, accentPurple]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5))],
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Create My SafeHer Account →',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, String? subtitle, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFFE91E8C).withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: textGrey, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          ...children.expand((w) => [w, const SizedBox(height: 12)]).take(children.length * 2 - 1),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text, bool isRequired = false, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE91E8C).withOpacity(0.12)),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: textDark, fontWeight: FontWeight.w500, fontSize: 14),
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          labelStyle: TextStyle(
              color: isRequired ? const Color(0xFFE91E8C).withOpacity(0.8) : textGrey,
              fontSize: 13),
          prefixIcon: Icon(icon, color: const Color(0xFFE91E8C).withOpacity(0.6), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE91E8C).withOpacity(0.12)),
      ),
      child: TextField(
        controller: _passCtrl,
        obscureText: _obscurePass,
        style: const TextStyle(color: textDark, fontWeight: FontWeight.w500, fontSize: 14),
        decoration: InputDecoration(
          labelText: 'Password *',
          labelStyle: TextStyle(color: const Color(0xFFE91E8C).withOpacity(0.8), fontSize: 13),
          prefixIcon: Icon(Icons.lock_outline_rounded, color: const Color(0xFFE91E8C).withOpacity(0.6), size: 18),
          suffixIcon: IconButton(
            icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: textGrey, size: 18),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
