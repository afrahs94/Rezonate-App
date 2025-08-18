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
        keywords: const ['name', 'username', 'email', 'profile', 'photo', 'picture', 'birthday'],
        builder: () => EditProfilePage(userName: widget.userName),
      ),
      _Item(
        label: 'Change Password',
        icon: Icons.lock_outline,
        keywords: const ['password', 'security', 'update', 'credentials'],
        builder: () => const ChangePasswordPage(userName: ''),
      ),
      _Item(
        label: 'Security & Privacy',
        icon: Icons.security,
        keywords: const [
          'privacy',
          'security',
          'encryption',
          'anonymous',
          'sharing',
          'app lock',
          'blocked users',
          'my journal lock'
        ],
        builder: () => SecurityAndPrivacyPage(userName: widget.userName),
      ),
      _Item(
        label: 'Push Notifications',
        icon: Icons.notifications_active_outlined,
        keywords: const ['push', 'notifications', 'reminders', 'alerts'],
        builder: () => PushNotificationsPage(userName: widget.userName),
      ),
      _Item(
        label: 'Deactivate Account',
        icon: Icons.person_off_outlined,
        keywords: const ['deactivate', 'disable', 'delete', 'close account', 'remove'],
        builder: () => DeactivateAccountPage(userName: widget.userName),
      ),
      _Item.darkMode(), // inline toggle row
      _Item.logout(),   // inline logout row
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
      _shown = _all.where((it) {
        if (it.type != _RowType.link) return false;
        if (it.label.toLowerCase().contains(q)) return true;
        return it.keywords.any((k) => k.contains(q));
      }).toList();
    });
  }

  // Jump straight to the best result when user submits.
  Future<void> _goToSearchResult() async {
    final results = _shown.where((it) => it.type == _RowType.link).toList();
    if (results.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No matching settings found')));
      return;
    }
    if (results.length == 1) {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => results.first.builder()));
      return;
    }
    // Multiple matches -> quick picker sheet
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF123A36) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 44,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Select a setting',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                ...results.map((it) => ListTile(
                      leading: Icon(it.icon, color: const Color(0xFF0D7C66)),
                      title: Text(it.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => it.builder()));
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  // Simple gradient chooser
  List<Color> _gradient(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
        : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)];
  }

  @override
  Widget build(BuildContext context) {
    final g = _gradient(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchFill = isDark ? const Color(0x1AF5F5F5) : Colors.white;

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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 29, 40, 8),
                child: Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Cleaner search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Material(
                  elevation: 4,
                  shadowColor: Colors.black12,
                  borderRadius: BorderRadius.circular(28),
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _goToSearchResult(),
                    decoration: InputDecoration(
                      hintText: 'Search settings…',
                      filled: true,
                      fillColor: searchFill,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearch();
                              },
                            ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              // Results list
              Expanded(
                child: _shown.isEmpty
                    ? const Center(
                        child: Text('No results',
                            style:
                                TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        itemCount: _shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          final it = _shown[i];
                          if (it.type == _RowType.darkMode) return _darkModeRow(context);
                          if (it.type == _RowType.logout) return _logoutRow(context);
                          return _linkRow(context, it);
                        },
                      ),
              ),

              // Bottom navigation
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _navIcon(
                      context,
                      icon: Icons.home_rounded,
                      selected: false,
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HomePage(userName: widget.userName),
                        ),
                      ),
                    ),
                    _navIcon(
                      context,
                      icon: Icons.menu_book_rounded,
                      selected: false,
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JournalPage(userName: widget.userName),
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
    final bg = const Color.fromARGB(131, 0, 150, 135);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => it.builder()),
      ),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
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
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
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
              transitionBuilder: (child, anim) => RotationTransition(
                turns: child.key == const ValueKey('sun')
                    ? Tween<double>(begin: 0.75, end: 1).animate(anim)
                    : Tween<double>(begin: 0.25, end: 1).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                on ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                key: ValueKey(on ? 'moon' : 'sun'),
                size: 26,
                color: on ? Colors.amber : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutRow(BuildContext context) {
    final bg = const Color.fromARGB(131, 0, 150, 135);
    return InkWell(
      onTap: () async {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
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
      icon: Icon(icon, size: 24, color: color),
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
  })  : _builder = builder,
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
