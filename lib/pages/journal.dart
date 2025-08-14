// lib/pages/journal.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:new_rezonate/pages/home.dart' as home_page;
import 'package:new_rezonate/main.dart' as app;
import 'package:new_rezonate/pages/settings.dart';
import 'package:new_rezonate/pages/services/user_settings.dart' as app_settings;

// ---------------- Colors / gradient ----------------
const _teal = Color(0xFF0D7C66);

/// Username resolver for your schema:
/// 1) /users/{uid}.username
/// 2) if missing, /users where email == user's email
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

enum _TimeFilter { all, d1, d7, d30 }
enum _OrderBy { dateDesc, dateAsc, mostReacted, mostReplies }

class JournalPage extends StatefulWidget {
  final String userName;
  const JournalPage({Key? key, required this.userName}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage>
    with SingleTickerProviderStateMixin {
  int _seg = 0;

  final _searchCtl = TextEditingController();
  final _pubCtl = TextEditingController();
  final _privTitleCtl = TextEditingController();
  final _privContentCtl = TextEditingController();

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

  // filters
  _TimeFilter _timeFilter = _TimeFilter.all;
  _OrderBy _orderBy = _OrderBy.dateDesc;

  @override
  void initState() {
    super.initState();
    _loadBlocked();

    _pubFocus.addListener(() {
      if (_pubFocus.hasFocus && !_showTriggerAdvice) {
        setState(() => _showTriggerAdvice = true);
      }
    });
  }

  Future<void> _loadBlocked() async {
    final u = _user;
    if (u == null) return;
    final me =
        await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final list = (me.data()?['blocked_uids'] as List?)?.cast<String>() ?? [];
    setState(() => _blocked = list.toSet());
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _pubCtl.dispose();
    _privTitleCtl.dispose();
    _privContentCtl.dispose();
    _pubFocus.dispose();
    for (final c in _replyCtls.values) {
      c.dispose();
    }
    super.dispose();
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

  Future<bool> _isAnonymousNow() async {
    return app_settings.UserSettings.anonymous == true;
  }

  // ---------------- Community actions ----------------

  Future<void> _postPublic() async {
    final text = _pubCtl.text.trim();
    final u = _user;
    if (text.isEmpty || u == null) return;

    final anon = await _isAnonymousNow();

    final safeUsername =
        anon
            ? 'anonymous user'
            : await _UsernameResolver.forCurrent(u, widget.userName);

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final photoUrl =
        anon ? null : (userDoc.data()?['photoUrl'] as String?) ?? u.photoURL;

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
    });

    _pubCtl.clear();
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

  Future<void> _reply(String postId, String text) async {
    final t = text.trim();
    final u = _user;
    if (t.isEmpty || u == null) return;

    final anon = await _isAnonymousNow();

    final safeUsername =
        anon
            ? 'anonymous user'
            : await _UsernameResolver.forCurrent(u, widget.userName);

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final photoUrl =
        anon ? null : (userDoc.data()?['photoUrl'] as String?) ?? u.photoURL;

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
      builder: (_) => AlertDialog(
        title: const Text('Edit post'),
        content: TextField(
          controller: ctl,
          maxLines: 8,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newText = ctl.text.trim();
              if (newText.isNotEmpty) {
                await _public.doc(postId).update({
                  'content': newText,
                  'updatedAt': FieldValue.serverTimestamp(),
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
      builder: (_) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
    });
  }

  // ---------------- Fetch ALL posts for search (paged) ----------------
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchAllPosts({
    int batchSize = 500,
  }) async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> acc = [];
    Query<Map<String, dynamic>> q = _public
        .orderBy('createdAt', descending: true)
        .limit(batchSize);

    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      acc.addAll(snap.docs);
      if (snap.docs.length < batchSize) break;

      last = snap.docs.last;
      q = _public
          .orderBy('createdAt', descending: true)
          .startAfterDocument(last)
          .limit(batchSize);
    }
    return acc;
  }

  // ---------------- Search (no date limit) ----------------
  Future<void> _openSearch() async {
    _searchCtl.clear();
    await showDialog(
      context: context,
      builder: (ctx) {
        List<QueryDocumentSnapshot<Map<String, dynamic>>> results = [];
        bool loading = false;
        String? error;

        Future<void> perform(String q) async {
          if (q.trim().isEmpty) return;
          loading = true;
          error = null;
          (ctx as Element).markNeedsBuild();
          try {
            final all = await _fetchAllPosts();
            final needle = q.toLowerCase();
            results = all.where((d) {
              final m = d.data();
              if (_blocked.contains(m['uid'])) return false;
              final content = (m['content'] as String?)?.toLowerCase() ?? '';
              final uname = (m['username'] as String?)?.toLowerCase() ?? '';
              return content.contains(needle) || uname.contains(needle);
            }).toList();
          } catch (e) {
            error = 'Search failed: $e';
          } finally {
            loading = false;
            (ctx as Element).markNeedsBuild();
          }
        }

        return StatefulBuilder(
          builder: (_, setLocal) {
            return AlertDialog(
              title: const Text('Search community'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchCtl,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (v) => perform(v),
                      decoration: const InputDecoration(
                        hintText: 'Search posts & usernames… (no date limit)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (loading) const LinearProgressIndicator(),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(error!, style: const TextStyle(color: Colors.red)),
                      ),
                    if (!loading && results.isNotEmpty)
                      SizedBox(
                        height: 360,
                        child: ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final m = results[i].data();
                            final ts = (m['createdAt'] as Timestamp?)?.toDate();
                            return ListTile(
                              leading: const Icon(Icons.article_outlined),
                              title: Text((m['content'] as String?) ?? ''),
                              subtitle: Text(
                                '${(m['username'] as String?) ?? 'user'} • ${ts != null ? _fmtFull(ts) : ''}',
                              ),
                            );
                          },
                        ),
                      ),
                    if (!loading && results.isEmpty && error == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('No matches found.'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () => perform(_searchCtl.text),
                  child: const Text('Search'),
                ),
              ],
            );
          },
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/images/Logo.png',
          height: 60, // bigger logo
          errorBuilder: (_, __, ___) =>
              Icon(Icons.bolt, color: _teal.withOpacity(.9), size: 32),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
        ],
      ),
      // NOTE: FAB moved into a Positioned widget above the custom bottom nav.
      body: Container(
        decoration: BoxDecoration(gradient: _bg(context)),
        child: SafeArea(
          child: Stack(
            children: [
              // Main content + bottom nav
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
                      _SegPill(
                        label: 'My Journal',
                        active: _seg == 1,
                        onTap: () => setState(() => _seg = 1),
                        alt: true,
                      ),
                    ],
                  ),
                  // Filters (community only)
                  if (_seg == 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Center(
                        child: Wrap(
                          spacing: 12,
                          alignment: WrapAlignment.center,
                          runSpacing: 6,
                          children: [
                            _SmallDropdown<_TimeFilter>(
                              value: _timeFilter,
                              onChanged: (v) => setState(() => _timeFilter = v!),
                              items: const [
                                DropdownMenuItem(value: _TimeFilter.all, child: Text('All time')),
                                DropdownMenuItem(value: _TimeFilter.d1, child: Text('Last 24h')),
                                DropdownMenuItem(value: _TimeFilter.d7, child: Text('Last 7 days')),
                                DropdownMenuItem(value: _TimeFilter.d30, child: Text('Last 30 days')),
                              ],
                            ),
                            _SmallDropdown<_OrderBy>(
                              value: _orderBy,
                              onChanged: (v) => setState(() => _orderBy = v!),
                              items: const [
                                DropdownMenuItem(value: _OrderBy.dateDesc, child: Text('Newest')),
                                DropdownMenuItem(value: _OrderBy.dateAsc, child: Text('Oldest')),
                                DropdownMenuItem(value: _OrderBy.mostReacted, child: Text('Most reacted')),
                                DropdownMenuItem(value: _OrderBy.mostReplies, child: Text('Most replies')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
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
                            Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
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
                  const SizedBox(height: 6),
                  Expanded(
                    child:
                        _seg == 0
                            ? _CommunityFeed(
                                user: u,
                                blocked: _blocked,
                                publicCol: _public,
                                onReact: _reactOnce,
                                onReply: _reply,
                                onDelete: _deletePost,
                                onEdit: _editPost,
                                onBlock: _blockUser,
                                openReplyFor: _openReplyFor,
                                setOpenReplyFor: (id) {
                                  setState(() => _openReplyFor = id == _openReplyFor ? null : id);
                                },
                                replyCtlFor: (id) => _replyCtls.putIfAbsent(
                                  id,
                                  () => TextEditingController(),
                                ),
                                fmtFull: _fmtFull,
                                relative: _relative,
                                filterFrom: _filterFromDate(_timeFilter),
                                orderBy: _orderBy,
                              )
                            : _PrivateJournal(
                                uid: u?.uid,
                                col: u == null ? null : _privateCol(u.uid),
                                fmtFull: _fmtFull,
                              ),
                  ),
                  if (_seg == 0) _publicComposer() else const SizedBox(height: 8),
                  _BottomNavTransparent(
                    selectedIndex: 1,
                    onHome:
                        () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                home_page.HomePage(userName: widget.userName),
                          ),
                        ),
                    onJournal: () {},
                    onSettings:
                        () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsPage(userName: widget.userName),
                          ),
                        ),
                  ),
                ],
              ),

              // >>> FAB positioned ABOVE the bottom nav when in "My Journal"
              if (_seg == 1)
                Positioned(
                  right: 16,
                  bottom: 86, // sits above the custom bottom nav row
                  child: FloatingActionButton(
                    backgroundColor: _teal,
                    onPressed: _openCreatePrivateDialog,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _publicComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pubCtl,
                focusNode: _pubFocus,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                onChanged: (_) {
                  if (!_showTriggerAdvice) {
                    setState(() => _showTriggerAdvice = true);
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'Write something…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _RoundIcon(
                icon: Icons.send,
                onTap: _postPublic,
                bg: _teal,
                fg: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors:
          dark
              ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
              : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
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
  });

  final User? user;
  final Set<String> blocked;
  final CollectionReference<Map<String, dynamic>> publicCol;
  final Future<void> Function(String postId, String emoji) onReact;
  final Future<void> Function(String postId, String text) onReply;
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

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = publicCol;
    if (filterFrom != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(filterFrom!));
    }
    switch (orderBy) {
      case _OrderBy.dateDesc:
        q = q.orderBy('createdAt', descending: true);
        break;
      case _OrderBy.dateAsc:
        q = q.orderBy('createdAt', descending: false);
        break;
      case _OrderBy.mostReacted:
        q = q.orderBy('reactionScore', descending: true).orderBy('createdAt', descending: true);
        break;
      case _OrderBy.mostReplies:
        q = q.orderBy('replyCount', descending: true).orderBy('createdAt', descending: true);
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

        final docs =
            (snap.data?.docs ?? [])
                .where((d) => !blocked.contains(d.data()['uid']))
                .toList();

        if (docs.isEmpty) {
          return const _EmptyHint(
            icon: Icons.public,
            title: 'No posts yet',
            subtitle: 'Be the first to share something with the community.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final m = doc.data();
            final ts =
                (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final postUid = (m['uid'] as String?) ?? '';
            final providedName = (m['username'] as String?)?.trim() ?? '';
            final isAnon = (m['isAnonymous'] as bool?) == true;

            final canEdit = user?.uid == postUid;
            final canBlock =
                postUid.isNotEmpty && user?.uid != postUid;

            return _Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Avatar(
                          photoUrl: m['photoUrl'] as String?,
                          anonymous: isAnon,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _UsernameTag(
                            uid: postUid,
                            provided: providedName,
                            isAnonymous: isAnon,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          fmtFull(ts),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _PostMenu(
                          canEdit: canEdit,
                          canDelete: canEdit,
                          canBlock: canBlock,
                          onEdit: () => onEdit(doc.id, (m['content'] as String?) ?? ''),
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

  @override
  Widget build(BuildContext context) {
    if (uid == null || col == null) {
      return const Center(child: Text('Sign in to view your private entries.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          col!.orderBy('createdAt', descending: true).limit(200).snapshots(),
      builder: (context, snap) {
        final list = snap.data?.docs ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('No entries yet. Tap + to add one.'));
        }

        Future<void> _viewEntry(QueryDocumentSnapshot<Map<String, dynamic>> d) async {
          final m = d.data();
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text((m['title'] as String?) ?? 'Untitled'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Text((m['content'] as String?) ?? ''),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _editEntry(context, col!, d.id, m['title'] ?? '', m['content'] ?? '');
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
              final ts =
                  (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              return _Card(
                child: ListTile(
                  onTap: () => _viewEntry(d),
                  leading: const Icon(Icons.lock_outline),
                  title: Text(
                    (m['title'] as String?) ?? 'Untitled',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        (m['content'] as String?) ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        fmtFull(ts),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        _editEntry(context, col!, d.id, m['title'] ?? '', m['content'] ?? '');
                      }
                      if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete entry?'),
                            content: const Text('This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await col!.doc(d.id).delete();
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
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
      builder: (_) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newTitle = tCtl.text.trim();
              final newContent = cCtl.text.trim();
              if (newTitle.isNotEmpty && newContent.isNotEmpty) {
                await col.doc(id).update({
                  'title': newTitle,
                  'content': newContent,
                  'updatedAt': FieldValue.serverTimestamp(),
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

class _SmallDropdown<T> extends StatelessWidget {
  const _SmallDropdown({
    required this.value,
    required this.onChanged,
    required this.items,
  });

  final T value;
  final ValueChanged<T?> onChanged;
  final List<DropdownMenuItem<T>> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        underline: const SizedBox.shrink(),
        items: items
            .map((e) => DropdownMenuItem<T>(
                  value: e.value,
                  child: DefaultTextStyle(
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    child: e.child,
                  ),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

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
    final fg = active ? (alt ? const Color(0xFF000000) : Colors.black) : Colors.black87;

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
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.photoUrl, this.anonymous = false});
  final String? photoUrl;
  final bool anonymous;

  @override
  Widget build(BuildContext context) {
    const radius = 18.0;
    if (!anonymous && photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    return const CircleAvatar(
      radius: radius,
      backgroundColor: Color(0xFFD7CFFC),
      child: Icon(Icons.person, color: Colors.black54),
    );
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
            if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit post')),
            if (canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete post')),
            if (canBlock) const PopupMenuItem(value: 'block', child: Text('Block user')),
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
    final color = selected ? _teal : Colors.black87;
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
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctl,
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 6,
              onSubmitted: (_) => onSend(ctl.text),
              decoration: const InputDecoration(
                hintText: 'Reply…',
                border: InputBorder.none,
              ),
            ),
          ),
          Material(
            color: _teal,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onSend(ctl.text),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyThread extends StatelessWidget {
  const _ReplyThread({
    required this.postId,
    required this.public,
    this.limit = 25,
    this.currentUid,
  });
  final String postId;
  final CollectionReference<Map<String, dynamic>> public;
  final int limit;
  final String? currentUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          public
              .doc(postId)
              .collection('replies')
              .orderBy('createdAt', descending: false)
              .limit(limit)
              .snapshots(),
      builder: (context, snap) {
        final replies = snap.data?.docs ?? [];
        if (replies.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children:
                replies.map((r) {
                  final m = r.data();
                  final ts =
                      (m['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now();
                  final replyUid = (m['uid'] as String?) ?? '';
                  final provided = (m['username'] as String?) ?? '';
                  final isAnon = (m['isAnonymous'] as bool?) == true;

                  final canEditReply =
                      currentUid != null && currentUid == replyUid;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Avatar(
                          photoUrl: m['photoUrl'] as String?,
                          anonymous: isAnon,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
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
                                        isAnonymous: isAnon,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM d, yyyy • hh:mm a').format(ts),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (canEditReply) ...[
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
                                              builder: (_) => AlertDialog(
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
                                                    onPressed: () => Navigator.pop(context),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      final newText = ctl.text.trim();
                                                      if (newText.isNotEmpty) {
                                                        await public
                                                            .doc(postId)
                                                            .collection('replies')
                                                            .doc(r.id)
                                                            .update({
                                                          'content': newText,
                                                          'updatedAt': FieldValue.serverTimestamp(),
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
                                            await public
                                                .doc(postId)
                                                .collection('replies')
                                                .doc(r.id)
                                                .delete();
                                            try {
                                              await public
                                                  .doc(postId)
                                                  .update({'replyCount': FieldValue.increment(-1)});
                                            } catch (_) {}
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit-reply',
                                            child: Text('Edit reply'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete-reply',
                                            child: Text('Delete reply'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text((m['content'] as String?) ?? ''),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
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

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > widget.trimAt;
    final visible =
        long && !_expanded
            ? (widget.text.substring(0, widget.trimAt) + '…')
            : widget.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(visible),
        if (long)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Show less' : 'Show more…'),
          ),
      ],
    );
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
        color: Colors.white,
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
            Text(
              title,
              style: const TextStyle(
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

  Color _c(int idx) => selectedIndex == idx ? _teal : Colors.white;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.home_filled, color: _c(0)),
            onPressed: onHome,
          ),
          IconButton(
            icon: Icon(Icons.menu_book_rounded, color: _c(1)),
            onPressed: onJournal,
          ),
          IconButton(
            icon: Icon(Icons.settings, color: _c(2)),
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
    if (isAnonymous) {
      return Text('anonymous user', style: style);
    }

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
