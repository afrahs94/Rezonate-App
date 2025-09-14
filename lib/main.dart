// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'pages/signup_page.dart';
import 'pages/login_page.dart';
import 'pages/home.dart';
import 'pages/user_sessions.dart';
import 'pages/services/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple theme controller + scope ------------------------------------------------

class ThemeController extends ChangeNotifier {
  ThemeController({bool isDark = false}) : _isDark = isDark;

  bool _isDark;
  bool get isDark => _isDark;

  Future<void> _persistDark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDark);
  }

  void toggleTheme() {
    _isDark = !_isDark;
    // fire-and-forget persistence
    _persistDark();
    notifyListeners();
  }

  void setDark(bool value) {
    if (_isDark == value) return;
    _isDark = value;
    _persistDark(); // fire-and-forget persistence
    notifyListeners();
  }
}

class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static ThemeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeControllerScope>();
    assert(scope != null, 'ThemeControllerScope not found in widget tree.');
    return scope!.notifier!;
  }
}

/// -------------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase Initialized!');
  } catch (e) {
    print('❌ Firebase Init Error: $e');
  }

  await UserSettings.init();
  await UserSession.instance.init();

  // ⚫️ Load persisted dark-mode preference (defaults to false)
  final prefs = await SharedPreferences.getInstance();
  final savedDark = prefs.getBool('is_dark_mode') ?? false;

  final controller = ThemeController(isDark: savedDark);

  runApp(
    ThemeControllerScope(
      controller: controller,
      child: RezonateApp(controller: controller),
    ),
  );
}

class RezonateApp extends StatelessWidget {
  final ThemeController controller;
  const RezonateApp({super.key, required this.controller});

  Future<Widget> _getStartPage() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    final user = FirebaseAuth.instance.currentUser;

    if (remember && user != null) {
      // ✅ Go straight to Home if remembered + logged in
      return HomePage(
        userName: user.displayName ?? user.email!.split('@').first,
      );
    } else {
      // ✅ Otherwise show Login
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Rezonate',
          debugShowCheckedModeBanner: false,
          themeMode: controller.isDark ? ThemeMode.dark : ThemeMode.light,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          home: FutureBuilder<Widget>(
            future: _getStartPage(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return snapshot.data ?? const SignUpPage();
            },
          ),
        );
      },
    );
  }
}

/// ------------------------------ THEMES ----------------------------------------

final ThemeData _lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF0D7C66),
  scaffoldBackgroundColor:
      Colors.transparent, // most pages draw their own gradient
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0D7C66),
    brightness: Brightness.light,
  ),
  textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.black87)),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.black87,
    centerTitle: true,
  ),
  iconTheme: const IconThemeData(color: Colors.black87),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF0D7C66),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      minimumSize: const Size(48, 48),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    hintStyle: const TextStyle(color: Colors.black38),
  ),
);

final ThemeData _darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF0D7C66),
  scaffoldBackgroundColor: Colors.transparent, // pages keep using gradients
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0D7C66),
    brightness: Brightness.dark,
  ),
  textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    centerTitle: true,
  ),
  iconTheme: const IconThemeData(color: Colors.white),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF0D7C66),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      minimumSize: const Size(48, 48),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withOpacity(0.08),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    hintStyle: const TextStyle(color: Colors.white70),
  ),
);
