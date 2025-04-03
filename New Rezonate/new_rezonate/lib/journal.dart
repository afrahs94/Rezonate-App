import 'package:flutter/material.dart';
import 'homepage.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final List<Map<String, String>> messages = [
    {'name': 'Bob Sanders', 'message': 'hi!', 'time': 'now'},
    {'name': 'Afrah Shailkh', 'message': 'how are you?', 'time': '3 min ago'},
    {'name': 'Jada Yudom', 'message': 'want to meet for lunch?', 'time': '1 hour ago'},
    {'name': 'Smirthi Gunasekaran', 'message': 'wydddd', 'time': '1 day ago'},
    {'name': 'Sania Ahmad', 'message': 'my little pony rocks', 'time': '1 wk ago'},
    {'name': 'Molly Clark', 'message': 'please do not contact me', 'time': '1 wk ago'},
  ];

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    }
  }

  void _showUserOptions(String username) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Actions for $username', style: const TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block User'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report User'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD7EAFE),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          },
        ),
        title: const Text('Messages'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('messages', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black)),
                Text('you have 2 new messages', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: messages.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final msg = messages[index];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.yellow,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(msg['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(msg['message']!),
                  trailing: Text(msg['time']!, style: const TextStyle(color: Colors.grey)),
                  onLongPress: () => _showUserOptions(msg['name']!),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'messages'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'settings'),
        ],
      ),
    );
  }
}