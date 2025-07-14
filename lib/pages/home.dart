// home.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_rezonate/pages/mood_tracker_page.dart';
import 'package:new_rezonate/pages/habit_tracker_page.dart';
import 'package:new_rezonate/pages/sleep_tracker_page.dart';

class HomePage extends StatefulWidget {
  final String userName;

  const HomePage({super.key, required this.userName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> trackerTitles = ['Mood', 'Habit', 'Sleep'];

  final String today = DateFormat('EEEE, MMMM d').format(DateTime.now());

  void _editTrackerName(int index) async {
    final controller = TextEditingController(text: trackerTitles[index]);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename or Delete Tracker'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new tracker name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                trackerTitles.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      setState(() => trackerTitles[index] = name.trim());
    }
  }

  void _openTracker(int index) {
    String title = trackerTitles[index].toLowerCase();

    if (title == 'mood') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodTrackerPage()));
    } else if (title == 'habit') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HabitTrackerPage()));
    } else if (title == 'sleep') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepTrackerPage()));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(trackerTitles[index])),
            body: Center(child: Text('Welcome to ${trackerTitles[index]} tracker!')),
          ),
        ),
      );
    }
  }

  void _addTracker() async {
    final controller = TextEditingController();
    final newTracker = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create New Tracker'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter tracker name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (newTracker != null && newTracker.trim().isNotEmpty) {
      setState(() => trackerTitles.add(newTracker.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF99BBFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.settings),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            color: const Color(0xFFCCCCFF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.flash_on, size: 40, color: Colors.white),
                const SizedBox(height: 10),
                Text('hi, ${widget.userName}!',
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
                children: [
                  ...List.generate(trackerTitles.length, (index) => _buildTracker(index)),
                  GestureDetector(
                    onTap: _addTracker,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCCCFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(Icons.add, size: 36, color: Color(0xFF99BBFF)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracker(int index) {
    return GestureDetector(
      onTap: () => _openTracker(index),
      onLongPress: () => _editTrackerName(index),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFCCCCFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            trackerTitles[index],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Color(0xFF99BBFF),
            ),
          ),
        ),
      ),
    );
  }
}