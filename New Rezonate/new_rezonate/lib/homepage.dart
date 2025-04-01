import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1;
  String getFormattedDate() {
    return DateFormat('EEEE, MMMM d').format(DateTime.now());
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Add navigation logic here
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = Color(0xFFBBDEFB);
    final Color lightBlue = Color(0xFFBBDEFB);
    final TextStyle labelStyle = TextStyle(color: Colors.blue[200], fontSize: 20, fontWeight: FontWeight.bold);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                color: lightBlue,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 70),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("hi, name!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: Colors.grey[700])),
                            Text(getFormattedDate(), style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                          ],
                        ),
                        Icon(Icons.person_outline, color: const Color(0xFFBBDEFB), size: 30),
                      ],
                    ),
                    SizedBox(height: 30),
                    TextField(
                      onChanged: (value) {
                        // Implement app-wide search logic
                      },
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search, color: const Color.fromARGB(255, 208, 223, 234)),
                        hintText: 'search rezonate',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Container(
                color: lightBlue,
                padding: EdgeInsets.symmetric(vertical: 0),
                child: Column(
                  children: [
                    Text("how do you feel?", style: TextStyle(color: Colors.white, fontSize: 18)),
                    SizedBox(height: 9),
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
              // this is for the spacing between boxes
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30), // to push the grid down
                child: Wrap(
                  spacing: 30, // horizontal row distance
                  runSpacing: 30, //vertical col distance
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
        SizedBox(height: 5),
        Text(label, style: TextStyle(color: Colors.white)),
      ],
    );
  }

// this is for the 4 boxes in the center of the screen
  Widget _buildMenuButton(String label) {
    return Container(
      width: 160,
      height: 100,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(child: Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[300]))),
    );
  }
}
