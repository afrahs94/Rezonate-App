// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'pages/signup_page.dart';
import 'pages/login_page.dart';
import 'pages/home.dart';
import 'pages/user_sessions.dart';
import 'pages/services/user_settings.dart';

// NEW
import 'pages/onboarding.dart';
import 'pages/onboarding_keys';

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
const String _kChannelId = 'rezonate_default';
const String _kChannelName = 'General';
const String _kChannelDesc = 'General notifications';

@pragma('vm:entry-point') // required by Android background isolate
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Keep minimal work here.
}

Future<void> _initLocalNotifs() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();

  await _fln.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (resp) {

    },
  );

  await _fln
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _kChannelId,
          _kChannelName,
          description: _kChannelDesc,
          importance: Importance.high,
        ),
      );
}

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
    _persistDark();
    notifyListeners();
  }

  void setDark(bool value) {
    if (_isDark == value) return;
    _isDark = value;
    _persistDark();
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


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _initLocalNotifs();

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e) {
    debugPrint(' Firebase init error: $e');
  }

  await UserSettings.init();
  await UserSession.instance.init();

  // Load cached onboarding stage early (helps if offline)
  await Onboarding.loadCacheIfEmpty();

  // Load persisted dark-mode preference (defaults to false)
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

class RezonateApp extends StatefulWidget {
  final ThemeController controller;
  const RezonateApp({super.key, required this.controller});

  @override
  State<RezonateApp> createState() => _RezonateAppState();
}

class _RezonateAppState extends State<RezonateApp> {
  static final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  late final Stream<User?> _authStream;

@override
void initState() {
  super.initState();

  // Foreground push → show local notification
  FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
    final notification = msg.notification;
    if (notification != null) {
      await _fln.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            channelDescription: _kChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: msg.data['postId'] ?? '',
      );
    }
  });

  // Handle when app is opened from a terminated state via notification
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) _handleOpenedMessage(message);
  });

  // Handle when app is opened from background via notification
  FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

  // Onboarding stage setup when user signs in
  _authStream = FirebaseAuth.instance.authStateChanges();
  _authStream.listen((user) {
    if (user != null) {
      Onboarding.ensureStageForCurrentUser();
    }
  });
}


  void _handleOpenedMessage(RemoteMessage msg) {
    final type = msg.data['type'] ?? '';
    final postId = msg.data['postId'];
  }

  Future<Widget> _getStartPage() async {
  final prefs = await SharedPreferences.getInstance();
  final remember = prefs.getBool('remember_me') ?? false;
  final user = FirebaseAuth.instance.currentUser;

  if (remember && user != null) {
    return HomePage(userName: user.displayName ?? user.email!.split('@').first);
  } else {
    return const LoginPage();
  }
}


  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navKey,
          title: 'Rezonate',
          debugShowCheckedModeBanner: false,
          themeMode: widget.controller.isDark ? ThemeMode.dark : ThemeMode.light,
          theme: _lightTheme,
          darkTheme: _darkTheme,

          builder: (context, child) {
            return ShowCaseWidget(
              builder: (showcaseCtx) => child ?? const SizedBox.shrink(),
            );
          },

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
  scaffoldBackgroundColor: Colors.transparent,
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
  scaffoldBackgroundColor: Colors.transparent,
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
    fillColor: Colors.white24,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    hintStyle: const TextStyle(color: Colors.white70),
  ),
);
