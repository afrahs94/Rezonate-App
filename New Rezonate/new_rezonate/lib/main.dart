import 'package:flutter/material.dart';
// ignore: unused_import
import 'homepage.dart';
import 'landing.dart'; // Import your new landing page
// import 'signup.dart';  // Create this
// import 'login.dart';   // Create this

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rezonate',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingPage(),
        '/signup': (context) =>  MyApp(), // You define this
        '/login': (context) =>  MyApp(),   // You define this
      },
    );
  }
}
