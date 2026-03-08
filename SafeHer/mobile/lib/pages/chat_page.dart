import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import '../services/location_service.dart';
import '../services/auth_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  Position? _pos;
  String? _conversationId;
  String? _selectedImageBase64;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  String? _currentRecordingPath;
  String _userId = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;
  final List<double> _waveformBars = List.generate(24, (_) => 0.3);

  // SafeHer Brand Colors
  static const Color primaryPink = Color(0xFFE91E8C);
  static const Color accentPurple = Color(0xFF9C27B0);
  static const Color textDark = Color(0xFF2D1B35);
  static const Color textGrey = Color(0xFF8C7B90);
  static const Color bgColor = Color(0xFFFFF0F8);

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'text': "Vanakkam! 🙏 I'm SafeHer AI — your Tamil Nadu safety companion.\n\nAsk me anything like:\n• 🔍 \"Is Marina Beach safe at 10 PM?\"\n• 📍 \"Nearest police station to me right now\"\n• 🌤️ \"Weather in Ooty this week\"\n• 🚶‍♀️ \"Tips for traveling alone in Madurai\"\n• 🆘 \"I feel unsafe\" — for immediate help\n\nI use real-time location data to assess safety near you. How can I help? 💜",
    }
  ];
  bool _isLoading = false;
  bool _hasConnectionError = false;

  // Quick suggestion chips
  final List<String> _suggestions = [
    '🔍 Is this area safe now?',
    '🚔 Nearest police station',
    '🌙 Night travel tips',
    '📞 Emergency numbers',
    '🏥 Nearest hospital',
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
    _loadUser();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _waveController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150))
      ..addListener(() {
        if (_isRecording && mounted) {
          setState(() {
            _waveformBars.removeAt(0);
            _waveformBars.add(0.2 + Random().nextDouble() * 0.8);
          });
        }
      });
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (user != null && mounted) {
      setState(() => _userId = user['id'] ?? '');
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _getLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (mounted) setState(() => _pos = pos);
  }

  void _sendMessage({String? voiceBase64, String? predefinedText}) async {
    final textToSend = predefinedText ?? _controller.text.trim();
    final hasText = textToSend.isNotEmpty;
    final hasImage = _selectedImageBase64 != null;
    final hasVoice = voiceBase64 != null;

    if (!hasText && !hasImage && !hasVoice) return;
    if (_isLoading) return;

    final image = _selectedImageBase64;

    setState(() {
      String displayText;
      if (hasVoice) {
        displayText = "🎤 Voice message (${_recordingSeconds}s)${textToSend.isNotEmpty ? '\n$textToSend' : ''}";
      } else if (hasImage) {
        displayText = "📸 Photo${textToSend.isNotEmpty ? ': $textToSend' : ' attached'}";
      } else {
        displayText = textToSend;
      }
      _messages.add({'role': 'user', 'text': displayText, 'hasImage': hasImage, 'image': image, 'hasVoice': hasVoice});
      _isLoading = true;
      _hasConnectionError = false;
      _selectedImageBase64 = null;
    });
    if (predefinedText == null) _controller.clear();
    _scrollToBottom();

    // Try backend first; if it fails, call Gemini directly
    String aiReply = '';
    try {
      final response = await _apiService.sendMessage(
        message: textToSend,
        conversationId: _conversationId,
        location: _pos != null ? {'lat': _pos!.latitude, 'lng': _pos!.longitude} : null,
        imageBase64: image,
        voiceBase64: voiceBase64,
      ).timeout(const Duration(seconds: 8));

      if (response['success'] == true) {
        _conversationId = response['conversation_id'];
        aiReply = response['response'] ?? '';
      }
    } catch (_) {
      // Backend unreachable — fall through to direct Gemini call
    }

    // If backend gave no answer, call Gemini API directly
    if (aiReply.isEmpty) {
      aiReply = await _callGeminiDirect(textToSend);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasConnectionError = false;
        _messages.add({'role': 'assistant', 'text': aiReply});
      });
      _scrollToBottom();
    }
  }

  /// Calls Gemini 1.5 Flash directly — works even when backend is down
  // Calls Gemini via JS interop (no CORS) on web, backend proxy on native
  Future<String> _callGeminiDirect(String userMessage) async {
    // On Web: use the JS function injected in index.html (no CORS issues)
    if (kIsWeb) {
      try {
        final completer = Completer<String>();
        final lat = _pos?.latitude;
        final lng = _pos?.longitude;

        // Call window.callGeminiAI(message, lat, lng) -> Promise
        final jsPromise = js.context.callMethod('callGeminiAI', [
          userMessage,
          lat,
          lng,
        ]);

        // Convert JS Promise to Dart Future
        jsPromise.callMethod('then', [
          js.allowInterop((result) {
            if (result != null && result.toString().isNotEmpty) {
              completer.complete(result.toString());
            } else {
              completer.complete('');
            }
          })
        ]).callMethod('catch', [
          js.allowInterop((err) {
            debugPrint('JS Gemini error: \$err');
            completer.complete('');
          })
        ]);

        final reply = await completer.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () => '',
        );
        if (reply.isNotEmpty) return reply;
      } catch (e) {
        debugPrint('JS interop error: \$e');
      }
    }

    // Fallback: try backend proxy (works when backend is running)
    try {
      final url = Uri.parse('${ApiService.baseUrl}/chat/direct');
      final body = jsonEncode({
        'message': userMessage,
        if (_pos != null) 'location': {
          'lat': _pos!.latitude,
          'lng': _pos!.longitude,
        },
      });
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply = data['response']?.toString() ?? '';
        if (reply.isNotEmpty) return reply;
      }
    } catch (e) {
      debugPrint('Backend proxy error: \$e');
    }

    return 'Sorry, I could not connect to the AI. Emergency numbers: Police 100, Emergency 112, Women Helpline 1091, Ambulance 108.';
  }

  String _smartFallback(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('police') || m.contains('\u0b95\u0bbe\u0bb5\u0bb2\u0bcd')) {
      return '🚔 Nearest police help:\n'
          '- Dial 100 for police\n'
          '- Dial 112 for national emergency\n\n'
          'Open the Safety Map tab to see nearest police stations.';
    }
    if (m.contains('hospital') || m.contains('ambulance') || m.contains('\u0bae\u0bb0\u0bc1\u0ba4\u0bcd\u0ba4\u0bc1\u0bb5\u0bae\u0ba9\u0bc8')) {
      return '🏥 Medical emergency:\n'
          '- Ambulance: 108\n'
          '- Emergency: 112\n\n'
          'Open the Safety Map tab to see nearest hospitals.';
    }
    if (m.contains('safe') || m.contains('unsafe') || m.contains('\u0baa\u0bbe\u0ba4\u0bc1\u0b95\u0bbe\u0baa\u0bcd\u0baa\u0bc1')) {
      return '🛡️ If you feel unsafe right now:\n'
          '1. Go to a crowded public place\n'
          '2. Call 100 (Police) or 112 (Emergency)\n'
          '3. Use the SOS button in this app\n'
          '4. Share your location with a trusted contact';
    }
    if (m.contains('night') || m.contains('travel') || m.contains('alone')) {
      return '🌙 Night travel safety tips for Tamil Nadu:\n'
          '- Use Ola/Uber, not unmarked autos\n'
          '- Share live location with family\n'
          '- Stay in lit, populated areas\n'
          '- Chennai Metro has women\'s coaches\n'
          '- Emergency: 100, 112, 1091';
    }
    if (m.contains('hi') || m.contains('hello') || m.contains('vanakkam')) {
      return 'Vanakkam! 🙏 I\'m SafeHer AI.\n\n'
          'I can help with:\n'
          '- Safety tips for Tamil Nadu\n'
          '- Nearest police and hospitals (open map)\n'
          '- Night travel advice\n'
          '- Emergency numbers\n\n'
          'Emergency: Police 100 | Emergency 112 | Women Helpline 1091';
    }
    return '🛡️ SafeHer AI - Emergency numbers:\n'
        '- Police: 100\n'
        '- Emergency: 112\n'
        '- Women Helpline: 1091\n'
        '- Ambulance: 108\n\n'
        'Start the backend for full AI: cd SafeHer/backend && python app.py';
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Add a Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2D1B35))),
            const SizedBox(height: 20),
            _buildSourceOption(icon: Icons.camera_alt_rounded, color: primaryPink, label: 'Camera', subtitle: 'Take a photo to analyze', onTap: () { Navigator.pop(ctx); _pickImageFromSource(ImageSource.camera); }),
            const SizedBox(height: 12),
            _buildSourceOption(icon: Icons.photo_library_rounded, color: accentPurple, label: 'Gallery', subtitle: 'Choose from your photos', onTap: () { Navigator.pop(ctx); _pickImageFromSource(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({required IconData icon, required Color color, required String label, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
            ]),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final camStatus = await Permission.camera.status;
        if (!camStatus.isGranted) {
          final result = await Permission.camera.request();
          if (!result.isGranted) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Camera permission needed."), action: SnackBarAction(label: 'Settings', onPressed: openAppSettings))); return; }
        }
      }
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) { setState(() => _selectedImageBase64 = base64Encode(bytes)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(source == ImageSource.camera ? "📸 Photo captured! Tap send." : "🖼️ Photo selected! Tap send."))); }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _startRecording() async {
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Microphone permission needed."), action: SnackBarAction(label: 'Settings', onPressed: openAppSettings))); return; }
    }
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/chat_record_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      _currentRecordingPath = path;
      _recordingSeconds = 0;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _recordingSeconds++); });
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopAndSendRecording() async {
    final path = await _audioRecorder.stop();
    _recordingTimer?.cancel();
    _pulseController.stop(); _pulseController.reset();
    _waveController.stop(); _waveController.reset();
    final seconds = _recordingSeconds;
    setState(() => _isRecording = false);
    if (path != null) {
      final bytes = await File(path).readAsBytes();
      _sendMessage(voiceBase64: base64Encode(bytes));
    }
  }

  Future<void> _cancelRecording() async {
    await _audioRecorder.stop();
    _recordingTimer?.cancel();
    _pulseController.stop(); _pulseController.reset();
    _waveController.stop(); _waveController.reset();
    _recordingSeconds = 0;
    if (_currentRecordingPath != null) { try { final f = File(_currentRecordingPath!); if (await f.exists()) await f.delete(); } catch (_) {} }
    setState(() => _isRecording = false);
  }

  String _formatDuration(int seconds) { final m = seconds ~/ 60; final s = seconds % 60; return '${m.toString().padLeft(1,'0')}:${s.toString().padLeft(2,'0')}'; }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: null,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFFFD6EC), Color(0xFFEDD6FF)]),
              ),
              child: ClipOval(
                child: Image.asset('assets/images/safeher_logo.jpg', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome_rounded, color: primaryPink, size: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SafeHer AI', style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.3)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: _hasConnectionError ? Colors.orange : const Color(0xFF4CAF50), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(_hasConnectionError ? 'Reconnecting...' : 'Always Active',
                      style: TextStyle(color: _hasConnectionError ? Colors.orange : textGrey, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_hasConnectionError)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: primaryPink),
              onPressed: () { setState(() { _hasConnectionError = false; }); },
              tooltip: 'Retry Connection',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFFFD6EC)),
        ),
      ),
      body: Column(
        children: [
          if (_selectedImageBase64 != null) _buildMediaPreview(),
          // Suggestion chips (show only initially)
          if (_messages.length == 1) _buildSuggestionChips(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return _buildTypingIndicator();
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          _isRecording ? _buildRecordingOverlay() : _buildInput(),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    return Container(
      height: 50,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _suggestions.length,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _sendMessage(predefinedText: _suggestions[i].replaceAll(RegExp(r'[^\x00-\x7F\s]+'), '').trim()),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD6EC), Color(0xFFEDD6FF)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryPink.withOpacity(0.2)),
            ),
            child: Text(_suggestions[i], style: const TextStyle(color: primaryPink, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingOverlay() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F8),
        boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_waveformBars.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 3, height: 8 + (_waveformBars[i] * 28),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: primaryPink.withOpacity(0.4 + _waveformBars[i] * 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: _cancelRecording,
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey[300]!)),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFF8E8E93), size: 22),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (_, __) => Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: primaryPink, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.4), blurRadius: _pulseAnimation.value * 6, spreadRadius: _pulseAnimation.value)],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(_formatDuration(_recordingSeconds),
                          style: const TextStyle(color: primaryPink, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1)),
                      ],
                    ),
                    const Text('Recording...', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _stopAndSendRecording,
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [primaryPink, accentPurple]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD6EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryPink.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_rounded, color: primaryPink, size: 20),
          const SizedBox(width: 10),
          const Expanded(child: Text('📸 Photo ready — add a message or send directly',
            style: TextStyle(color: primaryPink, fontWeight: FontWeight.w700, fontSize: 12))),
          GestureDetector(
            onTap: () => setState(() => _selectedImageBase64 = null),
            child: const Icon(Icons.close_rounded, color: textGrey, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)])
              : null,
          color: isUser ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: [BoxShadow(color: isUser ? primaryPink.withOpacity(0.2) : Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          border: isUser ? null : Border.all(color: const Color(0xFFFFD6EC), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg['hasImage'] == true && msg['image'] != null) ...[
              GestureDetector(
                onTap: () => _showFullImage(msg['image'] as String),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(base64Decode(msg['image'] as String), height: 180, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 100, color: Colors.black12, child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white70)))),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (msg['hasVoice'] == true) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.mic_none_rounded, color: Colors.white70, size: 14),
                  SizedBox(width: 4),
                  Text('Voice message', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ),
            ],
            SelectableText(
              msg['text'] as String,
              style: TextStyle(
                color: isUser ? Colors.white : textDark,
                fontSize: 14.5, height: 1.5, fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(String base64Image) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(16), child: InteractiveViewer(child: Image.memory(base64Decode(base64Image), fit: BoxFit.contain))),
            Positioned(top: 8, right: 8, child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white, size: 20)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD6EC)),
          boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 8)],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: primaryPink)),
            SizedBox(width: 10),
            Text('SafeHer AI is analyzing...', style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
        border: const Border(top: BorderSide(color: Color(0xFFFFD6EC), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showImageSourcePicker,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _selectedImageBase64 != null ? primaryPink.withOpacity(0.15) : const Color(0xFFFFF0F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryPink.withOpacity(0.2)),
              ),
              child: Icon(Icons.camera_alt_rounded, color: _selectedImageBase64 != null ? primaryPink : textGrey, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _startRecording,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryPink.withOpacity(0.2)),
              ),
              child: const Icon(Icons.mic_rounded, color: textGrey, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5FB),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primaryPink.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: textDark, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Ask about any place in Tamil Nadu...',
                  hintStyle: TextStyle(color: textGrey, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
                onSubmitted: (_) => _sendMessage(),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [primaryPink, accentPurple]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
