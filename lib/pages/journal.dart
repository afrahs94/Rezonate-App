// lib/pages/journal.dart
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_rezonate/main.dart' as app;
import 'package:new_rezonate/pages/home.dart' as home_page;
import 'package:new_rezonate/pages/settings.dart';
import 'package:new_rezonate/pages/services/user_settings.dart' as app_settings;

const _teal = Color(0xFF0D7C66);
// same purple as the top of the header gradient
const _headerPurple = Color(0xFFBDA9DB);

// Helpers for dark mode look (same layout, just darker)
bool _isDark(BuildContext context) =>
    app.ThemeControllerScope.of(context).isDark;
Color _cardBg(BuildContext context) =>
    _isDark(context) ? const Color(0xFF1E1F24) : Colors.white;
Color _replyBg(BuildContext context) =>
    _isDark(context) ? Colors.white.withOpacity(.06) : Colors.grey.shade50;
Color _textPrimary(BuildContext context) =>
    _isDark(context) ? Colors.white : Colors.black87;
Color _textSecondary(BuildContext context) =>
    _isDark(context) ? Colors.white70 : Colors.grey.shade600;

// Single translucent background used for ALL write areas
Color _entryBg(BuildContext context) => _teal.withOpacity(.16);

//for private journal lock
Future<bool> _promptForPin(BuildContext context) async {
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  final uid = auth.currentUser?.uid;
  if (uid == null) return false;

  final snap = await db.collection('users').doc(uid).get();
  final storedHash = snap.data()?['journal_lock_pin'] as String?;
  final enabled = snap.data()?['journal_lock_enabled'] as bool? ?? false;

  // If no lock is enabled, just allow access
  if (!enabled || storedHash == null) return true;

  final pinCtrl = TextEditingController();
  String? err;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Enter PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'PIN'),
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(err!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final entered = pinCtrl.text.trim();
                  final enteredHash =
                      sha256.convert(utf8.encode(entered)).toString();
                  if (enteredHash == storedHash) {
                    Navigator.pop(ctx, true);
                  } else {
                    setLocal(() => err = 'Incorrect PIN');
                  }
                },
                child: const Text('Unlock'),
              ),
            ],
          );
        },
      );
    },
  );
  return ok == true;
}

/// Resolve usernames for display.
class _UsernameResolver {
  static final Map<String, String> _cache = {};

