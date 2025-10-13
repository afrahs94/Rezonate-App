// lib/pages/ai_chatbot.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:new_rezonate/main.dart' as app;

/// AI Chatbot (conversational)
/// - Reflective listening first; one concise follow-up question each turn
/// - Uses OpenAI-compatible API when OPENAI_API_KEY (or your proxy) is configured
/// - Persists chat (Firestore if signed in, otherwise SharedPreferences)
/// - Safe, crisis-aware wording (not a medical device)
class AIChatbotPage extends StatefulWidget {
  const AIChatbotPage({super.key});
  @override
  State<AIChatbotPage> createState() => _AIChatbotPageState();
}

class _AIChatbotPageState extends State<AIChatbotPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;

  // ---------- Config ----------
  // If you’re calling your own secure proxy, set OPENAI_BASE_URL to that endpoint
  // (e.g., https://us-central1-<project>.cloudfunctions.net/chat) and leave API key empty.
  static const String _kApiKey =
      String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  static const String _kModel =
      String.fromEnvironment('OPENAI_MODEL', defaultValue: 'gpt-4o-mini');
  static const String _kBaseUrl =
      String.fromEnvironment('OPENAI_BASE_URL', defaultValue: 'https://api.openai.com/v1');

  // When using a Firebase Functions proxy, you can set this to true to send an ID token.
  static const bool _kUseFirebaseAuthOnRequests =
      bool.fromEnvironment('USE_FIREBASE_AUTH_BEARER', defaultValue: false);

  bool get _llmEnabled => _kBaseUrl.trim().isNotEmpty &&
      // If you point _kBaseUrl to your proxy, you may not need an API key here.
      (_kApiKey.trim().isNotEmpty || _kBaseUrl.contains('cloudfunctions.net') || _kBaseUrl.contains('vercel.app') || _kBaseUrl.contains('workers.dev'));

  // ---------- Theming ----------
  BoxDecoration _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
            : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
      ),
    );
  }

  double _topPad(BuildContext context) {
    final status = MediaQuery.of(context).padding.top;
    const appBar = kToolbarHeight;
    const extra = 24.0;
    return status + appBar + extra;
  }

  // ---------- Persistence ----------
  Future<void> _loadHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final qs = await FirebaseFirestore.instance
          .collection('ai_chat_v1')
          .doc(user.uid)
          .collection('messages')
          .orderBy('ts')
          .limit(500)
          .get();
      _messages
        ..clear()
        ..addAll(qs.docs.map((d) => _ChatMessage.fromMap(d.data())));
    } else {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ai_chat_local_v1');
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw) as List;
        _messages
          ..clear()
          ..addAll(list.map((m) => _ChatMessage.fromMap(Map<String, dynamic>.from(m))));
      }
    }
    if (mounted) setState(() {});
    _jumpToEnd();
  }

  Future<void> _persistMessage(_ChatMessage m) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('ai_chat_v1')
          .doc(user.uid)
          .collection('messages')
          .add(m.toMap());
    } else {
      final prefs = await SharedPreferences.getInstance();
      final list = [..._messages, m].map((e) => e.toMap()).toList();
      await prefs.setString('ai_chat_local_v1', jsonEncode(list));
    }
  }

  Future<void> _persistAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final col = FirebaseFirestore.instance
          .collection('ai_chat_v1')
          .doc(user.uid)
          .collection('messages');
      final batch = FirebaseFirestore.instance.batch();
      final old = await col.get();
      for (final d in old.docs) {
        batch.delete(d.reference);
      }
      for (final m in _messages) {
        batch.set(col.doc(), m.toMap());
      }
      await batch.commit();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'ai_chat_local_v1',
        jsonEncode(_messages.map((e) => e.toMap()).toList()),
      );
    }
  }

  // ---------- LLM client ----------
  List<Map<String, dynamic>> _buildLlmMessages() {
    const systemPrompt = '''
You are a warm, empathetic, *conversational* mental-health companion.
Primary goals:
1) Reflect back what you understood in plain, human language (1–2 sentences).
2) Ask ONE short, relevant follow-up question to learn more.
3) Only sometimes suggest a coping idea (breathing/grounding/CBT/ACT/DBT), and ONLY if it naturally fits.
4) Avoid diagnosis or medical claims. Encourage professional help when appropriate.
5) If the user seems in immediate danger or indicates self-harm intent, advise contacting emergency services/crisis lines right away.

Style:
- Short paragraphs, natural tone, no bullet lists unless the user asks.
- Never push exercises every turn. Listening comes first.
''';

    // Use the last ~20 turns for brevity
    final tail = _messages.length > 40 ? _messages.sublist(_messages.length - 40) : _messages;

    final msgs = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...tail.map((m) => {'role': m.role, 'content': m.text}),
    ];
    return msgs;
  }

  Future<String> _callLlm(List<Map<String, dynamic>> msgs) async {
    // If pointing at your secure proxy (Cloud Functions, Vercel, etc.), expose a chat-compatible route:
    // - Cloud Functions example in my previous message.
    // - If calling vendor directly, keep _kBaseUrl = https://api.openai.com/v1 and provide _kApiKey.
    final isProxy = !_kBaseUrl.contains('api.openai.com');

    final uri = isProxy
        ? Uri.parse(_kBaseUrl) // e.g., your https://...cloudfunctions.net/chat
        : Uri.parse('$_kBaseUrl/chat/completions');

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (!isProxy) {
      headers['Authorization'] = 'Bearer $_kApiKey';
    } else if (_kUseFirebaseAuthOnRequests) {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken != null) headers['Authorization'] = 'Bearer $idToken';
    }

    final body = isProxy
        ? jsonEncode({'messages': msgs, 'model': _kModel, 'temperature': 0.8})
        : jsonEncode({'model': _kModel, 'temperature': 0.8, 'messages': msgs});

    final resp = await http.post(uri, headers: headers, body: body);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (isProxy) {
        // Expecting { content: "...", usage: ... }
        final content = data['content']?.toString();
        if (content != null && content.trim().isNotEmpty) return content.trim();
      } else {
        final choices = data['choices'] as List?;
        final content = choices?.first?['message']?['content']?.toString();
        if (content != null && content.trim().isNotEmpty) return content.trim();
      }
      throw Exception('Empty model response');
    } else {
      String details = '';
      try {
        final m = jsonDecode(resp.body);
        details = m['error']?.toString() ?? resp.body;
      } catch (_) {
        details = resp.body;
      }
      throw Exception('LLM request failed (${resp.statusCode}): $details');
    }
  }

  // ---------- Conversational fallback (when no key/proxy) ----------
  String _reflectiveFallback(String input) {
    final t = input.trim();
    final lower = t.toLowerCase();

    String reflection;
    if (lower.contains('anx') || lower.contains('worry') || lower.contains('panic')) {
      reflection = "It sounds like anxiety’s been loud for you just now.";
    } else if (lower.contains('depress') || lower.contains('down') || lower.contains('sad')) {
      reflection = "I’m hearing a lot of heaviness and low mood in what you wrote.";
    } else if (lower.contains('sleep') || lower.contains('insomnia')) {
      reflection = "Sleep has been tough and that’s wearing you down.";
    } else if (lower.contains('anger') || lower.contains('mad') || lower.contains('irrit')) {
      reflection = "There’s a lot of frustration in this, and it makes sense you feel it.";
    } else if (lower.contains('grief') || lower.contains('loss')) {
      reflection = "I’m really sorry you’re going through this loss—those waves can be intense.";
    } else {
      reflection = "I’m hearing that this is a lot to carry.";
    }

    // ONE short follow-up, no exercise push by default
    String follow = "What part of this feels most important for me to understand right now?";

    return "$reflection $follow";
  }

  // ---------- UI helpers ----------
  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 160,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;

    final userMsg = _ChatMessage(
      role: 'user',
      text: text,
      ts: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.add(userMsg);
      _loading = true;
      _input.clear();
    });
    _jumpToEnd();
    await _persistMessage(userMsg);

    String reply;
    try {
      if (_llmEnabled) {
        final msgs = _buildLlmMessages();
        reply = await _callLlm(msgs);
      } else {
        reply = _reflectiveFallback(text);
      }
    } catch (e) {
      // If proxy or vendor fails, gracefully fall back to reflective style
      reply = "${_reflectiveFallback(text)}\n\n(We hit a connection issue, but I’m here with you.)";
    }

    final botMsg = _ChatMessage(
      role: 'assistant',
      text: reply,
      ts: DateTime.now().millisecondsSinceEpoch + 1,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(botMsg);
      _loading = false;
    });
    _jumpToEnd();
    await _persistMessage(botMsg);
  }

  Future<void> _clearConversation() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('This removes the current chat history on this device/account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _messages.clear());
    await _persistAll();
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);
    final liveChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _llmEnabled ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _llmEnabled ? const Color(0xFF2E7D32) : const Color(0xFFF9A825)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_llmEnabled ? Icons.bolt_rounded : Icons.wifi_off_rounded,
              size: 16, color: _llmEnabled ? const Color(0xFF2E7D32) : const Color(0xFFF9A825)),
          const SizedBox(width: 6),
          Text(_llmEnabled ? 'Live AI' : 'Offline mode',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _llmEnabled ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
              )),
        ],
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'AI Chatbot',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: .2),
        ),
        actions: [
          Center(child: Padding(padding: const EdgeInsets.only(right: 8), child: liveChip)),
          IconButton(
            tooltip: 'Clear conversation',
            onPressed: _messages.isEmpty ? null : _clearConversation,
            icon: const Icon(Icons.delete_outline_rounded),
          )
        ],
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(16, _topPad(context), 16, 24),
                  itemCount: _messages.length + 1 + (_loading ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.92),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black),
                          ),
                          child: const Text(
                            'I can offer supportive information, but I’m not a substitute for professional care. '
                            'If you might harm yourself or others, contact local emergency services or a crisis line now.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    }
                    if (_loading && i == _messages.length + 1) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.88),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(16),
                            ),
                            border: Border.all(color: Colors.black12),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Thinking…'),
                            ],
                          ),
                        ),
                      );
                    }

                    final m = _messages[i - 1];
                    final mine = m.role == 'user';
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: mine ? green : Colors.white.withOpacity(.88),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(mine ? 16 : 4),
                              bottomRight: Radius.circular(mine ? 4 : 16),
                            ),
                            border: Border.all(color: Colors.black12),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                          ),
                          child: SelectableText(
                            m.text,
                            style: TextStyle(
                              color: mine ? Colors.white : Colors.black87,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Composer
              Container(
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.9),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.black26),
                        ),
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: 'Tell me what’s going on…',
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _loading ? null : _send,
                      icon: _loading
                          ? const SizedBox(
                              height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded),
                      label: const Text('Send'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7C66),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  final int ts; // epoch ms

  const _ChatMessage({required this.role, required this.text, required this.ts});

  Map<String, dynamic> toMap() => {'role': role, 'text': text, 'ts': ts};

  factory _ChatMessage.fromMap(Map<String, dynamic> m) =>
      _ChatMessage(role: m['role'] as String, text: m['text'] as String, ts: (m['ts'] as num).toInt());
}
