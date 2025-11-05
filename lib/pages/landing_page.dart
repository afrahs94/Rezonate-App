// lib/pages/landing_page.dart
import 'dart:math' show pi, sin;
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10), // Faster than before
      vsync: this,
    )..repeat(); // Smooth infinite loop
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _getColors(bool dark) {
    return dark
        ? const [Color(0xFF2A2336), Color(0xFF3E8F84), Color(0xFF1A2E33)]
        : const [Color(0xFFF9F9F9), Color(0xFFD7C3F1), Color(0xFFB3E5DC)];
  }

  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    final colors = _getColors(dark);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * pi;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0.0 + 0.025 * sin(t), -1.0 + 0.02 * sin(t * 1.3)),
                end: Alignment(0.0 - 0.025 * sin(t * 1.2), 1.0 - 0.02 * sin(t)),
                colors: colors,
              ),
            ),
            child: Stack(
              children: [
                // Soft moving overlay
                Opacity(
                  opacity: 0.08,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(0.5 + 0.02 * sin(t * 1.5), -0.3),
                        end: Alignment(-0.3, 0.5 + 0.02 * sin(t * 1.7)),
                        colors: dark
                            ? const [Color(0xFF5A4F75), Color(0xFF407D78)]
                            : const [Color(0xFFF3EDF8), Color(0xFFB0EAE2)],
                      ),
                    ),
                  ),
                ),

                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/Full_logo.png',
                    width: MediaQuery.of(context).size.width * 0.85,
                    fit: BoxFit.contain,
                  ),
                ),

                // Bottom buttons
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
                              elevation: 4,
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
                              elevation: 4,
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
          );
        },
      ),
    );
  }
}