  static Future<String?> resolveByUid(String uid) async {
    if (uid.isEmpty) return null;
    if (_cache.containsKey(uid)) return _cache[uid];
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final name = (snap.data()?['username'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        _cache[uid] = name;
        return name;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> resolveByEmail(String email) async {
    if (email.isEmpty) return null;
    try {
      final q =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
      if (q.docs.isNotEmpty) {
        final uid = q.docs.first.id;
        final name = (q.docs.first.data()['username'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          _cache[uid] = name;
          return name;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String> forCurrent(User u, String fallback) async {
    final byUid = await resolveByUid(u.uid);
    if (byUid != null && byUid.isNotEmpty) return byUid;
    final byEmail = await resolveByEmail(u.email ?? '');
    if (byEmail != null && byEmail.isNotEmpty) return byEmail;
    return fallback.isNotEmpty ? fallback : 'user';
  }
}

/// Resolve the latest profile photo from users/{uid}.photoUrl (cached).
class _PhotoResolver {
  static final Map<String, String?> _cache = {};

  static Future<String?> byUid(String uid) async {
    if (uid.isEmpty) return null;
    if (_cache.containsKey(uid)) return _cache[uid];
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final url = (snap.data()?['photoUrl'] as String?)?.trim();
      _cache[uid] = (url != null && url.isNotEmpty) ? url : null;
      return _cache[uid];
    } catch (_) {
      return null;
    }
  }
}

enum _TimeFilter { all, d1, d7, d30 }

enum _OrderBy { dateDesc, dateAsc, mostReacted, mostReplies }

class JournalPage extends StatefulWidget {
  final String userName;
  const JournalPage({Key? key, required this.userName}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class NoTransitionPageRoute<T> extends MaterialPageRoute<T> {
  NoTransitionPageRoute({required WidgetBuilder builder})
    : super(builder: builder);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child; // no animation
  }
}

class _JournalPageState extends State<JournalPage>
    with SingleTickerProviderStateMixin {
  int _seg = 0;

  final _pubCtl = TextEditingController();
  final Map<String, TextEditingController> _replyCtls = {};
  String? _openReplyFor;
  final FocusNode _pubFocus = FocusNode();
  bool _showTriggerAdvice = false;

  User? get _user => FirebaseAuth.instance.currentUser;
  CollectionReference<Map<String, dynamic>> get _public =>
      FirebaseFirestore.instance.collection('public_posts');
  CollectionReference<Map<String, dynamic>> _privateCol(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private_posts');

  Set<String> _blocked = {};

  // filters (UI for time filters removed; sort remains)
  _TimeFilter _timeFilter = _TimeFilter.all;
  _OrderBy _orderBy = _OrderBy.dateDesc;

  // 🔐 Live anonymity flag from user doc (null = unknown yet)
  bool? _anonGlobal;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  @override
  void initState() {
    super.initState();
    _loadBlocked();

    // 🔐 Listen to current user's anonymity setting in Firestore (if signed in)
    final u = _user;
    if (u != null) {
      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .snapshots()
          .listen((snap) {
            final data = snap.data();

            // Priority: explicit fields → mode string → fallback to in-memory UserSettings
            bool anon = app_settings.UserSettings.anonymous == true;
            if (data != null) {
              if (data['share_anonymously'] == true) anon = true;
              if (data['anonymous'] == true) anon = true;
              if (data['share_publicly'] == true) anon = false; // forced public
              final mode = (data['shareMode'] as String?)?.toLowerCase().trim();
              if (mode == 'anonymous') anon = true;
              if (mode == 'public') anon = false;
            }
            if (mounted) setState(() => _anonGlobal = anon);
          });
    }
  }

  @override
  void dispose() {
    _pubCtl.dispose();
    _pubFocus.dispose();
    for (final c in _replyCtls.values) {
      c.dispose();
    }
    _userSub?.cancel(); // ✅ stop listening to avoid setState after dispose
    super.dispose();
  }

  Future<void> _loadBlocked() async {
    final u = _user;
    if (u == null) return;
    final me =
        await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final list = (me.data()?['blocked_uids'] as List?)?.cast<String>() ?? [];
    if (!mounted) return;
    setState(() => _blocked = list.toSet());
  }

  String _fmtFull(DateTime d) => DateFormat('MMM d, yyyy • hh:mm a').format(d);

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  bool get _anonNow =>
      _anonGlobal ?? (app_settings.UserSettings.anonymous == true); // fallback

  // ---------- Mentions helpers ----------
  final RegExp _mentionExp = RegExp(r'@([A-Za-z0-9_.-]{2,30})');

  Future<List<Map<String, String>>> _resolveMentions(String text) async {
    // unique usernames
    final names = <String>{
      for (final m in _mentionExp.allMatches(text)) m.group(1)!.trim(),
    };
    if (names.isEmpty) return [];

    final col = FirebaseFirestore.instance.collection('users');
    final results = <Map<String, String>>[];
    for (final name in names) {
      final q = await col.where('username', isEqualTo: name).limit(1).get();
      if (q.docs.isNotEmpty) {
        results.add({'username': name, 'uid': q.docs.first.id});
      }
    }
    return results;
  }

  // ---------------- Community actions ----------------
  Future<void> _postPublic() async {
    final text = _pubCtl.text.trim();
    final u = _user;
    if (text.isEmpty || u == null) return;

    final anon = _anonNow;
    final safeUsername =
        anon
            ? 'anonymous user'
            : await _UsernameResolver.forCurrent(u, widget.userName);
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final photoUrl =
        anon ? null : (userDoc.data()?['photoUrl'] as String?) ?? u.photoURL;

    final mentions = await _resolveMentions(text);

    final now = FieldValue.serverTimestamp();
    await _public.add({
      'uid': u.uid,
      'username': safeUsername,
      'isAnonymous': anon,
      'photoUrl': photoUrl,
      'content': text,
      'createdAt': now,
      'updatedAt': now,
      'reactions': {'❤️': 0, '👍': 0, '🥲': 0},
      'reactionScore': 0,
      'replyCount': 0,
      if (mentions.isNotEmpty) 'mentions': mentions,
      'edited': false,
    });

    _pubCtl.clear();
    if (!mounted) return;
    setState(() => _showTriggerAdvice = false);
    FocusScope.of(context).unfocus();
  }

  Future<void> _reactOnce(String postId, String emoji) async {
    final u = _user;
    if (u == null) return;
    final postRef = _public.doc(postId);
    final myReactRef = postRef.collection('reactions').doc(u.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final mySnap = await tx.get(myReactRef);
      final postSnap = await tx.get(postRef);
      if (!postSnap.exists) return;

      if (!mySnap.exists) {
        tx.set(myReactRef, {
          'emoji': emoji,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {
          'reactions.$emoji': FieldValue.increment(1),
          'reactionScore': FieldValue.increment(1),
        });
        return;
      }

      final prev = (mySnap.data() as Map<String, dynamic>)['emoji'] as String?;
      if (prev == emoji) {
        tx.update(postRef, {
          'reactions.$emoji': FieldValue.increment(-1),
          'reactionScore': FieldValue.increment(-1),
        });
        tx.delete(myReactRef);
        return;
      }

      if (prev != null && prev.isNotEmpty) {
        tx.update(postRef, {'reactions.$prev': FieldValue.increment(-1)});
      }
      tx.update(postRef, {'reactions.$emoji': FieldValue.increment(1)});
      tx.update(myReactRef, {
        'emoji': emoji,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _reactOnceReply(
    String replyId,
    String emoji,
    String postId,
  ) async {
    final u = _user;
    if (u == null) return;

    final replyRef = _public.doc(postId).collection('replies').doc(replyId);
    final myReactRef = replyRef.collection('reactions').doc(u.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final mySnap = await tx.get(myReactRef);
      final replySnap = await tx.get(replyRef);
      if (!replySnap.exists) return;

      if (!mySnap.exists) {
        tx.set(myReactRef, {
          'emoji': emoji,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(replyRef, {'reactions.$emoji': FieldValue.increment(1)});
        return;
      }

      final prev = (mySnap.data()?['emoji'] as String?) ?? '';
      if (prev == emoji) {
        tx.update(replyRef, {'reactions.$emoji': FieldValue.increment(-1)});
        tx.delete(myReactRef);
        return;
      }

      if (prev.isNotEmpty) {
        tx.update(replyRef, {'reactions.$prev': FieldValue.increment(-1)});
      }

      tx.update(replyRef, {'reactions.$emoji': FieldValue.increment(1)});
      tx.update(myReactRef, {
        'emoji': emoji,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _reply(String postId, String text, {String? parentId}) async {
    final t = text.trim();
    final u = _user;
    if (t.isEmpty || u == null) return;

    final anon = _anonNow;
    final safeUsername =
        anon
            ? 'anonymous user'
            : await _UsernameResolver.forCurrent(u, widget.userName);
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final photoUrl =
        anon ? null : (userDoc.data()?['photoUrl'] as String?) ?? u.photoURL;
    final mentions = await _resolveMentions(t);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final postRef = _public.doc(postId);
      final repliesRef = postRef.collection('replies').doc();
      tx.set(repliesRef, {
        'uid': u.uid,
        'username': safeUsername,
        'isAnonymous': anon,
        'photoUrl': photoUrl,
        'content': t,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (mentions.isNotEmpty) 'mentions': mentions,
        if (parentId != null) 'parentId': parentId,
        'edited': false,
      });
      tx.update(postRef, {'replyCount': FieldValue.increment(1)});
    });
  }

  Future<void> _blockUser(String otherUid) async {
    final u = _user;
    if (u == null) return;
    if (otherUid.isEmpty || otherUid == u.uid) return;
    final uname = (await _UsernameResolver.resolveByUid(otherUid)) ?? '';
    await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
      'blocked_uids': FieldValue.arrayUnion([otherUid]),
      if (uname.isNotEmpty) 'blocked_usernames': FieldValue.arrayUnion([uname]),
    }, SetOptions(merge: true));
    await _loadBlocked();
  }

  Future<void> _deletePost(String postId) async {
    await _public.doc(postId).delete();
  }

  Future<void> _editPost(String postId, String currentText) async {
    final ctl = TextEditingController(text: currentText);
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Edit post'),
            content: TextField(
              controller: ctl,
              maxLines: 8,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newText = ctl.text.trim();
                  if (newText.isNotEmpty) {
                    final mentions = await _resolveMentions(newText);
                    await _public.doc(postId).update({
                      'content': newText,
                      'updatedAt': FieldValue.serverTimestamp(),
                      'edited': true,
                      if (mentions.isNotEmpty)
                        'mentions': mentions
                      else
                        'mentions': FieldValue.delete(),
                    });
                  }
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  // ---------------- Private journal creation (plus button) ----------------
  Future<void> _openCreatePrivateDialog() async {
    final tCtl = TextEditingController();
    final cCtl = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('New entry'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tCtl,
                    decoration: const InputDecoration(
                      labelText: 'Entry Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cCtl,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Write a private entry…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _createPrivateEntry(tCtl.text.trim(), cCtl.text.trim());
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _createPrivateEntry(String title, String body) async {
    final u = _user;
    if (u == null) return;
    if (title.isEmpty || body.isEmpty) return;
    await _privateCol(u.uid).add({
      'title': title,
      'content': body,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'edited': false,
      'iconKey': 'book',
    });
  }

  // ---------------- Filters helpers ----------------
  DateTime? _filterFromDate(_TimeFilter f) {
    final now = DateTime.now();
    switch (f) {
      case _TimeFilter.all:
        return null;
      case _TimeFilter.d1:
        return now.subtract(const Duration(days: 1));
      case _TimeFilter.d7:
        return now.subtract(const Duration(days: 7));
      case _TimeFilter.d30:
        return now.subtract(const Duration(days: 30));
    }
  }

  // Open a friendly chooser for sort options
  Future<void> _openSortSheet() async {
    // Make labels high-contrast on the white bottom sheet so they’re clearly visible in dark mode too.
    const labelStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: Colors.black87,
    );

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        Widget tile(String title, IconData icon, _OrderBy value) => ListTile(
          leading: Icon(icon, color: _teal),
          title: Text(title, style: labelStyle),
          trailing:
              _orderBy == value ? const Icon(Icons.check, color: _teal) : null,
          onTap: () {
            setState(() => _orderBy = value);
            Navigator.pop(context);
          },
        );

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              tile('Newest', Icons.new_releases, _OrderBy.dateDesc),
              tile('Oldest', Icons.history, _OrderBy.dateAsc),
              tile(
                'Most reacted',
                Icons.emoji_emotions_outlined,
                _OrderBy.mostReacted,
              ),
              tile('Most replies', Icons.forum_outlined, _OrderBy.mostReplies),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  LinearGradient _bg(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors:
          dark
              ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
              : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      extendBodyBehindAppBar: true,
      // AppBar removed
      body: Stack(
        children: [
          // FIXED, NON-SCROLLING BACKGROUND LAYER
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: _bg(context)),
              ),
            ),
          ),

          // Foreground content
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SegPill(
                          label: 'Community Feed',
                          active: _seg == 0,
                          onTap: () => setState(() => _seg = 0),
                        ),
                        const SizedBox(width: 16),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 70),
                        ),
                        _SegPill(
                          label: 'My Journal',
                          active: _seg == 1,
                          onTap: () => setState(() => _seg = 1),
                          alt: true,
                        ),
                      ],
                    ),

                    // Only sort button (time filters removed)
                    if (_seg == 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 3, 16, 1),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Sort',
                            onPressed: _openSortSheet,
                            icon: const Icon(Icons.sort_rounded),
                            color: _textPrimary(context),
                          ),
                        ),
                      ),

                    Expanded(
                      child:
                          _seg == 0
                              ? _CommunityFeed(
                                user: u,
                                blocked: _blocked,
                                publicCol: _public,
                                onReact: _reactOnce,
                                onReply: _reply, // supports parentId
                                onDelete: _deletePost,
                                onEdit: _editPost,
                                onBlock: _blockUser,
                                openReplyFor: _openReplyFor,
                                setOpenReplyFor: (id) {
                                  setState(
                                    () =>
                                        _openReplyFor =
                                            id == _openReplyFor ? null : id,
                                  );
                                },
                                replyCtlFor:
                                    (id) => _replyCtls.putIfAbsent(
                                      id,
                                      () => TextEditingController(),
                                    ),
                                fmtFull: _fmtFull,
                                relative: _relative,
                                filterFrom: _filterFromDate(_timeFilter),
                                orderBy: _orderBy,
                                selfAnon: _anonNow,
                              )
                              : FutureBuilder<bool>(
                                future: _promptForPin(context),
                                builder: (ctx, snap) {
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (snap.data == true) {
                                    return _PrivateJournal(
                                      uid: u?.uid,
                                      col:
                                          u == null ? null : _privateCol(u.uid),
                                      fmtFull: _fmtFull,
                                    );
                                  } else {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'My Journal is locked.',
                                            style: TextStyle(
                                              color: _textPrimary(context),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: () async {
                                              final ok = await _promptForPin(
                                                context,
                                              );
                                              if (ok) {
                                                if (mounted) setState(() {});
                                              }
                                            },
                                            child: const Text('Unlock'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                    ),

                    const SizedBox(height: 16),

                    // Warning appears RIGHT ABOVE only when typing
                    if (_seg == 0 && _showTriggerAdvice)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'If discussing sensitive topics, please add a trigger warning to your post.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Composer (community only)
                    if (_seg == 0)
                      _ComposerWithMentions(
                        controller: _pubCtl,
                        focusNode: _pubFocus,
                        hintText: 'start writing',
                        onSubmit: _postPublic,
                        showTriggerAdvice: (s) {
                          setState(() => _showTriggerAdvice = s);
                        },
                        leadingAvatarUrl: u?.photoURL,
                      )
                    else
                      const SizedBox(height: 8),

                    _BottomNavTransparent(
                      selectedIndex: 1,
                      onHome:
                          () => Navigator.pushReplacement(
                            context,
                            NoTransitionPageRoute(
                              builder:
                                  (_) => home_page.HomePage(
                                    userName: widget.userName,
                                  ),
                            ),
                          ),
                      onJournal: () {},
                      onSettings:
                          () => Navigator.pushReplacement(
                            context,
                            NoTransitionPageRoute(
                              builder:
                                  (_) =>
                                      SettingsPage(userName: widget.userName),
                            ),
                          ),
                    ),
                  ],
                ),

                // FAB for adding private entry (floats above bottom nav)
                if (_seg == 1)
                  Positioned(
                    right: 16,
                    bottom: 86,
                    child: FloatingActionButton(
                      backgroundColor: _teal,
                      onPressed: _openCreatePrivateDialog,
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Community Feed ----------------
class _CommunityFeed extends StatelessWidget {
  const _CommunityFeed({
    required this.user,
    required this.blocked,
    required this.publicCol,
    required this.onReact,
    required this.onReply,
    required this.onDelete,
    required this.onEdit,
    required this.onBlock,
    required this.openReplyFor,
    required this.setOpenReplyFor,
    required this.replyCtlFor,
    required this.fmtFull,
    required this.relative,
    required this.filterFrom,
    required this.orderBy,
    required this.selfAnon,
  });

  final User? user;
  final Set<String> blocked;
  final CollectionReference<Map<String, dynamic>> publicCol;
  final Future<void> Function(String postId, String text, {String? parentId})
  onReply;
  final Future<void> Function(String postId, String emoji) onReact;
  final Future<void> Function(String postId) onDelete;
  final Future<void> Function(String postId, String currentText) onEdit;
  final Future<void> Function(String otherUid) onBlock;
  final String? openReplyFor;
  final void Function(String? id) setOpenReplyFor;
  final TextEditingController Function(String postId) replyCtlFor;
  final String Function(DateTime) fmtFull;
  final String Function(DateTime) relative;
  final DateTime? filterFrom;
  final _OrderBy orderBy;
  final bool selfAnon;

  Query<Map<String, dynamic>> _buildQuery() {
    // Avoid composite indexes entirely
    Query<Map<String, dynamic>> q = publicCol;

    if (filterFrom != null) {
      q = q.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(filterFrom!),
      );
      q = q.orderBy('createdAt', descending: true);
      return q.limit(500);
    }

    switch (orderBy) {
      case _OrderBy.dateDesc:
        q = q.orderBy('createdAt', descending: true);
        break;
      case _OrderBy.dateAsc:
        q = q.orderBy('createdAt', descending: false);
        break;
      case _OrderBy.mostReacted:
        break;
      case _OrderBy.mostReplies:
        break;
    }
    return q.limit(500);
  }

  @override
  Widget build(BuildContext context) {
    final stream = _buildQuery().snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            (snap.data?.docs ?? [])
                .where((d) => !blocked.contains(d.data()['uid']))
                .toList();

        // Client-side sort for aggregate sorts (no index needed).
        if (orderBy == _OrderBy.mostReacted) {
          docs.sort((a, b) {
            final ar = (a.data()['reactionScore'] ?? 0) as int;
            final br = (b.data()['reactionScore'] ?? 0) as int;
            if (br != ar) return br.compareTo(ar);
            final at =
                (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
            final bt =
                (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
            return bt.compareTo(at);
          });
        } else if (orderBy == _OrderBy.mostReplies) {
          docs.sort((a, b) {
            final ar = (a.data()['replyCount'] ?? 0) as int;
            final br = (b.data()['replyCount'] ?? 0) as int;
            if (br != ar) return br.compareTo(ar);
            final at =
                (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
            final bt =
                (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
            return bt.compareTo(at);
          });
        }

        if (docs.isEmpty) {
          return const _EmptyHint(
            icon: Icons.public,
            title: 'No posts yet',
            subtitle: 'Be the first to share something with the community.',
          );
        }

        return ListView.builder(
          // ⬇️ extra bottom padding adds space above the composer
          key: const PageStorageKey<String>('community_feed_list'),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 220),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final m = doc.data();
            final ts =
                (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final postUid = (m['uid'] as String?) ?? '';
            final providedName = (m['username'] as String?)?.trim() ?? '';
            final storedAnon = (m['isAnonymous'] as bool?) == true;

            final isSelf = user?.uid == postUid;
            final displayAnon = isSelf ? selfAnon : storedAnon;

            final canEdit = user?.uid == postUid;
            final canBlock = postUid.isNotEmpty && user?.uid != postUid;

            return _Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _AvatarSmart(
                          uid: postUid,
                          photoUrlFromPost: m['photoUrl'] as String?,
                          postAnonymous: displayAnon,
                          preferFresh: isSelf,
                          selfFallbackUrl: isSelf ? user?.photoURL : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _UsernameTag(
                                  uid: postUid,
                                  provided: providedName,
                                  isAnonymous: displayAnon,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: _textPrimary(context),
                                  ),
                                ),
                              ),
                              if ((m['edited'] as bool?) == true)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    'Edited',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: _textSecondary(context),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          fmtFull(ts),
                          style: TextStyle(
                            color: _textSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _PostMenu(
                          canEdit: canEdit,
                          canDelete: canEdit,
                          canBlock: canBlock,
                          onEdit:
                              () => onEdit(
                                doc.id,
                                (m['content'] as String?) ?? '',
                              ),
                          onDelete: () => onDelete(doc.id),
                          onBlock: () => onBlock(postUid),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    _ExpandableText(text: (m['content'] as String?) ?? ''),

                    const SizedBox(height: 12),

                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream:
                          (user == null)
                              ? null
                              : publicCol
                                  .doc(doc.id)
                                  .collection('reactions')
                                  .doc(user!.uid)
                                  .snapshots(),
                      builder: (context, rxSnap) {
                        final myEmoji =
                            (rxSnap.data?.data()?['emoji'] as String?) ?? '';
                        return Row(
                          children: [
                            _EmojiSelectable(
                              emoji: '❤️',
                              count: (m['reactions']?['❤️'] ?? 0) as int,
                              selected: myEmoji == '❤️',
                              onTap:
                                  user == null
                                      ? null
                                      : () => onReact(doc.id, '❤️'),
                            ),
                            const SizedBox(width: 8),
                            _EmojiSelectable(
                              emoji: '👍',
                              count: (m['reactions']?['👍'] ?? 0) as int,
                              selected: myEmoji == '👍',
                              onTap:
                                  user == null
                                      ? null
                                      : () => onReact(doc.id, '👍'),
                            ),
                            const SizedBox(width: 8),
                            _EmojiSelectable(
                              emoji: '🥲',
                              count: (m['reactions']?['🥲'] ?? 0) as int,
                              selected: myEmoji == '🥲',
                              onTap:
                                  user == null
                                      ? null
                                      : () => onReact(doc.id, '🥲'),
                            ),
                            const Spacer(),
                            _RepliesToggle(
                              col: publicCol,
                              postId: doc.id,
                              open: openReplyFor == doc.id,
                              onPressed:
                                  () => setOpenReplyFor(
                                    openReplyFor == doc.id ? null : doc.id,
                                  ),
                            ),
                          ],
                        );
                      },
                    ),

                    if (openReplyFor == doc.id) ...[
                      _ReplyThread(
                        postId: doc.id,
                        public: publicCol,
                        currentUid: user?.uid,
                        selfAnon: selfAnon,
                        onReply: onReply, // supports nested
                        onBlock: onBlock,
                        blocked: blocked,
                      ),
                      _InlineReplyComposer(
                        currentUserName: user?.displayName ?? 'You',
                        currentUserPhoto: user?.photoURL,
                        ctl: replyCtlFor(doc.id),
                        onSend: (txt) async {
                          await onReply(doc.id, txt);
                          replyCtlFor(doc.id).clear();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------- Private Journal ----------------
class _PrivateJournal extends StatelessWidget {
  const _PrivateJournal({
    required this.uid,
    required this.col,
    required this.fmtFull,
  });

  final String? uid;
  final CollectionReference<Map<String, dynamic>>? col;
  final String Function(DateTime) fmtFull;

  // --- Icon options for private entries
  static const Map<String, IconData> _iconChoices = {
    'book': Icons.menu_book_rounded,
    'star': Icons.star_rounded,
    'heart': Icons.favorite_rounded,
    'bolt': Icons.bolt_rounded,
    'check': Icons.check_circle_rounded,
    'note': Icons.note_rounded,
    'flower': Icons.local_florist_rounded,
  };

  IconData _iconForKey(String? key) {
    return _iconChoices[key] ?? Icons.menu_book_rounded;
  }

  Future<void> _chooseIcon(
    BuildContext context,
    CollectionReference<Map<String, dynamic>> col,
    String id,
    String currentKey,
  ) async {
    String selected = currentKey;
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Choose an icon'),
            content: SizedBox(
              width: 420,
              child: Wrap(
                alignment:
                    WrapAlignment.spaceEvenly, // or .center, .spaceAround
                spacing: 12,
                runSpacing: 12,
                children:
                    _iconChoices.entries.map((e) {
                      final isSel = e.key == selected;
                      return InkWell(
                        onTap: () {
                          selected = e.key;
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color:
                                isSel ? _teal.withOpacity(.12) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? _teal : Colors.black12,
                            ),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 6),
                            ],
                          ),
                          child: Icon(e.value, color: _teal, size: 30),
                        ),
                      );
                    }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
    if (selected != currentKey) {
      await col.doc(id).update({'iconKey': selected});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null || col == null) {
      return Center(
        child: Text(
          'Sign in to view your private entries.',
          style: TextStyle(color: _textPrimary(context)),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          col!.orderBy('createdAt', descending: true).limit(200).snapshots(),
      builder: (context, snap) {
        final list = snap.data?.docs ?? [];
        if (list.isEmpty) {
          return Center(
            child: Text(
              'No entries yet. Tap + to add one.',
              style: TextStyle(color: _textPrimary(context)),
            ),
          );
        }

        Future<void> _viewEntry(
          QueryDocumentSnapshot<Map<String, dynamic>> d,
        ) async {
          final m = d.data();
          await showDialog(
            context: context,
            builder:
                (_) => AlertDialog(
                  title: Text((m['title'] as String?) ?? 'Untitled'),
                  content: SizedBox(
                    width: 520,
                    child: SingleChildScrollView(
                      child: Text((m['content'] as String?) ?? ''),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _editEntry(
                          context,
                          col!,
                          d.id,
                          m['title'] ?? '',
                          m['content'] ?? '',
                        );
                      },
                      child: const Text('Edit'),
                    ),
                  ],
                ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
          children: [
            ...list.map((d) {
              final m = d.data();
              final created =
                  (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final updated = (m['updatedAt'] as Timestamp?)?.toDate();
              final edited = (m['edited'] as bool?) == true;
              final iconKey = (m['iconKey'] as String?) ?? 'book';

              return _Card(
                child: ListTile(
                  onTap: () => _viewEntry(d),
                  leading: Icon(_iconForKey(iconKey), color: _teal),
                  title: Text(
                    (m['title'] as String?) ?? 'Untitled',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _textPrimary(context),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        (m['content'] as String?) ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _textPrimary(context)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Created • ${fmtFull(created)}',
                        style: TextStyle(
                          color: _textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                      if (edited && updated != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Edited • ${fmtFull(updated)}',
                          style: TextStyle(
                            color: _textSecondary(context),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        _editEntry(
                          context,
                          col!,
                          d.id,
                          m['title'] ?? '',
                          m['content'] ?? '',
                        );
                      }
                      if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder:
                              (_) => AlertDialog(
                                title: const Text('Delete entry?'),
                                content: const Text('This cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                        );
                        if (ok == true) {
                          await col!.doc(d.id).delete();
                        }
                      }
                      if (v == 'icon') {
                        await _chooseIcon(context, col!, d.id, iconKey);
                      }
                    },
                    itemBuilder:
                        (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                            value: 'icon',
                            child: Text('Change icon'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _editEntry(
    BuildContext context,
    CollectionReference<Map<String, dynamic>> col,
    String id,
    String title,
    String content,
  ) async {
    final tCtl = TextEditingController(text: title);
    final cCtl = TextEditingController(text: content);

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Edit entry'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tCtl,
                    decoration: const InputDecoration(
                      labelText: 'Entry Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cCtl,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Write a private entry…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newTitle = tCtl.text.trim();
                  final newContent = cCtl.text.trim();
                  if (newTitle.isNotEmpty && newContent.isNotEmpty) {
                    await col.doc(id).update({
                      'title': newTitle,
                      'content': newContent,
                      'updatedAt': FieldValue.serverTimestamp(),
                      'edited': true,
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }
}

// ---------------- Small widgets ----------------

class _SegPill extends StatelessWidget {
  const _SegPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.alt = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool alt;

  @override
  Widget build(BuildContext context) {
    final bg =
        active
            ? (alt ? const Color(0xFFFFFFFF) : Colors.white)
            : Colors.white70;
    final fg =
        active
            ? (alt ? const Color(0xFF000000) : Colors.black)
            : Colors.black87;

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Text(
          label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Smart avatar that shows latest profile photo unless anonymous.
class _AvatarSmart extends StatelessWidget {
  const _AvatarSmart({
    required this.uid,
    required this.photoUrlFromPost,
    required this.postAnonymous,
    this.preferFresh = false,
    this.selfFallbackUrl,
  });

  final String? uid;
  final String? photoUrlFromPost;
  final bool postAnonymous;
  final bool preferFresh;
  final String? selfFallbackUrl;

  @override
  Widget build(BuildContext context) {
    const radius = 18.0;
    final placeholder = const CircleAvatar(
      radius: radius,
      backgroundColor: Color(0xFFD7CFFC),
      child: Icon(Icons.person, color: Colors.black54),
    );

    if (postAnonymous) return placeholder;

    if (preferFresh && (uid != null && uid!.isNotEmpty)) {
      return FutureBuilder<String?>(
        future: _PhotoResolver.byUid(uid!),
        builder: (_, snap) {
          final url =
              (snap.data ?? '').isNotEmpty
                  ? snap.data
                  : (selfFallbackUrl?.isNotEmpty == true
                      ? selfFallbackUrl
                      : (photoUrlFromPost?.isNotEmpty == true
                          ? photoUrlFromPost
                          : null));
          if (url != null && url.isNotEmpty) {
            return CircleAvatar(
              radius: radius,
              backgroundImage: NetworkImage(url),
            );
          }
          return placeholder;
        },
      );
    }

    if (photoUrlFromPost != null && photoUrlFromPost!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrlFromPost!),
      );
    }

    if (uid != null && uid!.isNotEmpty) {
      return FutureBuilder<String?>(
        future: _PhotoResolver.byUid(uid!),
        builder: (_, snap) {
          final url =
              (snap.data ?? '').isNotEmpty
                  ? snap.data
                  : (selfFallbackUrl?.isNotEmpty == true
                      ? selfFallbackUrl
                      : null);
          if (url != null && url.isNotEmpty) {
            return CircleAvatar(
              radius: radius,
              backgroundImage: NetworkImage(url),
            );
          }
          return placeholder;
        },
      );
    }

    if (selfFallbackUrl != null && selfFallbackUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(selfFallbackUrl!),
      );
    }

    return placeholder;
  }
}

class _PostMenu extends StatelessWidget {
  const _PostMenu({
    required this.canEdit,
    required this.canDelete,
    required this.canBlock,
    required this.onEdit,
    required this.onDelete,
    required this.onBlock,
  });

  final bool canEdit;
  final bool canDelete;
  final bool canBlock;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
        if (v == 'block') onBlock();
      },
      itemBuilder:
          (c) => [
            if (canEdit)
              const PopupMenuItem(value: 'edit', child: Text('Edit post')),
            if (canDelete)
              const PopupMenuItem(value: 'delete', child: Text('Delete post')),
            if (canBlock)
              const PopupMenuItem(value: 'block', child: Text('Block user')),
          ],
    );
  }
}

class _EmojiSelectable extends StatelessWidget {
  const _EmojiSelectable({
    required this.emoji,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _teal : _textPrimary(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepliesToggle extends StatelessWidget {
  const _RepliesToggle({
    required this.col,
    required this.postId,
    required this.open,
    required this.onPressed,
  });

  final CollectionReference<Map<String, dynamic>> col;
  final String postId;
  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: col.doc(postId).collection('replies').snapshots(),
      builder: (context, snap) {
        final count = snap.data?.size ?? 0;
        return TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.forum_outlined),
          label: Text(open ? 'Hide replies ($count)' : 'Replies $count'),
        );
      },
    );
  }
}

// ---------------- INLINE REPLY COMPOSER (friendlier UI) -------------------
class _InlineReplyComposer extends StatelessWidget {
  const _InlineReplyComposer({
    required this.currentUserName,
    required this.currentUserPhoto,
    required this.ctl,
    required this.onSend,
  });

  final String currentUserName;
  final String? currentUserPhoto;
  final TextEditingController ctl;
  final Future<void> Function(String text) onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _ComposerWithMentions(
        controller: ctl,
        hintText: 'Write a reply…',
        onSubmit: () => onSend(ctl.text),
        compact: true, // friendlier compact style for replies
        leadingAvatarUrl: currentUserPhoto,
      ),
    );
  }
}

// ---------------- Mention-aware composer used for public + replies -------
class _ComposerWithMentions extends StatefulWidget {
  const _ComposerWithMentions({
    required this.controller,
    required this.hintText,
    required this.onSubmit,
    this.focusNode,
    this.compact = false,
    this.showTriggerAdvice,
    this.leadingAvatarUrl,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSubmit;
  final FocusNode? focusNode;
  final bool compact;
  final void Function(bool show)? showTriggerAdvice;
  final String? leadingAvatarUrl; // shown in compact (reply) mode

  @override
  State<_ComposerWithMentions> createState() => _ComposerWithMentionsState();
}

class _ComposerWithMentionsState extends State<_ComposerWithMentions> {
  final _link = LayerLink();
  OverlayEntry? _overlay;

  // user cache
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allUsers = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtered = [];

  String? _activeQuery; // null = hidden
  final _scrollCtl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    _scrollCtl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('users')
              .orderBy('username')
              .limit(100)
              .get();
      _allUsers = snap.docs;
      _filtered = _allUsers;
      if (mounted && _activeQuery != null) _filterUsers(_activeQuery!);
    } catch (_) {
      _allUsers = [];
      _filtered = [];
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final hasText = text.trim().isNotEmpty;
    widget.showTriggerAdvice?.call(hasText);

    final sel = widget.controller.selection;
    final q = _extractMentionQuery(text, sel);
    if (q == null || q.isEmpty) {
      _activeQuery = null;
      _removeOverlay();
      setState(() {});
    } else {
      _activeQuery = q;
      _filterUsers(q);
      _showOverlay();
      setState(() {});
    }
  }

  // Find current "@query" immediately before the caret (no spaces)
  String? _extractMentionQuery(String text, TextSelection sel) {
    if (!sel.isValid || sel.start == -1) return null;
    final i = sel.start;
    if (i == 0) return null;
    int j = i - 1;
    // walk back until whitespace/newline or start
    while (j >= 0 && !RegExp(r'\s').hasMatch(text[j])) {
      if (text[j] == '@') {
        if (j == 0 || RegExp(r'\s').hasMatch(text[j - 1])) {
          return text.substring(j + 1, i);
        }
        break;
      }
      j--;
    }
    return null;
  }

  void _filterUsers(String q) {
    final qq = q.trim().toLowerCase();
    if (qq.isEmpty) {
      _filtered = _allUsers;
    } else {
      _filtered =
          _allUsers.where((d) {
            final u = (d.data()['username'] as String? ?? '').toLowerCase();
            final email = (d.data()['email'] as String? ?? '').toLowerCase();
            return u.contains(qq) || email.contains(qq);
          }).toList();
    }
  }

  void _insertPicked(String username) {
    // replace the "@partial" with "@username "
    final sel = widget.controller.selection;
    final text = widget.controller.text;
    int i = sel.start;
    int j = i - 1;
    while (j >= 0 && !RegExp(r'\s').hasMatch(text[j])) {
      if (text[j] == '@') break;
      j--;
    }
    if (j < 0 || text[j] != '@') return;
    final newText = text.replaceRange(j, i, '@$username ');
    final offset = j + username.length + 2;
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset),
    );
    _activeQuery = null;
    _removeOverlay();
    setState(() {});
  }

  void _showOverlay() {
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    _overlay = OverlayEntry(
      builder:
          (ctx) => Positioned(
            width: MediaQuery.of(context).size.width - 32,
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: const Offset(0, 44), // below the field
              child: Material(
                elevation: 6,
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 180,
                  child: ListView.builder(
                    controller: _scrollCtl,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final d = _filtered[i];
                      final m = d.data();
                      final username = (m['username'] as String? ?? '').trim();
                      final email = (m['email'] as String? ?? '').trim();
                      final photo = (m['photoUrl'] as String?) ?? '';
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFD7CFFC),
                          backgroundImage:
                              photo.isNotEmpty ? NetworkImage(photo) : null,
                          child:
                              photo.isEmpty
                                  ? const Icon(
                                    Icons.person,
                                    color: Colors.black54,
                                  )
                                  : null,
                        ),
                        title: Text(
                          username.isEmpty ? '(no username)' : '@$username',
                        ),
                        subtitle: email.isEmpty ? null : Text(email),
                        onTap: () => _insertPicked(username),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
    );
    Overlay.of(context, debugRequiredFor: widget)?.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  List<TextSpan> _highlightSpans(String s, TextStyle base) {
    final exp = RegExp(r'@([A-Za-z0-9_.-]{2,30})');
    final spans = <TextSpan>[];
    int i = 0;
    for (final m in exp.allMatches(s)) {
      if (m.start > i)
        spans.add(TextSpan(text: s.substring(i, m.start), style: base));
      final uname = m.group(1)!;
      spans.add(
        TextSpan(
          text: '@$uname',
          style: base.merge(
            const TextStyle(color: _teal, fontWeight: FontWeight.w600),
          ),
        ),
      );
      i = m.end;
    }
    if (i < s.length) spans.add(TextSpan(text: s.substring(i), style: base));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final bg = _entryBg(context);
    final padding = EdgeInsets.fromLTRB(
      16,
      widget.compact ? 10 : 14,
      4,
      widget.compact ? 10 : 14,
    );

    // Friendlier compact style (used for replies)
    if (widget.compact) {
      return CompositedTransformTarget(
        link: _link,
        child: Container(
          decoration: BoxDecoration(
            color: _cardBg(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
            border: Border.all(color: Colors.black12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFD7CFFC),
                backgroundImage:
                    (widget.leadingAvatarUrl?.isNotEmpty == true)
                        ? NetworkImage(widget.leadingAvatarUrl!)
                        : null,
                child:
                    (widget.leadingAvatarUrl?.isNotEmpty == true)
                        ? null
                        : const Icon(
                          Icons.person,
                          size: 18,
                          color: Colors.black54,
                        ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: _highlightSpans(
                            widget.controller.text,
                            TextStyle(color: _textPrimary(context)),
                          ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      enableSuggestions: true,
                      autocorrect: true,
                      onSubmitted: (_) => widget.onSubmit(),
                      cursorColor: _teal,
                      style: const TextStyle(
                        color: Colors.transparent,
                        height: 1.2,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Write a reply…',
                        border: InputBorder.none,
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      );
    }

    // Default (top composer) style remains
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: CompositedTransformTarget(
        link: _link,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(.18)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Padding(
                      padding: padding,
                      child: RichText(
                        text: TextSpan(
                          children: _highlightSpans(
                            widget.controller.text,
                            TextStyle(color: _textPrimary(context)),
                          ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      enableSuggestions: true,
                      autocorrect: true,
                      textInputAction: TextInputAction.newline,
                      onSubmitted: (_) => widget.onSubmit(),
                      cursorColor: _teal,
                      style: const TextStyle(
                        color: Colors.transparent,
                        height: 1.2,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        border: InputBorder.none,
                        isDense: true,
                        filled: false,
                        contentPadding: padding,
                      ),
                    ),
                  ],
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.white.withOpacity(.12),
                  highlightColor: Colors.white.withOpacity(.08),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send),
                  color: _teal,
                  splashRadius: widget.compact ? 20 : 22,
                  tooltip: 'Send',
                  onPressed: widget.onSubmit,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Replies thread with nested replies ----------------
class _ReplyThread extends StatefulWidget {
  const _ReplyThread({
    required this.postId,
    required this.public,
    this.limit = 200,
    this.currentUid,
    required this.selfAnon,
    required this.onReply,
    required this.onBlock,
    required this.blocked,
  });

  final String postId;
  final CollectionReference<Map<String, dynamic>> public;
  final int limit;
  final String? currentUid;
  final bool selfAnon;
  final Future<void> Function(String postId, String text, {String? parentId})
  onReply;
  final Future<void> Function(String otherUid) onBlock;
  final Set<String> blocked;

  @override
  State<_ReplyThread> createState() => _ReplyThreadState();
}

class _ReplyThreadState extends State<_ReplyThread> {
  final Map<String, TextEditingController> _nestedCtls = {};
  final Set<String> _openUnder = {}; // replyIds with composer open

  TextEditingController _ctlFor(String id) =>
      _nestedCtls.putIfAbsent(id, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _nestedCtls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          widget.public
              .doc(widget.postId)
              .collection('replies')
              .orderBy('createdAt', descending: false)
              .limit(widget.limit)
              .snapshots(),
      builder: (context, snap) {
        final repliesAll = snap.data?.docs ?? [];
        final replies =
            repliesAll.where((r) {
              final uid = (r.data()['uid'] as String?) ?? '';
              return !widget.blocked.contains(uid);
            }).toList();

        if (replies.isEmpty) return const SizedBox.shrink();

        // Build parent -> children map (parentId may be null)
        final children =
            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        final roots = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        for (final r in replies) {
          final parent = (r.data()['parentId'] as String?) ?? '';
          if (parent.isEmpty) {
            roots.add(r);
          } else {
            children.putIfAbsent(parent, () => []).add(r);
          }
        }

        Widget buildNode(
          QueryDocumentSnapshot<Map<String, dynamic>> r,
          int depth,
        ) {
          final m = r.data();
          final ts = (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final replyUid = (m['uid'] as String?) ?? '';
          final provided = (m['username'] as String?) ?? '';
          final storedAnon = (m['isAnonymous'] as bool?) == true;

          final isSelf =
              widget.currentUid != null && widget.currentUid == replyUid;
          final displayAnon = isSelf ? widget.selfAnon : storedAnon;
          final canEditReply = isSelf;
          final canBlock = !isSelf && replyUid.isNotEmpty;

          final kids = children[r.id] ?? const [];

          return Padding(
            padding: EdgeInsets.only(left: depth * 16.0, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarSmart(
                  uid: replyUid,
                  photoUrlFromPost: m['photoUrl'] as String?,
                  postAnonymous: displayAnon,
                  preferFresh: isSelf,
                  selfFallbackUrl:
                      isSelf
                          ? FirebaseAuth.instance.currentUser?.photoURL
                          : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _replyBg(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _UsernameTag(
                                uid: replyUid,
                                provided: provided,
                                isAnonymous: displayAnon,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary(context),
                                ),
                              ),
                            ),
                            if ((m['edited'] as bool?) == true)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  'Edited',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontStyle: FontStyle.italic,
                                    color: _textSecondary(context),
                                  ),
                                ),
                              ),
                            Text(
                              DateFormat('MMM d, yyyy • hh:mm a').format(ts),
                              style: TextStyle(
                                color: _textSecondary(context),
                                fontSize: 11,
                              ),
                            ),
                            if (canEditReply || canBlock) ...[
                              const SizedBox(width: 6),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_horiz, size: 18),
                                onSelected: (v) async {
                                  if (v == 'edit-reply') {
                                    final ctl = TextEditingController(
                                      text: (m['content'] as String?) ?? '',
                                    );
                                    await showDialog(
                                      context: context,
                                      builder:
                                          (_) => AlertDialog(
                                            title: const Text('Edit reply'),
                                            content: TextField(
                                              controller: ctl,
                                              maxLines: 6,
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  final newText =
                                                      ctl.text.trim();
                                                  if (newText.isNotEmpty) {
                                                    await widget.public
                                                        .doc(widget.postId)
                                                        .collection('replies')
                                                        .doc(r.id)
                                                        .update({
                                                          'content': newText,
                                                          'updatedAt':
                                                              FieldValue.serverTimestamp(),
                                                          'edited': true,
                                                        });
                                                  }
                                                  Navigator.pop(context);
                                                },
                                                child: const Text('Save'),
                                              ),
                                            ],
                                          ),
                                    );
                                  }
                                  if (v == 'delete-reply') {
                                    await widget.public
                                        .doc(widget.postId)
                                        .collection('replies')
                                        .doc(r.id)
                                        .delete();
                                    try {
                                      await widget.public
                                          .doc(widget.postId)
                                          .update({
                                            'replyCount': FieldValue.increment(
                                              -1,
                                            ),
                                          });
                                    } catch (_) {}
                                  }
                                  if (v == 'block-user') {
                                    await widget.onBlock(replyUid);
                                  }
                                },
                                itemBuilder:
                                    (_) => [
                                      if (canEditReply)
                                        const PopupMenuItem(
                                          value: 'edit-reply',
                                          child: Text('Edit reply'),
                                        ),
                                      if (canEditReply)
                                        const PopupMenuItem(
                                          value: 'delete-reply',
                                          child: Text('Delete reply'),
                                        ),
                                      if (canBlock)
                                        const PopupMenuItem(
                                          value: 'block-user',
                                          child: Text('Block user'),
                                        ),
                                    ],
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        _MentionRichText(text: (m['content'] as String?) ?? ''),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed:
                                  () => setState(() {
                                    if (_openUnder.contains(r.id)) {
                                      _openUnder.remove(r.id);
                                    } else {
                                      _openUnder.add(r.id);
                                    }
                                  }),
                              icon: const Icon(Icons.reply_outlined, size: 18),
                              label: const Text('Reply'),
                            ),
                          ],
                        ),
                        if (_openUnder.contains(r.id))
                          _InlineReplyComposer(
                            currentUserName:
                                FirebaseAuth
                                    .instance
                                    .currentUser
                                    ?.displayName ??
                                'You',
                            currentUserPhoto:
                                FirebaseAuth.instance.currentUser?.photoURL,
                            ctl: _ctlFor(r.id),
                            onSend: (txt) async {
                              final v = _ctlFor(r.id).text;
                              if (v.trim().isNotEmpty) {
                                await widget.onReply(
                                  widget.postId,
                                  v,
                                  parentId: r.id,
                                );
                                _ctlFor(r.id).clear();
                                setState(() => _openUnder.remove(r.id));
                              }
                            },
                          ),
                        if (kids.isNotEmpty) const SizedBox(height: 6),
                        if (kids.isNotEmpty)
                          ...kids.map((child) => buildNode(child, depth + 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(children: roots.map((r) => buildNode(r, 0)).toList()),
        );
      },
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text, this.trimAt = 140});
  final String text;
  final int trimAt;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  List<TextSpan> _spansFrom(String s, TextStyle base) {
    final exp = RegExp(r'@([A-Za-z0-9_.-]{2,30})');
    final spans = <TextSpan>[];
    int i = 0;
    for (final m in exp.allMatches(s)) {
      if (m.start > i) {
        spans.add(TextSpan(text: s.substring(i, m.start), style: base));
      }
      final uname = m.group(1)!;
      spans.add(
        TextSpan(
          text: '@$uname',
          style: base.merge(
            const TextStyle(color: _teal, fontWeight: FontWeight.w600),
          ),
          recognizer:
              TapGestureRecognizer()
                ..onTap = () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('@$uname')));
                },
        ),
      );
      i = m.end;
    }
    if (i < s.length) spans.add(TextSpan(text: s.substring(i), style: base));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > widget.trimAt;
    final textToShow =
        long && !_expanded
            ? (widget.text.substring(0, widget.trimAt) + '…')
            : widget.text;
    final base = TextStyle(color: _textPrimary(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(text: TextSpan(children: _spansFrom(textToShow, base))),
        if (long)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Show less' : 'Show more…'),
          ),
      ],
    );
  }
}

class _MentionRichText extends StatelessWidget {
  const _MentionRichText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(color: _textPrimary(context));
    final exp = RegExp(r'@([A-Za-z0-9_.-]{2,30})');

    final spans = <TextSpan>[];
    int i = 0;
    for (final m in exp.allMatches(text)) {
      if (m.start > i) {
        spans.add(TextSpan(text: text.substring(i, m.start), style: base));
      }
      final uname = m.group(1)!;
      spans.add(
        TextSpan(
          text: '@$uname',
          style: base.merge(
            const TextStyle(color: _teal, fontWeight: FontWeight.w600),
          ),
          recognizer:
              TapGestureRecognizer()
                ..onTap = () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('@$uname')));
                },
        ),
      );
      i = m.end;
    }
    if (i < text.length)
      spans.add(TextSpan(text: text.substring(i), style: base));

    return RichText(text: TextSpan(children: spans));
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.white70),
            const SizedBox(height: 12),
            const Text(
              'No posts yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: fg),
        ),
      ),
    );
  }
}

class _BottomNavTransparent extends StatelessWidget {
  final int selectedIndex; // 0=home, 1=journal, 2=settings
  final VoidCallback onHome;
  final VoidCallback onJournal;
  final VoidCallback onSettings;

  const _BottomNavTransparent({
    required this.selectedIndex,
    required this.onHome,
    required this.onJournal,
    required this.onSettings,
  });

  Color _c(BuildContext context, int idx) {
    final sel = selectedIndex == idx;
    if (sel && _isDark(context)) return _headerPurple; // match home page purple
    return sel ? _teal : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.home, color: _c(context, 0)),
            onPressed: onHome,
          ),
          IconButton(
            icon: Icon(Icons.menu_book_rounded, color: _c(context, 1)),
            onPressed: onJournal,
          ),
          IconButton(
            icon: Icon(Icons.settings, color: _c(context, 2)),
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _UsernameTag extends StatelessWidget {
  const _UsernameTag({
    required this.uid,
    required this.provided,
    required this.isAnonymous,
    required this.style,
  });

  final String uid;
  final String provided;
  final bool isAnonymous;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (isAnonymous) return Text('anonymous user', style: style);
    if (uid.isEmpty) {
      final fb = provided.trim().isEmpty ? 'user' : provided.trim();
      return Text('@$fb', style: style);
    }
    return FutureBuilder<String?>(
      future: _UsernameResolver.resolveByUid(uid),
      builder: (_, snap) {
        final fromDoc = (snap.data ?? '').trim();
        final show =
            fromDoc.isNotEmpty
                ? fromDoc
                : (provided.trim().isEmpty ? 'user' : provided.trim());
        return Text('@$show', style: style);
      },
    );
  }
}

// ---------- Helper: Sort chip (not used but kept) ----------
class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      showCheckmark: true,
      avatar: Icon(icon, size: 18, color: _teal),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      selectedColor: _teal.withOpacity(.15),
      onSelected: (_) => onTap(),
    );
  }
}

// ---------- Helper: circular icon button for sorting ----------
class _SortIconButton extends StatelessWidget {
  const _SortIconButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? _teal.withOpacity(.18) : Colors.white.withOpacity(.22);
    final fg = selected ? _teal : _teal.withOpacity(.95);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: fg, size: 22),
          ),
        ),
      ),
    );
  }
}
