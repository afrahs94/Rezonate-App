import 'package:flutter/material.dart';
import 'package:new_rezonate/homepage.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9FBFD),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Logo & Title
                Column(
                  children: [
                    Image.asset(
                      'assets/logo.png', // Replace with your asset path
                      height: 60,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'rezonate',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w300,
                        color: Colors.grey[700],
                        letterSpacing: 1,
                      ),
                    ),
                    const Text(
                      'YOUR STORY MATTERS.',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'connecting, journaling, and\ntracking your mind',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 50),

                // Group Icon
                Icon(
                  Icons.groups_rounded,
                  size: 100,
                  color: Colors.blue[100],
                ),

                const SizedBox(height: 50),

                // Get Started Button → HomePage
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue[100],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'get started',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                  ),
                ),

                const SizedBox(height: 20),

                // Log In text → HomePage
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('have an account? ', style: TextStyle(color: Colors.grey)),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => HomePage()),
                        );
                      },
                      child: const Text(
                        'log in',
                        style: TextStyle(
                          color: Colors.grey,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
