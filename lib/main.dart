import 'package:flutter/material.dart';
import 'pages/signup_page.dart'; // Make sure this file exists in /lib

void main() {
  runApp(const RezonateApp());
}

class RezonateApp extends StatelessWidget {
  const RezonateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rezonate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.white,
        scaffoldBackgroundColor: const Color(0xFFCCCCFF), // periwinkle blue
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Colors.white),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF99BBFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      home: const SignUpPage(), // ← Correct class name
    );
  }
}
