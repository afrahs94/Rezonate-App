/*// lib/pages/journal_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_rezonate/pages/services/user_settings.dart';
import 'package:new_rezonate/pages/home.dart' as home_page;
import 'package:new_rezonate/pages/settings.dart';

class PublicPost {
  final String username;
  final String content;
  final DateTime timestamp;
  PublicPost({
    required this.username,
    required this.content,
    required this.timestamp,
  });
}

class PrivatePost {
  final String title;
  final String content;
  final DateTime timestamp;
  PrivatePost({
    required this.title,
    required this.content,
    required this.timestamp,
  });
}

class JournalPage extends StatefulWidget {
  final String userName;
  const JournalPage({Key? key, required this.userName}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final _pubCtl = TextEditingController();
  final _privTitleCtl = TextEditingController();
  final _privContentCtl = TextEditingController();

  final List<PublicPost> _publicPosts = [];
  final List<PrivatePost> _privatePosts = [];

  void _postPublic() {
    final txt = _pubCtl.text.trim();
    if (txt.isNotEmpty) {
      setState(() {
        _publicPosts.insert(
          0,
          PublicPost(
            username: widget.userName,
            content: txt,
            timestamp: DateTime.now(),
          ),
        );
      });
      _pubCtl.clear();
    }
  }

  void _editPublic(int idx) async {
    final ctl = TextEditingController(text: _publicPosts[idx].content);
    final updated = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Post'),
        content: TextField(controller: ctl, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (updated != null && updated.isNotEmpty) {
      setState(() {
        _publicPosts[idx] = PublicPost(
          username: _publicPosts[idx].username,
          content: updated,
          timestamp: DateTime.now(),
        );
      });
    }
  }

  void _deletePublic(int idx) => setState(() => _publicPosts.removeAt(idx));

  void _postPrivate() {
    final title = _privTitleCtl.text.trim();
    final body = _privContentCtl.text.trim();
    if (title.isNotEmpty && body.isNotEmpty) {
      setState(() {
        _privatePosts.insert(
          0,
          PrivatePost(
            title: title,
            content: body,
            timestamp: DateTime.now(),
          ),
        );
      });
      _privTitleCtl.clear();
      _privContentCtl.clear();
    }
  }

  String _fmt(DateTime d) => DateFormat('MMM d, yyyy • kk:mm').format(d);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => home_page.HomePage(userName: widget.userName)),
            ),
          ),
          title: const Text('Journal'),
          centerTitle: true,
          bottom: const TabBar(tabs: [Tab(text: 'Public'), Tab(text: 'Private')]),
        ),
        body: TabBarView(children: [
          // Public Tab
          Column(children: [
            Expanded(
              child: ListView.builder(
                itemCount: _publicPosts.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (c, i) {
                  final p = _publicPosts[i];
                  final mine = p.username == widget.userName;
                  final displayName = UserSettings.anonymous ? 'Anonymous' : p.username;
                  return ListTile(
                    leading: CircleAvatar(child: Text(displayName[0].toUpperCase())),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(p.content, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        _fmt(p.timestamp),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    trailing: mine
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _editPublic(i)),
                            IconButton(icon: const Icon(Icons.delete), onPressed: () => _deletePublic(i)),
                          ])
                        : null,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _pubCtl,
                    decoration: InputDecoration(
                      hintText: 'Write a public post...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: _postPublic,
                ),
              ]),
            ),
          ]),

          // Private Tab
          Column(children: [
            Expanded(
              child: ListView.builder(
                itemCount: _privatePosts.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (c, i) {
                  final e = _privatePosts[i];
                  return ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.content),
                      const SizedBox(height: 4),
                      Text(_fmt(e.timestamp), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                TextField(
                  controller: _privTitleCtl,
                  decoration: InputDecoration(
                    hintText: 'Entry title...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _privContentCtl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Write a private entry...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    color: Theme.of(context).primaryColor,
                    onPressed: _postPrivate,
                  ),
                ),
              ]),
            ),
          ]),
        ]),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _NavItem(
              icon: Icons.home,
              isSelected: false,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => home_page.HomePage(userName: widget.userName),
                  ),
                );
              },
            ),
            _NavItem(
              icon: Icons.public,
              isSelected: true,
              onTap: () {}, // already on Journal
            ),
            _NavItem(
              icon: Icons.settings,
              isSelected: false,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(userName: widget.userName),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: isSelected
            ? BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(16))
            : null,
        child: Icon(icon, size: 28, color: isSelected ? Colors.purple : Colors.grey.shade600),
      ),
    );
  }
}

lib/pages/journal.dart
lib/pages/journal.dart
lib/pages/journal.dart
lib/pages/journal.dart




lib/pages/journal.dart
lib/pages/journal.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:new_rezonate/pages/home.dart' as home_page;
import 'package:new_rezonate/pages/settings.dart';

// ---------------- Colors / gradient ----------------
const _lavender = Color(0xFFD9CEF8);
const _frost    = Color(0xFFCFE1E8);
const _aqua     = Color(0xFFC5E7DD);
const _mint     = Color(0xFFBFEBD1);
const _teal     = Color(0xFF0D7C66);

class JournalPage extends StatefulWidget {
  final String userName; // same name shown on Home ("Hello, ...")
  const JournalPage({Key? key, required this.userName}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage>
    with SingleTickerProviderStateMixin {
  // 0 = Community, 1 = My Journal
  int _seg = 0;

  // search dialog text
  final _searchCtl = TextEditingController();

  // community composer
  final _pubCtl = TextEditingController();

  // private composer
  final _privTitleCtl = TextEditingController();
  final _privContentCtl = TextEditingController();

  // per-post reply controller (when opened)
  final Map<String, TextEditingController> _replyCtls = {};
  String? _openReplyFor; // which post id is expanded

  // auth / firestore
  User? get _user => FirebaseAuth.instance.currentUser;
  CollectionReference<Map<String, dynamic>> get _public =>
      FirebaseFirestore.instance.collection('public_posts');
  CollectionReference<Map<String, dynamic>> _privateCol(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private_posts');

  // blocked users simple list
  Set<String> _blocked = {};

  @override
  void initState() {
    super.initState();
    _loadBlocked();
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
    for (final c in _replyCtls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------- Helpers ----------------
  String _fmtFull(DateTime d) => DateFormat('MMM d, yyyy • hh:mm a').format(d);
  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  // ---------------- Community actions ----------------

  /// Post to community. Saves username/photo from user doc when available.
  Future<void> _postPublic() async {
    final text = _pubCtl.text.trim();
    final u = _user;
    if (text.isEmpty || u == null) return;

    String username = widget.userName;
    String? photoUrl;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final md = userDoc.data();
    if (md != null) {
      username = (md['username'] as String?)?.trim().isNotEmpty == true
          ? md['username'] as String
          : (u.displayName ?? widget.userName);
      photoUrl = (md['photoUrl'] as String?) ?? u.photoURL;
    } else {
      username = u.displayName ?? widget.userName;
      photoUrl = u.photoURL;
    }

    final now = FieldValue.serverTimestamp();
    await _public.add({
      'uid': u.uid,
      'username': username,
      'photoUrl': photoUrl,
      'content': text,
      'createdAt': now,
      'updatedAt': now,
      'reactions': {'❤️': 0, '👍': 0, '🥲': 0},
    });

    _pubCtl.clear();
  }

  /// One reaction per post per user.
  /// Tapping the same emoji again **removes** your reaction (toggle off).
  Future<void> _reactOnce(String postId, String emoji) async {
    final u = _user;
    if (u == null) return;

    final postRef = _public.doc(postId);
    final myReactRef = postRef.collection('reactions').doc(u.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final mySnap = await tx.get(myReactRef);

      if (!mySnap.exists) {
        // first time reacting
        tx.set(myReactRef, {
          'emoji': emoji,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {'reactions.$emoji': FieldValue.increment(1)});
        return;
      }

      final prev = (mySnap.data() as Map<String, dynamic>)['emoji'] as String?;

      if (prev == emoji) {
        // toggle OFF
        tx.update(postRef, {'reactions.$emoji': FieldValue.increment(-1)});
        tx.delete(myReactRef);
        return;
      }

      // switch to a different emoji
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

    String username = widget.userName;
    String? photoUrl = u.photoURL;
    final md = (await FirebaseFirestore.instance
            .collection('users')
            .doc(u.uid)
            .get())
        .data();
    if (md != null) {
      username = (md['username'] as String?)?.trim().isNotEmpty == true
          ? md['username'] as String
          : widget.userName;
      photoUrl = (md['photoUrl'] as String?) ?? photoUrl;
    }

    await _public.doc(postId).collection('replies').add({
      'uid': u.uid,
      'username': username,
      'photoUrl': photoUrl,
      'content': t,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _blockUser(String otherUid) async {
    final u = _user;
    if (u == null) return;
    await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
      'blocked_uids': FieldValue.arrayUnion([otherUid])
    }, SetOptions(merge: true));
    await _loadBlocked();
  }

  Future<void> _deletePost(String postId) async {
    await _public.doc(postId).delete();
  }

  // ---------------- Private actions ----------------
  Future<void> _savePrivate() async {
    final u = _user;
    if (u == null) return;
    final title = _privTitleCtl.text.trim();
    final body = _privContentCtl.text.trim();
    if (title.isEmpty || body.isEmpty) return;

    await _privateCol(u.uid).add({
      'title': title,
      'content': body,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _privTitleCtl.clear();
    _privContentCtl.clear();
  }

  // ---------------- UI ----------------
  LinearGradient _bg(bool isDark) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
            : const [_lavender, _frost, _aqua, _mint],
        stops: const [0.0, 0.45, 0.75, 1.0],
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final u = _user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => home_page.HomePage(userName: widget.userName),
            ),
          ),
        ),
        centerTitle: true,
        title: Icon(Icons.bolt, color: _teal.withOpacity(.9)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              _searchCtl.clear();
              await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Search'),
                  content: TextField(
                    controller: _searchCtl,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Keywords'),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close')),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: _bg(isDark)),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              // centered segmented pills
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
              const SizedBox(height: 10),
              Expanded(
                child: _seg == 0
                    ? _CommunityFeed(
                        user: u,
                        homeDisplayName: widget.userName,
                        blocked: _blocked,
                        publicCol: _public,
                        onReact: _reactOnce,
                        onReply: _reply,
                        onDelete: _deletePost,
                        onBlock: _blockUser,
                        openReplyFor: _openReplyFor,
                        setOpenReplyFor: (id) {
                          setState(() => _openReplyFor = id == _openReplyFor ? null : id);
                        },
                        replyCtlFor: (id) =>
                            _replyCtls.putIfAbsent(id, () => TextEditingController()),
                        fmtFull: _fmtFull,
                        relative: _relative,
                      )
                    : _PrivateJournal(
                        uid: u?.uid,
                        col: u == null ? null : _privateCol(u.uid),
                        titleCtl: _privTitleCtl,
                        contentCtl: _privContentCtl,
                        onSave: _savePrivate,
                        fmtFull: _fmtFull,
                      ),
              ),
              if (_seg == 0) _publicComposer() else const SizedBox(height: 8),
              _BottomNavTransparent(
                selectedIndex: 1,
                onHome: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => home_page.HomePage(userName: widget.userName),
                  ),
                ),
                onJournal: () {},
                onSettings: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(userName: widget.userName),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // community composer (post box)
  Widget _publicComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pubCtl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _postPublic(),
                decoration: const InputDecoration(
                  hintText: 'Write something…',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
}

// ---------------- Community Feed ----------------

class _CommunityFeed extends StatelessWidget {
  const _CommunityFeed({
    required this.user,
    required this.homeDisplayName,
    required this.blocked,
    required this.publicCol,
    required this.onReact,
    required this.onReply,
    required this.onDelete,
    required this.onBlock,
    required this.openReplyFor,
    required this.setOpenReplyFor,
    required this.replyCtlFor,
    required this.fmtFull,
    required this.relative,
  });

  final User? user;
  final String homeDisplayName; // the same "Hello, ..." name from Home
  final Set<String> blocked;
  final CollectionReference<Map<String, dynamic>> publicCol;
  final Future<void> Function(String postId, String emoji) onReact;
  final Future<void> Function(String postId, String text) onReply;
  final Future<void> Function(String postId) onDelete;
  final Future<void> Function(String otherUid) onBlock;

  final String? openReplyFor;
  final void Function(String? id) setOpenReplyFor;
  final TextEditingController Function(String postId) replyCtlFor;

  final String Function(DateTime) fmtFull;
  final String Function(DateTime) relative;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: publicCol.orderBy('createdAt', descending: true).limit(200).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final docs = (snap.data?.docs ?? [])
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
            final ts = (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final postUid = (m['uid'] as String?) ?? '';
            final me = user?.uid == postUid;
            final savedName = (m['username'] as String?)?.trim() ?? '';

            final Widget nameWidget = savedName.isNotEmpty
                ? Text(savedName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16))
                : _UsernameFromUsers(
                    uid: postUid,
                    fallback: me ? homeDisplayName : 'User',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  );

            return _Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // header
                    Row(
                      children: [
                        _Avatar(photoUrl: m['photoUrl'] as String?),
                        const SizedBox(width: 8),
                        Expanded(child: nameWidget),
                        Text(fmtFull(ts),
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(width: 6),
                        _PostMenu(
                          canDelete: me,
                          onDelete: () => onDelete(doc.id),
                          onBlock: () => onBlock(postUid),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // content with "show more"
                    _ExpandableText(text: (m['content'] as String?) ?? ''),
                    const SizedBox(height: 12),

                    // reactions + replies toggle with count
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: (user == null)
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
                              onTap: user == null
                                  ? null
                                  : () => onReact(doc.id, '❤️'),
                            ),
                            const SizedBox(width: 8),
                            _EmojiSelectable(
                              emoji: '👍',
                              count: (m['reactions']?['👍'] ?? 0) as int,
                              selected: myEmoji == '👍',
                              onTap: user == null
                                  ? null
                                  : () => onReact(doc.id, '👍'),
                            ),
                            const SizedBox(width: 8),
                            _EmojiSelectable(
                              emoji: '🥲',
                              count: (m['reactions']?['🥲'] ?? 0) as int,
                              selected: myEmoji == '🥲',
                              onTap: user == null
                                  ? null
                                  : () => onReact(doc.id, '🥲'),
                            ),
                            const Spacer(),
                            _RepliesToggle(
                              col: publicCol,
                              postId: doc.id,
                              open: openReplyFor == doc.id,
                              onPressed: () => setOpenReplyFor(
                                  openReplyFor == doc.id ? null : doc.id),
                            ),
                          ],
                        );
                      },
                    ),

                    // replies (thread + composer) ONLY when toggled open
                    if (openReplyFor == doc.id) ...[
                      _ReplyThread(
                        postId: doc.id,
                        public: publicCol,
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
    required this.titleCtl,
    required this.contentCtl,
    required this.onSave,
    required this.fmtFull,
  });

  final String? uid;
  final CollectionReference<Map<String, dynamic>>? col;
  final TextEditingController titleCtl;
  final TextEditingController contentCtl;
  final Future<void> Function() onSave;
  final String Function(DateTime) fmtFull;

  @override
  Widget build(BuildContext context) {
    if (uid == null || col == null) {
      return const Center(child: Text('Sign in to view your private entries.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: col!
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        final list = snap.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
          children: [
            // composer card
            _Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: titleCtl,
                      decoration: const InputDecoration(
                        labelText: 'Entry Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentCtl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Write a private entry…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: onSave,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...list.map((d) {
              final m = d.data();
              final ts =
                  (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              return _Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(
                    (m['title'] as String?) ?? 'Untitled',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text((m['content'] as String?) ?? ''),
                      const SizedBox(height: 6),
                      Text(fmtFull(ts),
                          style:
                              TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
}

// ---------------- Small widgets ----------------

class _SegPill extends StatelessWidget {
  const _SegPill(
      {required this.label, required this.active, required this.onTap, this.alt = false});
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool alt;

  @override
  Widget build(BuildContext context) {
    final bg = active ? (alt ? const Color(0xFF69A79D) : Colors.white) : Colors.white70;
    final fg = active ? (alt ? Colors.white : Colors.black) : Colors.black87;
    final underline = active ? _teal : Colors.transparent;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: fg, fontWeight: FontWeight.w700, letterSpacing: .2)),
            const SizedBox(height: 4),
            Container(
              height: 3,
              width: 130,
              decoration: BoxDecoration(
                color: underline,
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.photoUrl});
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    const radius = 18.0;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(photoUrl!));
    }
    return const CircleAvatar(
      radius: radius,
      backgroundColor: Color(0xFFD7CFFC),
      child: Icon(Icons.person, color: Colors.black54),
    );
  }
}

class _PostMenu extends StatelessWidget {
  const _PostMenu({required this.canDelete, required this.onDelete, required this.onBlock});
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      onSelected: (v) {
        if (v == 'delete') onDelete();
        if (v == 'block') onBlock();
      },
      itemBuilder: (c) => [
        if (canDelete)
          const PopupMenuItem(value: 'delete', child: Text('Delete post')),
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
            Text('$count',
                style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: color)),
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
              textInputAction: TextInputAction.send,
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
  const _ReplyThread(
      {required this.postId, required this.public, this.limit = 25});
  final String postId;
  final CollectionReference<Map<String, dynamic>> public;
  final int limit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: public
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
            children: replies.map((r) {
              final m = r.data();
              final ts =
                  (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final name = (m['username'] as String?) ?? 'User';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(photoUrl: m['photoUrl'] as String?),
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
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM d, yyyy • hh:mm a').format(ts),
                                  style: TextStyle(
                                      color: Colors.grey.shade600, fontSize: 11),
                                ),
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
    final visible = long && !_expanded
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
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6))
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
  const _EmptyHint({required this.icon, required this.title, required this.subtitle});

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
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
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
  const _RoundIcon({required this.icon, required this.onTap, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: fg)),
      ),
    );
  }
}

/// Transparent bottom nav (like other pages)
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
          IconButton(icon: Icon(Icons.home_filled, color: _c(0)), onPressed: onHome),
          IconButton(icon: Icon(Icons.menu_book_rounded, color: _c(1)), onPressed: onJournal),
          IconButton(icon: Icon(Icons.settings, color: _c(2)), onPressed: onSettings),
        ],
      ),
    );
  }
}

/// Displays a username by fetching /users/{uid}.username if not provided.
class _UsernameFromUsers extends StatelessWidget {
  const _UsernameFromUsers({
    required this.uid,
    required this.fallback,
    required this.style,
  });

  final String uid;
  final String fallback;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return Text(fallback, style: style);
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (_, snap) {
        final data = snap.data?.data();
        final name = (data?['username'] as String?)?.trim();
        return Text(
          (name != null && name.isNotEmpty) ? name : fallback,
          style: style,
        );
      },
    );
  }
}*/

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:new_rezonate/pages/home.dart' as home_page;
import 'package:new_rezonate/main.dart' as app;
import 'package:new_rezonate/pages/settings.dart';
import 'package:new_rezonate/pages/services/user_settings.dart' as app_settings;

