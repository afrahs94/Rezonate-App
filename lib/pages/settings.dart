// lib/pages/settings.dart
import 'package:flutter/material.dart';
import 'package:new_rezonate/main.dart' as app; // ThemeControllerScope
import 'package:new_rezonate/pages/home.dart';
import 'package:new_rezonate/pages/journal.dart';
import 'package:new_rezonate/pages/edit_profile.dart';
import 'package:new_rezonate/pages/change_password.dart';
import 'package:new_rezonate/pages/security_privacy.dart';
import 'package:new_rezonate/pages/push_notifs.dart';
import 'package:new_rezonate/pages/deactivate.dart';
import 'package:new_rezonate/pages/login_page.dart';

class SettingsPage extends StatefulWidget {
  final String userName;
  const SettingsPage({super.key, required this.userName});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<_Item> _all;
  late List<_Item> _shown;

  @override
  void initState() {
    super.initState();
    _all = [
      _Item(
        label: 'Edit Profile',
        icon: Icons.person_outline,
        keywords: const ['name', 'username', 'email', 'profile'],
        builder: () => EditProfilePage(userName: widget.userName),
      ),
      _Item(
        label: 'Change Password',
        icon: Icons.lock_outline,
        keywords: const ['password', 'security', 'update'],
        builder: () => const ChangePasswordPage(userName: ''),
      ),
      _Item(
        label: 'Security & Privacy',
        icon: Icons.security,
        keywords: const ['privacy', 'encryption', 'anonymous', 'sharing'],
        builder: () => SecurityAndPrivacyPage(userName: widget.userName),
      ),
      _Item(
        label: 'Push Notifications',
        icon: Icons.notifications_active_outlined,
        keywords: const ['push', 'notifications', 'reminders'],
        builder: () => PushNotificationsPage(userName: widget.userName),
      ),
      _Item(
        label: 'Deactivate Account',
        icon: Icons.person_off_outlined,
        keywords: const ['deactivate', 'disable', 'close account'],
        builder: () => DeactivateAccountPage(userName: widget.userName),
      ),
      _Item.darkMode(), // inline “row” handled below
      _Item.logout(), // inline “row” handled below
    ];
    _shown = List.of(_all);
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _shown = List.of(_all));
      return;
    }
    setState(() {
      _shown =
          _all.where((it) {
            if (it.type != _RowType.link) return false;
            if (it.label.toLowerCase().contains(q)) return true;
            return it.keywords.any((k) => k.contains(q));
          }).toList();
    });
  }

  // Simple gradient chooser that doesn’t rely on AppGradients fields
  List<Color> _gradient(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
        : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)];
  }

  @override
  Widget build(BuildContext context) {
    final g = _gradient(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: g,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header + back
              // Header + back
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 29, 0, 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          shadows:
                              Theme.of(context).brightness == Brightness.dark
                                  ? [
                                    const Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 15,
                                      color: Colors.black,
                                    ),
                                  ]
                                  : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 26, 20),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color.fromARGB(57, 210, 210, 210) // dark mode background
                            : const Color.fromARGB(152, 255, 255, 255), // light mode background
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'search',
                          ),
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _onSearch,
                      ),
                    ],
                  ),
                ),
              ),

              // List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  itemCount: _shown.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final it = _shown[i];
                    if (it.type == _RowType.darkMode)
                      return _darkModeRow(context);
                    if (it.type == _RowType.logout) return _logoutRow(context);
                    return _linkRow(context, it);
                  },
                ),
              ),

              // Transparent bottom navigation
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _navIcon(
                      context,
                      icon: Icons.home_rounded,
                      selected: false,
                      onTap:
                          () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => HomePage(userName: widget.userName),
                            ),
                          ),
                    ),
                    _navIcon(
                      context,
                      icon: Icons.menu_book_rounded,
                      selected: false,
                      onTap:
                          () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => JournalPage(userName: widget.userName),
                            ),
                          ),
                    ),
                    _navIcon(
                      context,
                      icon: Icons.settings_rounded,
                      selected: true,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ————————— UI parts —————————

  Widget _linkRow(BuildContext context, _Item it) {
    final bg = Color.fromARGB(131, 0, 150, 135);
    return InkWell(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => it.builder()),
          ),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(it.icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                it.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              height: 30,
              width: 30,
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _darkModeRow(BuildContext context) {
    final ctrl = app.ThemeControllerScope.of(context);
    final on = ctrl.isDark;
    final bg = const Color.fromARGB(131, 0, 150, 135);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.brightness_6_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Dark Mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => ctrl.toggleTheme(),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder:
                  (child, anim) => RotationTransition(
                    turns:
                        child.key == const ValueKey('sun')
                            ? Tween<double>(begin: 0.75, end: 1).animate(anim)
                            : Tween<double>(begin: 0.25, end: 1).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
              child: Icon(
                on ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                key: ValueKey(on ? 'moon' : 'sun'),
                size: 30,
                color: on ? Colors.amber : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutRow(BuildContext context) {
    final bg = Color.fromARGB(131, 0, 150, 135);
    return InkWell(
      onTap: () async {
        // If you also sign out Firebase, do it here, then:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: const [
            Icon(Icons.logout_rounded, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Log out',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(
    BuildContext context, {
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color =
        selected ? const Color.fromARGB(255, 13, 124, 102) : Colors.white;
    return IconButton(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onPressed: onTap,
      icon: Icon(icon, size: 28, color: color),
    );
  }
}

// ————————— models / helpers —————————

enum _RowType { link, darkMode, logout }

class _Item {
  final String label;
  final IconData icon;
  final List<String> keywords;
  final Widget Function()? _builder;
  final _RowType type;

  _Item({
    required this.label,
    required this.icon,
    required this.keywords,
    required Widget Function() builder,
  }) : _builder = builder,
       type = _RowType.link;

  _Item._special(this.label, this.icon, this.keywords, this.type)
    : _builder = null;

  factory _Item.darkMode() => _Item._special(
    'Dark Mode',
    Icons.dark_mode_rounded,
    const [],
    _RowType.darkMode,
  );

  factory _Item.logout() => _Item._special(
    'Log out',
    Icons.logout_rounded,
    const ['logout'],
    _RowType.logout,
  );

  Widget builder() => _builder!.call();
}

// Small iOS-style pill switch used in row
class _MiniSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MiniSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color:
              value ? const Color(0xFFBDE8CA) : Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
