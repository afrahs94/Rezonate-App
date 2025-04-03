import 'package:flutter/material.dart';
import 'settings.dart';
import 'messages.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1;

  String getFormattedDate() {
    return DateTime.now().toLocal().toString().split(' ')[0];
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MessagesPage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingsPage(
            firstName: 'First',
            lastName: 'Last',
            username: 'username',
            email: 'email@example.com',
            password: 'password',
            phone: '123-456-7890',
            birthday: '01/01/1990',
          ),
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = const Color(0xFFEAF4FF);
    final Color lightBlue = const Color(0xFFD7EAFE);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                color: lightBlue,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "hi, name!",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              getFormattedDate(),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.person_outline, color: Colors.blue[100], size: 30),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      onChanged: (value) {
                        // Implement app-wide search logic
                      },
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search, color: Colors.blue[200]),
                        hintText: 'search rezonate',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: lightBlue,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    const Text(
                      "how do you feel?",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildEmojiOption(Icons.tag_faces, "great"),
                        _buildEmojiOption(Icons.sentiment_neutral, "eh..."),
                        _buildEmojiOption(Icons.sentiment_very_dissatisfied, "not so great"),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    _buildMenuButton("chat"),
                    _buildMenuButton("journal"),
                    _buildMenuButton("track"),
                    _buildMenuButton("resources"),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
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

  Widget _buildEmojiOption(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 40, color: Colors.white),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _buildMenuButton(String label) {
    return GestureDetector(
      onTap: () {
        if (label == 'chat') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MessagesPage()),
          );
        }
      },
      child: Container(
        width: 140,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue[300],
            ),
          ),
        ),
      ),
    );
  }
}
