import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// ── Seeded community posts (always visible, never empty) ──────────────────────
const _seededPosts = [
  {
    'id': 'seed_1', 'is_seed': true,
    'user_name': 'Priya M.', 'category': 'safety_tip',
    'title': 'Marina Beach — Evening Walk',
    'content': 'Visited Marina Beach around 7 PM. Well-lit, police patrol clearly visible, families all around. Felt completely safe.',
    'location_name': 'Marina Beach, Chennai',
    'safety_rating': 5, 'likes': 47, 'created_at': '2026-03-06T19:30:00',
    'badge': 'Verified Travel Insight',
  },
  {
    'id': 'seed_2', 'is_seed': true,
    'user_name': 'Sneha R.', 'category': 'experience',
    'title': 'T Nagar Shopping — Very Safe',
    'content': 'T Nagar is crowded but well monitored. Security guards at most shops, lots of people even after 9 PM. Recommend sticking to main roads.',
    'location_name': 'T Nagar, Chennai',
    'safety_rating': 4, 'likes': 38, 'created_at': '2026-03-06T14:00:00',
    'badge': 'Verified Travel Insight',
  },
  {
    'id': 'seed_3', 'is_seed': true,
    'user_name': 'Divya K.', 'category': 'warning',
    'title': 'Egmore Station — Late Night Caution',
    'content': 'Good transport hub but avoid isolated platform areas after midnight. The main concourse is fine. Use prepaid auto counters only.',
    'location_name': 'Egmore, Chennai',
    'safety_rating': 3, 'likes': 62, 'created_at': '2026-03-05T23:00:00',
    'badge': 'Verified Travel Insight',
  },
  {
    'id': 'seed_4', 'is_seed': true,
    'user_name': 'Aishwarya T.', 'category': 'safety_tip',
    'title': 'Ooty — Solo Trip Tips',
    'content': 'Travelled to Ooty alone last weekend. The town is very safe. Hotel staff helpful, and there are tourist police booths. Recommend Ola cabs over local autos at night.',
    'location_name': 'Ooty, Nilgiris',
    'safety_rating': 5, 'likes': 89, 'created_at': '2026-03-04T11:00:00',
    'badge': 'Verified Travel Insight',
  },
  {
    'id': 'seed_5', 'is_seed': true,
    'user_name': 'Kavitha N.', 'category': 'attraction',
    'title': 'Pondicherry — Peaceful & Safe',
    'content': 'White Town in Pondicherry is one of the safest places I\'ve visited in TN. Well-maintained roads, lots of cafes open late, and French Quarter is well-patrolled.',
    'location_name': 'White Town, Pondicherry',
    'safety_rating': 5, 'likes': 103, 'created_at': '2026-03-03T16:00:00',
    'badge': 'Verified Travel Insight',
  },
  {
    'id': 'seed_6', 'is_seed': true,
    'user_name': 'Meena S.', 'category': 'safety_tip',
    'title': 'Metro Travel Tips — Chennai',
    'content': 'Chennai Metro is excellent for solo travel. Dedicated women\'s coaches, well-lit stations, security at every exit. Runs until 10 PM. Best option after dark.',
    'location_name': 'Chennai Metro',
    'safety_rating': 5, 'likes': 76, 'created_at': '2026-03-02T08:00:00',
    'badge': 'Verified Travel Insight',
  },
];

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _userPosts = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  Map<String, dynamic>? _user;
  late TabController _tabCtrl;

  static const Color pink   = Color(0xFFE91E8C);
  static const Color purple = Color(0xFF7C3AED);

  static const _filters = [
    {'key': 'all',        'label': 'All',        'icon': Icons.apps_rounded},
    {'key': 'safety_tip', 'label': 'Safety Tips', 'icon': Icons.security_rounded},
    {'key': 'warning',    'label': 'Alerts',      'icon': Icons.warning_amber_rounded},
    {'key': 'experience', 'label': 'Experiences', 'icon': Icons.explore_rounded},
    {'key': 'attraction', 'label': 'Places',      'icon': Icons.place_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _filters.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) return;
      setState(() => _filter = _filters[_tabCtrl.index]['key'] as String);
    });
    _loadUser();
    _fetchPosts();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = await AuthService.getUser();
    if (mounted) setState(() => _user = u);
  }

  Future<void> _fetchPosts() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.getCommunityPosts();
      if (mounted) {
        setState(() {
          _loading = false;
          if (res['success'] == true) {
            final raw = (res['posts'] as List?) ?? [];
            _userPosts = raw.map((p) => Map<String, dynamic>.from(p as Map)).toList();
          } else {
            _error = res['error']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Could not reach server.'; });
    }
  }

  List<Map<String, dynamic>> get _allPosts {
    // Merge seeded + user posts, seeded always at end so user posts appear first
    final seeded = _seededPosts.map((p) => Map<String, dynamic>.from(p)).toList();
    return [..._userPosts, ...seeded];
  }

  List<Map<String, dynamic>> get _filteredPosts {
    if (_filter == 'all') return _allPosts;
    return _allPosts.where((p) => p['category'] == _filter).toList();
  }

  Future<void> _like(String postId, int idx) async {
    if (postId.startsWith('seed_')) {
      // Local like for seeded posts
      setState(() {
        final i = _filteredPosts.indexWhere((p) => p['id'] == postId);
        if (i >= 0) _filteredPosts[i]['likes'] = (_filteredPosts[i]['likes'] ?? 0) + 1;
      });
      return;
    }
    final res = await _api.likePost(postId);
    if (mounted && res['success'] == true) {
      setState(() {
        final i = _userPosts.indexWhere((p) => p['id'] == postId);
        if (i >= 0) _userPosts[i]['likes'] = res['likes'];
      });
    }
  }

  void _showNewPost() {
    final titleCtrl    = TextEditingController();
    final contentCtrl  = TextEditingController();
    final locationCtrl = TextEditingController();
    String cat = 'experience';
    bool sending = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final sheetBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
        final fieldBg = isDark ? const Color(0xFF0F0F1F) : const Color(0xFFF3F4F6);
        final txtColor = isDark ? Colors.white : const Color(0xFF111827);

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 44, height: 4, margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              Text('Share Your Experience', style: TextStyle(color: txtColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Help women travel safer in Tamil Nadu', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 22),
              _sheetField(titleCtrl, 'Title', Icons.title_rounded, fieldBg, txtColor),
              const SizedBox(height: 12),
              _sheetField(locationCtrl, 'Location (e.g. Marina Beach)', Icons.place_rounded, fieldBg, txtColor),
              const SizedBox(height: 12),
              _sheetField(contentCtrl, 'Share your experience...', Icons.notes_rounded, fieldBg, txtColor, maxLines: 4),
              const SizedBox(height: 18),
              // Category chips
              SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, children: [
                'experience', 'safety_tip', 'warning', 'attraction'
              ].map((c) {
                final sel = c == cat;
                return GestureDetector(
                  onTap: () => setS(() => cat = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? pink : (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF3F4F6)),
                      borderRadius: BorderRadius.circular(12)),
                    child: Text(c.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(color: sel ? Colors.white : Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                );
              }).toList())),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: sending ? null : () async {
                  if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) return;
                  setS(() => sending = true);
                  final res = await _api.createCommunityPost(
                    userName: _user?['name'] ?? 'Traveler',
                    title: titleCtrl.text.trim(),
                    content: contentCtrl.text.trim(),
                    locationName: locationCtrl.text.trim(),
                    category: cat,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (res['success'] == true) _fetchPosts();
                },
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [pink, purple]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: pink.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Center(child: Text(sending ? 'Sharing...' : 'Post to Community',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint, IconData icon, Color bg, Color txtColor, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: TextField(
        controller: ctrl, maxLines: maxLines,
        style: TextStyle(color: txtColor, fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
          prefixIcon: Icon(icon, color: pink, size: 20),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF8F4FF);
    final cardBg  = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final txtDark = isDark ? Colors.white : const Color(0xFF111827);
    final txtGrey = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final posts = _filteredPosts;

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('SafeHer Circle', style: TextStyle(color: txtDark, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                          const SizedBox(height: 2),
                          Text('${_allPosts.length} stories from Tamil Nadu', style: TextStyle(color: txtGrey, fontSize: 12)),
                        ]),
                        GestureDetector(
                          onTap: _fetchPosts,
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: pink.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.refresh_rounded, color: pink, size: 20)),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                child: TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  labelColor: pink,
                  unselectedLabelColor: txtGrey,
                  indicatorColor: pink,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  tabs: _filters.map((f) => Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(f['icon'] as IconData, size: 15),
                      const SizedBox(width: 6),
                      Text(f['label'] as String),
                    ]),
                  )).toList(),
                ),
              ),
            ),
          ),
        ],
        body: _loading
            ? Center(child: CircularProgressIndicator(color: pink))
            : RefreshIndicator(
                onRefresh: _fetchPosts,
                color: pink,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: posts.isEmpty ? 1 : posts.length,
                  itemBuilder: (ctx, i) {
                    if (posts.isEmpty) return _emptyState(txtDark, txtGrey);
                    return _postCard(posts[i], i, isDark, cardBg, txtDark, txtGrey);
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () { HapticFeedback.lightImpact(); _showNewPost(); },
        backgroundColor: pink,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post, int idx, bool isDark, Color cardBg, Color txtDark, Color txtGrey) {
    final cat = post['category'] as String? ?? 'experience';
    final isSeed = post['is_seed'] == true;
    final isAlert = cat == 'warning';
    final rating = (post['safety_rating'] as int?) ?? 4;

    final catMeta = {
      'experience': {'color': const Color(0xFF7C3AED), 'label': 'Experience', 'icon': Icons.explore_rounded},
      'safety_tip': {'color': const Color(0xFF059669), 'label': 'Safety Tip', 'icon': Icons.security_rounded},
      'warning':    {'color': const Color(0xFFDC2626), 'label': '⚠️ Alert',    'icon': Icons.warning_rounded},
      'attraction': {'color': const Color(0xFF0284C7), 'label': 'Place',       'icon': Icons.place_rounded},
      'food':       {'color': const Color(0xFFD97706), 'label': 'Food',        'icon': Icons.restaurant_rounded},
    };
    final meta = catMeta[cat] ?? catMeta['experience']!;
    final catColor = meta['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: isAlert ? Border.all(color: const Color(0xFFDC2626).withOpacity(0.3), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Row(children: [
            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [catColor, catColor.withOpacity(0.6)],
                ),
              ),
              child: Center(child: Text(
                (post['user_name'] as String? ?? 'T')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post['user_name'] ?? 'Traveler',
                style: TextStyle(color: txtDark, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 2),
              Text(_relTime(post['created_at']),
                style: TextStyle(color: txtGrey, fontSize: 11)),
            ])),
            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: catColor.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(meta['icon'] as IconData, size: 11, color: catColor),
                const SizedBox(width: 4),
                Text(meta['label'] as String, style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.w900)),
              ]),
            ),
          ]),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post['title'] ?? '', style: TextStyle(color: txtDark, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3, height: 1.3)),
            const SizedBox(height: 8),
            Text(post['content'] ?? '', style: TextStyle(color: txtGrey, fontSize: 13, height: 1.55)),
          ]),
        ),

        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Row(children: [
            // Location tag
            if ((post['location_name'] as String?)?.isNotEmpty == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A1A4E) : const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.place_rounded, size: 12, color: purple),
                  const SizedBox(width: 4),
                  Text(post['location_name'] as String,
                    style: TextStyle(color: purple, fontSize: 11, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            const Spacer(),
            // Star rating
            Row(children: List.generate(5, (i) => Icon(
              i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 14, color: i < rating ? const Color(0xFFF59E0B) : Colors.grey[400],
            ))),
            const SizedBox(width: 12),
            // Like button
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); _like(post['id'] as String, idx); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A1A1A) : const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.favorite_rounded, color: Color(0xFFE91E8C), size: 14),
                  const SizedBox(width: 5),
                  Text('${post['likes'] ?? 0}',
                    style: TextStyle(color: txtDark, fontWeight: FontWeight.w900, fontSize: 12)),
                ]),
              ),
            ),
          ]),
        ),

        // Seed badge
        if (isSeed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(isDark ? 0.15 : 0.07),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.verified_rounded, size: 13, color: const Color(0xFF059669).withOpacity(0.8)),
              const SizedBox(width: 5),
              Text('Verified Travel Insight', style: TextStyle(color: const Color(0xFF059669).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w800)),
            ]),
          ),
      ]),
    );
  }

  Widget _emptyState(Color txtDark, Color txtGrey) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🌺', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 16),
        Text('No posts in this category yet', style: TextStyle(color: txtDark, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Be the first to share!', style: TextStyle(color: txtGrey, fontSize: 14)),
      ]),
    );
  }

  String _relTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final d    = DateTime.parse(raw.toString()).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24)  return '${diff.inHours}h ago';
      if (diff.inDays    < 7)   return '${diff.inDays}d ago';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) { return ''; }
  }
}
