// lib/pages/ai_chatbot.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; // Still needed for persistence logic
import 'package:new_rezonate/main.dart' as app;
import 'package:google_generative_ai/google_generative_ai.dart';

/// AI Chatbot (conversational)
/// - Reflective listening first; one concise follow-up question each turn
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
  
  // Initialize these late, they will be set in initState if _llmEnabled is true
  late final GenerativeModel _gemini;
  late final ChatSession _chat;
  
  bool _loading = false;

  // ---------- Config ----------
  // Use the Gemini API. The API key can be set via --dart-define=GEMINI_API_KEY="your-key"
  static const String _kApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  // Use a Gemini model that supports multi-turn chat
  static const String _kModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );
  // Removed _kBaseUrl as the package handles it.

  // When using a Firebase Functions proxy, you can set this to true to send an ID token.
  static const bool _kUseFirebaseAuthOnRequests = bool.fromEnvironment(
    'USE_FIREBASE_AUTH_BEARER',
    defaultValue: false,
  );

  bool get _llmEnabled => _kApiKey.trim().isNotEmpty;

  // ---------- Theming ----------
  BoxDecoration _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors:
            dark
                ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
                : const [
                  Color(0xFFFFFFFF),
                  Color(0xFFD7C3F1),
                  Color(0xFF41B3A2),
                ],
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
      final qs =
          await FirebaseFirestore.instance
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
          ..addAll(
            list.map((m) => _ChatMessage.fromMap(Map<String, dynamic>.from(m))),
          );
      }
    }
    
    if (mounted) setState(() {});
    _jumpToEnd();
    
    // NEW: If LLM is enabled, restart the chat session with the loaded history
    if (_llmEnabled && _messages.isNotEmpty) {
      final history = _messages.map((m) => m.toContent()).toList();
      _chat = _gemini.startChat(history: history); 
    }
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
  // System instruction for the Gemini API
  final String _kSystemInstruction = '''
You are a warm, empathetic, *conversational* mental-health companion. Primary goals: 1) Reflect back what you understood in plain, human language (1–2 sentences). 2) Ask ONE short, relevant follow-up question to learn more. 3) Only sometimes suggest a coping idea (breathing/grounding/CBT/ACT/DBT), and ONLY if it naturally fits. 4) Avoid diagnosis or medical claims. Encourage professional help when appropriate. 5) If the user seems in immediate danger or indicates self-harm intent, advise contacting emergency services/crisis lines right away. Style: - Short paragraphs, natural tone, no bullet lists unless the user asks. - Never push exercises every turn. Listening comes first.
''';

  // REMOVED: _buildLlmMessages() as ChatSession handles this.
  // REMOVED: _callLlm() as GenerativeModel handles this.
  
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
    if (text.isEmpty || _loading || !_llmEnabled)
      return; // Only allow sending if AI is enabled

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
      // Using the ChatSession's sendMessage method
      final response = await _chat.sendMessage(Content.text(text)); 
      
      reply = response.text ?? 'Sorry, I received an empty response from the AI.';

    } on FirebaseException catch (e) {
      // Handle Firebase proxy auth errors if _kUseFirebaseAuthOnRequests is true
      reply = "Authentication error: $e";
    } on Exception catch (e) {
      // Handle API connection errors, including failed key or network issues
      if (e is SocketException) {
        reply = "Connection failed. Please check your network.";
      } else {
        reply =
            "I hit a connection issue and couldn't process your request right now. Could you please try again in a moment? ($e)";
      }
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
      builder:
          (c) => AlertDialog(
            title: const Text('Clear conversation?'),
            content: const Text(
              'This removes the current chat history on this device/account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
    if (ok != true) return;

    setState(() => _messages.clear());
    await _persistAll();
      _chat = _gemini.startChat(history: []);
  }

  @override
void initState() {
  super.initState();
  _loadHistory();

  if (_llmEnabled) {
    // 1. Initialize GenerativeModel
    _gemini = GenerativeModel(
      model: _kModel,
      apiKey: _kApiKey,
      generationConfig: GenerationConfig(
        //temperature: 0.8,
        //systemInstruction: _kSystemInstruction,
      ),
    );
    
    // 2. Initialize ChatSession
    // Map existing history to Content objects for the session
    final history = _messages.map((m) => m.toContent()).toList();
    _chat = _gemini.startChat(history: history);
  }
}

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (rest of your build method remains the same) ...
    const green = Color(0xFF0D7C66);
    final liveChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _llmEnabled ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              _llmEnabled ? const Color(0xFF2E7D32) : const Color(0xFFF9A825),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _llmEnabled
                ? Icons.bolt_rounded
                : Icons.lock_outline_rounded, // Changed icon for 'key missing'
            size: 16,
            color:
                _llmEnabled ? const Color(0xFF2E7D32) : const Color(0xFFF9A825),
          ),
          const SizedBox(width: 6),
          Text(
            _llmEnabled ? 'Live AI' : 'API Key Missing', // Updated text
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color:
                  _llmEnabled
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFF57F17),
            ),
          ),
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
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: liveChip,
            ),
          ),
          IconButton(
            tooltip: 'Clear conversation',
            onPressed: _messages.isEmpty ? null : _clearConversation,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.88),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(16),
                            ),
                            border: Border.all(color: Colors.black12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 6),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              //Text('Thinking…'),
                            ],
                          ),
                          ),
                      );
                    }

                    final m = _messages[i - 1];
                    final mine = m.role == 'user';
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * .78,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
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
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 6),
                            ],
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
                          color: Colors.white,
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
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _loading ? null : _send,
                      icon:
                          _loading
                              ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.send_rounded),
                      label: const Text('Send'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7C66),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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

  const _ChatMessage({
    required this.role,
    required this.text,
    required this.ts,
  });

  Map<String, dynamic> toMap() => {'role': role, 'text': text, 'ts': ts};

  factory _ChatMessage.fromMap(Map<String, dynamic> m) => _ChatMessage(
    role: m['role'] as String,
    text: m['text'] as String,
    ts: (m['ts'] as num).toInt(),
  );
  
  // NEW: Helper to convert to package Content
  Content toContent() {
    return Content(
      // 'model' is the required role for the AI in the API
      role == 'assistant' ? 'model' : 'user', 
      [
        //Part.text(text),
      ],
    );
  }
}