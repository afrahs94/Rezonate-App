// lib/pages/landing_page.dart
import 'package:flutter/material.dart';
import 'package:new_rezonate/main.dart' as app;
import 'package:new_rezonate/pages/login_page.dart';
import 'package:new_rezonate/pages/signup_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    // Create a controller for the swirl animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Create a smooth swirl (rotation + scale-in)
    _rotation = Tween<double>(begin: -0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // Start the animation when the page loads
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  BoxDecoration _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)] // dark gradient
            : const [
                Color(0xFFFFFFFF),
                Color(0xFFD7C3F1),
                Color(0xFF41B3A2),
              ], // app-wide gradient
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _bg(context),
        width: double.infinity,
        child: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Animated swirling logo
              Align(
                alignment: const Alignment(0, -0.2),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotation.value,
                      child: Transform.scale(
                        scale: _scale.value,
                        child: child,
                      ),
                    );
                  },
                  child: Image.asset(
                    'assets/images/Full_logo.png',
                    fit: BoxFit.contain,
                    width: MediaQuery.of(context).size.width * 0.85, // larger logo
                  ),
                ),
              ),

              // Buttons at bottom
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const LoginPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const StadiumBorder(),
                            elevation: 3,
                          ),
                          child: const Text(
                            'LOG IN',
                            style: TextStyle(
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SignUpPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.9),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const StadiumBorder(),
                            elevation: 3,
                          ),
                          child: const Text(
                            'SIGN UP',
                            style: TextStyle(
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
