import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../main.dart' show themeNotifier;

class SettingsPage extends StatefulWidget {
  final VoidCallback onLogout;
  const SettingsPage({super.key, required this.onLogout});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _profile;
  List<dynamic> _contacts = [];
  bool _loadingProfile = true;
  bool _isDark = false;

  static const Color pink   = Color(0xFFE91E8C);
  static const Color purple = Color(0xFF9C27B0);
  static const Color red    = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _isDark = themeNotifier.isDark;
    themeNotifier.addListener(_onThemeChange);
    _loadProfile();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() => _isDark = themeNotifier.isDark);
  }

  Future<void> _loadProfile() async {
    // First: immediately show locally cached user so UI is never blank
    final localUser = await AuthService.getUser();
    if (mounted && localUser != null) {
      setState(() {
        _profile = localUser;
        _loadingProfile = false;
      });
    }
    // Then try to refresh from backend (works when server is running)
    try {
      final res  = await _api.getProfile();
      final cRes = await _api.getEmergencyContacts();
      if (mounted) {
        setState(() {
          if (res['success'] == true) {
            _profile = res['profile'] ?? res['user'] ?? _profile;
          }
          _contacts = cRes['success'] == true ? (cRes['contacts'] ?? []) : [];
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  // ── Edit Name Dialog ────────────────────────────────────────────────────────
  void _showEditNameDialog() {
    final ctrl = TextEditingController(text: _profile?['name'] ?? '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit Name', style: TextStyle(fontWeight: FontWeight.w900)),
      content: _field(ctrl, 'Your Name', Icons.person_outline_rounded),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: pink, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            Navigator.pop(ctx);
            // Update locally (API update can be added if backend supports it)
            final newName = ctrl.text.trim();
            if (mounted) setState(() { _profile?['name'] = newName; });
            await AuthService.updateUserField('name', newName);
            _showSnack('✅ Name updated');
          },
          child: const Text('Save'),
        ),
      ],
    ));
  }

  // ── Change Password ─────────────────────────────────────────────────────────
  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    String? error;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w900)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12),
          child: Text(error!, style: const TextStyle(color: red, fontSize: 13))),
        _field(oldCtrl, 'Current Password', Icons.lock_outline_rounded, isPassword: true),
        const SizedBox(height: 12),
        _field(newCtrl, 'New Password (min 8 chars)', Icons.lock_person_outlined, isPassword: true),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            if (oldCtrl.text.isEmpty || newCtrl.text.isEmpty) { setD(() => error = 'Both fields required'); return; }
            if (newCtrl.text.length < 8) { setD(() => error = 'Min 8 characters'); return; }
            final res = await _api.changePassword(oldPassword: oldCtrl.text, newPassword: newCtrl.text);
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) _showSnack(res['success'] == true ? '✅ Password updated' : (res['error'] ?? 'Failed'));
          },
          child: const Text('Update'),
        ),
      ],
    )));
  }

  // ── Add Contact ─────────────────────────────────────────────────────────────
  void _showAddContactDialog() {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Emergency Contact', style: TextStyle(fontWeight: FontWeight.w900)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(nameCtrl, 'Contact Name', Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _field(phoneCtrl, 'Phone Number (+91XXXXXXXXXX)', Icons.phone_outlined, type: TextInputType.phone),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            if (phoneCtrl.text.isEmpty) return;
            final res = await _api.addEmergencyContact(
              contactName: nameCtrl.text.trim().isEmpty ? 'Emergency Contact' : nameCtrl.text.trim(),
              contactPhone: phoneCtrl.text.trim());
            if (ctx.mounted) Navigator.pop(ctx);
            if (res['success'] == true) { _loadProfile(); if (mounted) _showSnack('✅ Contact added'); }
            else { if (mounted) _showSnack(res['error'] ?? 'Failed'); }
          },
          child: const Text('Add'),
        ),
      ],
    ));
  }

  Future<void> _deleteContact(String contactId) async {
    final res = await _api.deleteEmergencyContact(contactId);
    if (res['success'] == true) { _loadProfile(); if (mounted) _showSnack('Contact removed'); }
    else { if (mounted) _showSnack(res['error'] ?? 'Failed'); }
  }

  void _showLogoutDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w900)),
      content: const Text('Are you sure you want to logout from SafeHer?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () { Navigator.pop(ctx); AuthService.logout().then((_) => widget.onLogout()); },
          child: const Text('Logout'),
        ),
      ],
    ));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3)));
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bg = _isDark ? const Color(0xFF12121A) : const Color(0xFFF4F4F8);
    final cardColor = _isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textDark = _isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textGrey = _isDark ? Colors.grey[400]! : const Color(0xFF8E8E93);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 20, color: textDark),
          onPressed: () => Navigator.pop(context)),
        title: Text('Settings', style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 22)),
        actions: [
          // Quick dark mode toggle in AppBar
          IconButton(
            icon: Icon(_isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _isDark ? Colors.amber : Colors.blueGrey),
            onPressed: () => themeNotifier.toggle(),
            tooltip: _isDark ? 'Light Mode' : 'Dark Mode',
          ),
        ],
      ),
      body: _loadingProfile
          ? Center(child: CircularProgressIndicator(color: pink))
          : ListView(padding: const EdgeInsets.all(20), children: [

          // ── Profile Card (like real apps: avatar + name + edit) ─────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              // Avatar circle
              Container(width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)])),
                child: Center(child: Text(
                  (_profile?['name'] ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_profile?['name'] ?? '—', style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 2),
                Text(_profile?['email'] ?? '—', style: TextStyle(color: textGrey, fontSize: 13)),
                if ((_profile?['phone'] ?? '').isNotEmpty)
                  Text(_profile!['phone'], style: TextStyle(color: textGrey, fontSize: 12)),
              ])),
              IconButton(
                icon: Icon(Icons.edit_rounded, color: pink, size: 22),
                onPressed: _showEditNameDialog),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Appearance ─────────────────────────────────────────────────
          _sectionHeader('APPEARANCE', textGrey),
          _settingsCard(cardColor, [
            _switchTile(
              icon: _isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              iconColor: _isDark ? Colors.amber : Colors.blueGrey,
              label: 'Dark Mode',
              subtitle: _isDark ? 'Currently using dark theme' : 'Currently using light theme',
              value: _isDark,
              onChanged: (_) => themeNotifier.toggle(),
              textDark: textDark, textGrey: textGrey, cardColor: cardColor,
            ),
          ]),

          const SizedBox(height: 20),

          // ── Account ────────────────────────────────────────────────────
          _sectionHeader('ACCOUNT', textGrey),
          _settingsCard(cardColor, [
            _settingsTile(icon: Icons.person_outline_rounded, iconColor: purple,
              label: 'Edit Name', subtitle: _profile?['name'] ?? '',
              onTap: _showEditNameDialog, textDark: textDark, textGrey: textGrey, cardColor: cardColor),
            _divider(),
            _settingsTile(icon: Icons.lock_outline_rounded, iconColor: purple,
              label: 'Change Password', subtitle: 'Update your password',
              onTap: _showChangePasswordDialog, textDark: textDark, textGrey: textGrey, cardColor: cardColor),
          ]),

          const SizedBox(height: 20),

          // ── Emergency Contacts ─────────────────────────────────────────
          _sectionHeader('EMERGENCY CONTACTS (${_contacts.length})', textGrey),
          _settingsCard(cardColor, [
            if (_contacts.isEmpty) Padding(padding: const EdgeInsets.all(16),
              child: Text('No contacts added yet. Add them so SafeHer can alert them in an SOS.',
                style: TextStyle(color: textGrey, fontSize: 13))),
            ..._contacts.asMap().entries.map((e) => Column(children: [
              _contactTile(e.value, textDark, textGrey, cardColor),
              if (e.key < _contacts.length - 1) _divider(),
            ])),
            if (_contacts.isNotEmpty) _divider(),
            _settingsTile(icon: Icons.add_circle_outline_rounded, iconColor: Colors.green,
              label: 'Add Emergency Contact', subtitle: 'They will be alerted on SOS',
              onTap: _showAddContactDialog, textDark: textDark, textGrey: textGrey, cardColor: cardColor),
          ]),

          const SizedBox(height: 20),

          // ── About ──────────────────────────────────────────────────────
          _sectionHeader('ABOUT', textGrey),
          _settingsCard(cardColor, [
            _settingsTile(icon: Icons.info_outline_rounded, iconColor: Colors.blue,
              label: 'SafeHer v1.0', subtitle: 'Women Safety App for Tamil Nadu',
              onTap: () {}, trailing: const SizedBox.shrink(),
              textDark: textDark, textGrey: textGrey, cardColor: cardColor),
            _divider(),
            _settingsTile(icon: Icons.phone_rounded, iconColor: Colors.red,
              label: 'Emergency Helplines', subtitle: 'Police: 100 | Women: 1091 | Emergency: 112',
              onTap: () {}, trailing: const SizedBox.shrink(),
              textDark: textDark, textGrey: textGrey, cardColor: cardColor),
            _divider(),
            _settingsTile(icon: Icons.privacy_tip_outlined, iconColor: Colors.teal,
              label: 'Privacy Policy', subtitle: 'How we protect your data',
              onTap: () async {
                try { await launchUrl(Uri.parse('https://safeher.app/privacy'), mode: LaunchMode.externalApplication); } catch (_) {}
              }, textDark: textDark, textGrey: textGrey, cardColor: cardColor),
          ]),

          const SizedBox(height: 28),

          // ── Logout Button ──────────────────────────────────────────────
          GestureDetector(
            onTap: _showLogoutDialog,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: red.withOpacity(0.3)),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.logout_rounded, color: red, size: 22),
                SizedBox(width: 10),
                Text('Logout', style: TextStyle(color: red, fontWeight: FontWeight.w900, fontSize: 16)),
              ]),
            ),
          ),

          const SizedBox(height: 40),
        ]),
    );
  }

  // ── Widget Helpers ──────────────────────────────────────────────────────────

  Widget _sectionHeader(String label, Color color) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)));

  Widget _settingsCard(Color cardColor, List<Widget> children) => Container(
    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
    child: Column(children: children));

  Widget _divider() => Divider(height: 1, thickness: 1, indent: 52, endIndent: 16, color: Colors.grey.withOpacity(0.1));

  Widget _settingsTile({
    required IconData icon, required Color iconColor, required String label,
    required String subtitle, required VoidCallback onTap,
    required Color textDark, required Color textGrey, required Color cardColor,
    Widget? trailing,
  }) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(18),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: textDark, fontWeight: FontWeight.w700, fontSize: 14)),
          if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: textGrey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        trailing ?? Icon(Icons.chevron_right_rounded, color: textGrey, size: 20),
      ])),
  );

  Widget _switchTile({
    required IconData icon, required Color iconColor, required String label,
    required String subtitle, required bool value, required ValueChanged<bool> onChanged,
    required Color textDark, required Color textGrey, required Color cardColor,
  }) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 20)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: textDark, fontWeight: FontWeight.w700, fontSize: 14)),
        Text(subtitle, style: TextStyle(color: textGrey, fontSize: 12)),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFFE91E8C)),
    ]));

  Widget _contactTile(dynamic contact, Color textDark, Color textGrey, Color cardColor) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.contact_emergency_rounded, color: Colors.green, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(contact['contact_name'] ?? 'Emergency Contact',
            style: TextStyle(color: textDark, fontWeight: FontWeight.w700, fontSize: 13)),
          Text(contact['contact_phone'] ?? '', style: TextStyle(color: textGrey, fontSize: 12)),
        ])),
        IconButton(icon: const Icon(Icons.remove_circle_rounded, color: red, size: 22),
          onPressed: () => _deleteContact(contact['id']?.toString() ?? '')),
      ]));

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool isPassword = false, TextInputType? type}) =>
    Container(
      decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(12)),
      child: TextField(controller: ctrl, obscureText: isPassword, keyboardType: type,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label, labelStyle: const TextStyle(fontSize: 13),
          prefixIcon: Icon(icon, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))));
}
