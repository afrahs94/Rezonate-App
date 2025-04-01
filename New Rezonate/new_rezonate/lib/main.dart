import 'package:flutter/material.dart';
import 'package:new_rezonate/homepage.dart';
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
        '/signup': (context) =>  HomePage(), // You define this
        '/login': (context) =>  HomePage(),   // You define this
      },
    );
  }
}
