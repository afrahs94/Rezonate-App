// home_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  final String userName;

  const HomePage({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    final String today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.settings, color: Color(0xFF99BBFF)),
            label: 'settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: Colors.transparent),
            label: '',
          ),
        ],
        selectedLabelStyle: const TextStyle(color: Color(0xFF99BBFF)),
        showUnselectedLabels: true,
        currentIndex: 0,
        onTap: (_) {},
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            color: const Color(0xFFCCCCFF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(Icons.person_outline, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                const Icon(Icons.flash_on, size: 40, color: Colors.white),
                const SizedBox(height: 10),
                Text('hi, $userName!',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: Colors.grey)),
                Text(today, style: const TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                children: List.generate(4, (index) => _buildTracker(index + 1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracker(int number) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFCCCCFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          'tracker #$number',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: Color(0xFF99BBFF),
          ),
        ),
      ),
    );
  }
}