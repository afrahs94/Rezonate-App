import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_rezonate/pages/services/user_settings.dart';

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

class JournalPage extends StatefulWidget {
  final String userName;
  const JournalPage({Key? key, required this.userName}) : super(key: key);

  @override
  _JournalPageState createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final _controller = TextEditingController();
  final _posts = <PublicPost>[];

  void _addPost() {
    final txt = _controller.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _posts.insert(
        0,
        PublicPost(
          username: widget.userName,
          content: txt,
          timestamp: DateTime.now(),
        ),
      );
      _controller.clear();
    });
  }

  String _format(DateTime dt) => DateFormat('MMM d, yyyy • HH:mm').format(dt);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _posts.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (_, i) {
                final p = _posts[i];
                final display =
                    UserSettings.anonymous ? 'Anonymous' : p.username;
                return ListTile(
                  leading: CircleAvatar(child: Text(display[0].toUpperCase())),
                  title: Text(p.content),
                  subtitle: Text('$display • ${_format(p.timestamp)}'),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Write a public post...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _addPost),
            ]),
          ),
        ],
      ),
    );
  }
}