// ---------------- Colors / gradient ----------------
const _lavender = Color(0xFFD9CEF8);
const _frost = Color(0xFFCFE1E8);
const _aqua = Color(0xFFC5E7DD);
const _mint = Color(0xFFBFEBD1);
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

  User? get _user => FirebaseAuth.instance.currentUser;
  CollectionReference<Map<String, dynamic>> get _public =>
      FirebaseFirestore.instance.collection('public_posts');
  CollectionReference<Map<String, dynamic>> _privateCol(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private_posts');

  Set<String> _blocked = {};

  @override
  void initState() {
    super.initState();
    _loadBlocked();
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
    });

    _pubCtl.clear();
  }

  Future<void> _reactOnce(String postId, String emoji) async {
    final u = _user;
    if (u == null) return;

    final postRef = _public.doc(postId);
    final myReactRef = postRef.collection('reactions').doc(u.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final mySnap = await tx.get(myReactRef);

      if (!mySnap.exists) {
        tx.set(myReactRef, {
          'emoji': emoji,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {'reactions.$emoji': FieldValue.increment(1)});
        return;
      }

      final prev = (mySnap.data() as Map<String, dynamic>)['emoji'] as String?;

      if (prev == emoji) {
        tx.update(postRef, {'reactions.$emoji': FieldValue.increment(-1)});
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

    await _public.doc(postId).collection('replies').add({
      'uid': u.uid,
      'username': safeUsername,
      'isAnonymous': anon,
      'photoUrl': photoUrl,
      'content': t,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Prevent self-blocking: ignore if [otherUid] is empty or matches current user.
  Future<void> _blockUser(String otherUid) async {
    final u = _user;
    if (u == null) return;
    if (otherUid.isEmpty || otherUid == u.uid) return; // <- guard
    await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
      'blocked_uids': FieldValue.arrayUnion([otherUid]),
    }, SetOptions(merge: true));
    await _loadBlocked();
  }

  Future<void> _deletePost(String postId) async {
    await _public.doc(postId).delete();
  }

  // ---------------- Private actions ----------------
  Future<void> _savePrivate() async {
    final u = _user;
    if (u == null) return;
    final title = _privTitleCtl.text.trim();
    final body = _privContentCtl.text.trim();
    if (title.isEmpty || body.isEmpty) return;

    await _privateCol(u.uid).add({
      'title': title,
      'content': body,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _privTitleCtl.clear();
    _privContentCtl.clear();
  }

  // ---------------- UI ----------------
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final u = _user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Icon(Icons.bolt, color: _teal.withOpacity(.9)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              _searchCtl.clear();
              await showDialog(
                context: context,
                builder:
                    (_) => AlertDialog(
                      title: const Text('Search'),
                      content: TextField(
                        controller: _searchCtl,
                        autofocus: true,
                        decoration: const InputDecoration(hintText: 'Keywords'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: _bg(context)),
        child: SafeArea(
          child: Column(
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
              const SizedBox(height: 10),
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
                        )
                        : _PrivateJournal(
                          uid: u?.uid,
                          col: u == null ? null : _privateCol(u.uid),
                          titleCtl: _privTitleCtl,
                          contentCtl: _privContentCtl,
                          onSave: _savePrivate,
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
                        builder:
                            (_) =>
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
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _postPublic(),
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
    required this.onBlock,
    required this.openReplyFor,
    required this.setOpenReplyFor,
    required this.replyCtlFor,
    required this.fmtFull,
    required this.relative,
  });

  final User? user;
  final Set<String> blocked;
  final CollectionReference<Map<String, dynamic>> publicCol;
  final Future<void> Function(String postId, String emoji) onReact;
  final Future<void> Function(String postId, String text) onReply;
  final Future<void> Function(String postId) onDelete;
  final Future<void> Function(String otherUid) onBlock;

  final String? openReplyFor;
  final void Function(String? id) setOpenReplyFor;
  final TextEditingController Function(String postId) replyCtlFor;

  final String Function(DateTime) fmtFull;
  final String Function(DateTime) relative;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          publicCol
              .orderBy('createdAt', descending: true)
              .limit(200)
              .snapshots(),
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

            final canDelete = user?.uid == postUid;
            final canBlock =
                postUid.isNotEmpty && user?.uid != postUid; // <- only others

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
                          canDelete: canDelete,
                          canBlock: canBlock, // <- new flag
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
                      _ReplyThread(postId: doc.id, public: publicCol),
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
    required this.titleCtl,
    required this.contentCtl,
    required this.onSave,
    required this.fmtFull,
  });

  final String? uid;
  final CollectionReference<Map<String, dynamic>>? col;
  final TextEditingController titleCtl;
  final TextEditingController contentCtl;
  final Future<void> Function() onSave;
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
          children: [
            _Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: titleCtl,
                      decoration: const InputDecoration(
                        labelText: 'Entry Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentCtl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Write a private entry…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: onSave,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...list.map((d) {
              final m = d.data();
              final ts =
                  (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              return _Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(
                    (m['title'] as String?) ?? 'Untitled',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text((m['content'] as String?) ?? ''),
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
                ),
              );
            }),
          ],
        );
      },
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 0),
            Container(
              height: 3,
              width: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ],
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
    required this.canDelete,
    required this.canBlock,
    required this.onDelete,
    required this.onBlock,
  });
  final bool canDelete;
  final bool canBlock;
  final VoidCallback onDelete;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      onSelected: (v) {
        if (v == 'delete') onDelete();
        if (v == 'block') onBlock();
      },
      itemBuilder:
          (c) => [
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
              textInputAction: TextInputAction.send,
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
  });
  final String postId;
  final CollectionReference<Map<String, dynamic>> public;
  final int limit;

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
                                      DateFormat(
                                        'MMM d, yyyy • hh:mm a',
                                      ).format(ts),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                    ),
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
