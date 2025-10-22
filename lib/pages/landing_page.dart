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
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _bgController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late bool _showLogo;

  @override
  void initState() {
    super.initState();
    _showLogo = false;

    // Main fade/scale animation controller
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnim = CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeInOut,
    );

    _scaleAnim = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutBack),
    );

    _mainController.forward();

    // Background gradient shimmer controller
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    // Switch from Welcome → Logo
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _showLogo = true;
      });
      _mainController
        ..reset()
        ..forward();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  BoxDecoration _animatedBg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    final animationValue = _bgController.value;

    final List<Color> lightColors = [
      Color.lerp(const Color(0xFFFFFFFF), const Color(0xFFD7C3F1), animationValue)!,
      Color.lerp(const Color(0xFFD7C3F1), const Color(0xFF41B3A2), 1 - animationValue)!,
    ];

    final List<Color> darkColors = [
      Color.lerp(const Color(0xFFBDA9DB), const Color(0xFF3E8F84), animationValue)!,
      Color.lerp(const Color(0xFF3E8F84), const Color(0xFFBDA9DB), 1 - animationValue)!,
    ];

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark ? darkColors : lightColors,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: _animatedBg(context),
            width: double.infinity,
            child: SafeArea(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: AnimatedSwitcher(
                        duration: const Duration(seconds: 1),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.95, end: 1.0)
                                  .animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _showLogo
                            ? Image.asset(
                                'assets/images/Full_logo.png',
                                key: const ValueKey('logo'),
                                fit: BoxFit.contain,
                                width:
                                    MediaQuery.of(context).size.width * 0.85,
                              )
                            : Text(
                                'Welcome',
                                key: const ValueKey('welcome'),
                                style: TextStyle(
                                  fontFamily: 'Poppins', // Match your logo font here
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.97),
                                  letterSpacing: 1.8,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(2, 3),
                                      blurRadius: 6,
                                      color: Colors.black.withOpacity(0.3),
                                    ),
                                  ],
                                ),
                              ),
                      ),
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
                                  MaterialPageRoute(
                                      builder: (_) => const LoginPage()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
                                  MaterialPageRoute(
                                      builder: (_) => const SignUpPage()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.9),
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
            ),
          );
        },
      ),
    );
  }
}
