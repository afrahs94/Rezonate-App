// lib/pages/journal_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_rezonate/pages/home.dart' as home_page;
import 'package:new_rezonate/pages/settings_page.dart';

class PublicPost {
  final String username;
  final String content;
  final DateTime timestamp;
  PublicPost({required this.username, required this.content, required this.timestamp});
}

class PrivatePost {
  final String title;
  final String content;
  final DateTime timestamp;
  PrivatePost({required this.title, required this.content, required this.timestamp});
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
                timestamp: DateTime.now()));
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
                timestamp: DateTime.now()));
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
          title: const Text('Journal'),
          centerTitle: true,
          bottom: const TabBar(tabs: [Tab(text: 'Public'), Tab(text: 'Private')]),
        ),
        body: TabBarView(children: [
          // Public
          Column(children: [
            Expanded(
              child: ListView.builder(
                itemCount: _publicPosts.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (c, i) {
                  final p = _publicPosts[i];
                  final mine = p.username == widget.userName;
                  return ListTile(
                    leading: CircleAvatar(child: Text(p.username[0].toUpperCase())),
                    title: Text(p.content, style: const TextStyle(fontSize: 16)),
                    subtitle: Text('${p.username} • ${_fmt(p.timestamp)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                IconButton(icon: const Icon(Icons.send), color: Theme.of(context).primaryColor, onPressed: _postPublic),
              ]),
            ),
          ]),

          // Private
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
                  child: IconButton(icon: const Icon(Icons.send), color: Theme.of(context).primaryColor, onPressed: _postPrivate),
                ),
              ]),
            ),
          ]),
        ]),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _NavItem(icon: Icons.home, isSelected: false, onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => home_page.HomePage(userName: widget.userName)),
              );
            }),
            _NavItem(icon: Icons.public, isSelected: true, onTap: () {}),
            _NavItem(icon: Icons.settings, isSelected: false, onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => SettingsPage(userName: widget.userName)),
              );
            }),
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
