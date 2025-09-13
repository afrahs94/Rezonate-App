// lib/pages/settings.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

// Onboarding + showcase
import 'onboarding.dart';
import 'package:showcaseview/showcaseview.dart';

class SettingsPage extends StatefulWidget {
  final String userName;
  const SettingsPage({super.key, required this.userName});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class NoTransitionPageRoute<T> extends MaterialPageRoute<T> {
  NoTransitionPageRoute({required WidgetBuilder builder}) : super(builder: builder);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return child; // no animation
  }
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<_Item> _all;
  late List<_Item> _shown;
  late List<String> _suggestions;

  // 👇 local key for the Search showcase (avoids OBKeys import issues)
  final GlobalKey _settingsSearchKey = GlobalKey();

  // showcase ctx (must be under ShowCaseWidget)
  late BuildContext _showcaseCtx;

  @override
  void initState() {
    super.initState();
    _suggestions = [];
    _all = [
      _Item(
        label: 'Edit Profile',
        icon: Icons.person_outline,
        keywords: const [
          'edit profile', 'profile', 'name', 'username', 'email', 'bio',
          'photo', 'picture', 'avatar', 'birthday', 'account info', 'details',
        ],
        builder: () => EditProfilePage(userName: widget.userName),
      ),
      _Item(
        label: 'Change Password',
        icon: Icons.lock_outline,
        keywords: const [
          'change password','password','update password','reset password',
          'credentials','security','old password','new password','confirm password',
        ],
        builder: () => const ChangePasswordPage(userName: ''),
      ),
      _Item(
        label: 'Security & Privacy',
        icon: Icons.security,
        keywords: const [
          'security & privacy','security','privacy','encryption','permissions',
          'anonymous','sharing','app lock','pin','blocked users','journal lock',
          'data','tracking','biometrics','face id','touch id',
        ],
        builder: () => SecurityAndPrivacyPage(userName: widget.userName),
      ),
      _Item(
        label: 'Push Notifications',
        icon: Icons.notifications_active_outlined,
        keywords: const [
          'push notifications','notifications','notify','reminders','alerts',
          'daily reminder','journal reminder','mute','do not disturb','schedule',
        ],
        builder: () => PushNotificationsPage(userName: widget.userName),
      ),
      _Item.replayTutorial(),
      _Item(
        label: 'Deactivate Account',
        icon: Icons.person_off_outlined,
        keywords: const [
          'deactivate account','deactivate','delete account','delete',
          'close account','disable','remove account','account deletion',
          'permanently delete',
        ],
        builder: () => DeactivateAccountPage(userName: widget.userName),
      ),
      _Item.darkMode(),
      _Item.logout(),
    ];
    _shown = List.of(_all);
    _searchCtrl.addListener(_onSearch);

    _maybeStartSettingsShowcase();
  }

  Future<void> _maybeStartSettingsShowcase() async {
    final stage = await Onboarding.getStage();
    if (stage != OnboardingStage.replayingTutorial) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        ShowCaseWidget.of(_showcaseCtx).startShowCase([_settingsSearchKey]);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  String _norm(String s) => s.toLowerCase().trim();
  int _lev(String a, String b) {
    a = _norm(a); b = _norm(b);
    if (a == b) return 0; if (a.isEmpty) return b.length; if (b.isEmpty) return a.length;
    final m = a.length, n = b.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) dp[i][0] = i;
    for (var j = 0; j <= n; j++) dp[0][j] = j;
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[m][n];
  }

  List<String> _suggestFor(String query, {int maxReturn = 3}) {
    final q = _norm(query);
    if (q.isEmpty) return [];
    final scores = <String, int>{};
    for (final it in _all) {
      if (it.type == _RowType.darkMode) continue;
      var best = 9999;
      for (final text in [it.label, ...it.keywords]) {
        final parts = _norm(text).split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty);
        for (final w in parts) {
          final d = _lev(q, w);
          if (d < best) best = d;
          if (best == 0) break;
        }
        if (best == 0) break;
      }
      if (best <= 3) {
        scores[it.label] = scores[it.label] == null ? best : (best < scores[it.label]!? best : scores[it.label]!);
      }
    }
    final sorted = scores.entries.toList()
      ..sort((a, b) => a.value != b.value ? a.value - b.value : a.key.compareTo(b.key));
    return sorted.take(maxReturn).map((e) => e.key).toList();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() { _shown = List.of(_all); _suggestions = []; });
      return;
    }
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    bool matches(_Item it) {
      final isLogout = it.type == _RowType.logout;
      final isReplay = it.type == _RowType.replay;
      final isSearchable = it.type == _RowType.link || isLogout || isReplay;
      if (!isSearchable) return false;

      final haystack = <String>[ it.label.toLowerCase(), ...it.keywords.map((k) => k.toLowerCase()) ];

      const minLen = 3;
      if (isLogout) {
        return tokens.any((tok) => tok.length >= minLen && haystack.any((h) => h.contains(tok)));
      }
      return tokens.every((tok) => haystack.any((h) => h.contains(tok)));
    }

    final results = _all.where(matches).toList();
    setState(() {
      _shown = results;
      _suggestions = results.isEmpty ? _suggestFor(_searchCtrl.text) : [];
    });
  }

  Future<void> _goToSearchResult() async {
    final results = _shown.where((it) => it.type == _RowType.link).toList();
    if (results.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No matching settings found')));
      return;
    }
    if (results.length == 1) {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => results.first.builder()));
      return;
    }
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
                Container(height: 4, width: 44, margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(20)),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Select a setting', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                ...results.map((it) => ListTile(
                      leading: const Icon(Icons.tune, color: Color(0xFF0D7C66)),
                      title: Text(it.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => it.builder()));
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Color> _gradient(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
                : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)];
  }

  @override
  Widget build(BuildContext context) {
    final g = _gradient(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchFill = isDark ? const Color(0x1AF5F5F5) : Colors.white;

    return ShowCaseWidget(
      builder: (ctx) {
        _showcaseCtx = ctx;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: g, begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(40, 29, 40, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Settings', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),

                  // 🔎 Showcase ends here
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Showcase(
                      key: _settingsSearchKey,
                      description:
                          'Search anything in Settings — try “password”, “notifications”, or “dark mode”. It’s the fastest way to find options.',
                      disposeOnTap: true,
                      onToolTipClick: () async => Onboarding.setStage(OnboardingStage.done),
                      onTargetClick:  () async => Onboarding.setStage(OnboardingStage.done),
                      onBarrierClick: () async => Onboarding.setStage(OnboardingStage.done),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                      child: _DidYouMean(
                        suggestions: _suggestions,
                        onTap: (label) {
                          _searchCtrl.text = label;
                          _searchCtrl.selection =
                              TextSelection.fromPosition(TextPosition(offset: _searchCtrl.text.length));
                          _onSearch();
                        },
                      ),
                    ),

                  Expanded(
                    child: _shown.isEmpty
                        ? const Center(
                            child: Text('No results',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                            itemCount: _shown.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, i) {
                              final it = _shown[i];
                              if (it.type == _RowType.darkMode) return _darkModeRow(context);
                              if (it.type == _RowType.logout) return _logoutRow(context);
                              if (it.type == _RowType.replay) return _replayRow(context);
                              return _linkRow(context, it);
                            },
                          ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _navIcon(context, icon: Icons.home_rounded, selected: false, onTap: () {
                          Navigator.pushReplacement(context,
                              NoTransitionPageRoute(builder: (_) => HomePage(userName: widget.userName)));
                        }),
                        _navIcon(context, icon: Icons.menu_book_rounded, selected: false, onTap: () {
                          Navigator.pushReplacement(context,
                              NoTransitionPageRoute(builder: (_) => JournalPage(userName: widget.userName)));
                        }),
                        _navIcon(context, icon: Icons.settings_rounded, selected: true, onTap: () {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ——— UI parts ———

  Widget _linkRow(BuildContext context, _Item it) {
    final bg = const Color.fromARGB(131, 0, 150, 135);
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => it.builder())),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Row(
          children: [
            Icon(it.icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(it.label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _replayRow(BuildContext context) {
    final bg = const Color.fromARGB(131, 0, 150, 135);
    Future<void> _startReplay() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Replay tutorial?'),
          content: const Text('We’ll show a quick walkthrough of the app. Your data won’t be changed.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start')),
          ],
        ),
      );
      if (ok == true) {
        await Onboarding.replayTutorial();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          NoTransitionPageRoute(builder: (_) => HomePage(userName: widget.userName)),
          (route) => false,
        );
      }
    }

    return InkWell(
      onTap: _startReplay,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: const Row(
          children: [
            Icon(Icons.school_outlined, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text('Replay Tutorial', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.play_circle_outline, color: Colors.white),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          const Icon(Icons.brightness_6_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Dark Mode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () => ctrl.toggleTheme(),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  RotationTransition(turns: child.key == const ValueKey('sun') ? Tween<double>(begin: .75, end: 1).animate(anim) : Tween<double>(begin: .25, end: 1).animate(anim), child: FadeTransition(opacity: anim, child: child)),
              child: Icon(on ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded, key: ValueKey(on ? 'moon' : 'sun'), size: 26, color: on ? Colors.amber : Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutRow(BuildContext context) {
    final bg = const Color.fromARGB(131, 0, 150, 135);
    Future<void> _confirmLogout() async {
      final theme = Theme.of(context);
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Log out?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          content: Text('Are you sure you want to log out?', style: theme.textTheme.bodyMedium),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
          ],
        ),
      );
      if (ok == true && context.mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', false);
        await prefs.remove('user_name');
        await FirebaseAuth.instance.signOut();
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
      }
    }

    return InkWell(
      onTap: _confirmLogout,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Expanded(child: Text('Log out', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
            Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(BuildContext context, {required IconData icon, required bool selected, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected ? (isDark ? const Color(0xFFBDA9DB) : const Color(0xFF0D7C66)) : Colors.white;
    return IconButton(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onPressed: onTap,
      icon: Icon(icon, size: 24, color: color),
    );
  }
}

// ——— models / helpers ———

enum _RowType { link, darkMode, logout, replay }

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

  _Item._special(this.label, this.icon, this.keywords, this.type) : _builder = null;

  factory _Item.darkMode() => _Item._special('Dark Mode', Icons.dark_mode_rounded, const [], _RowType.darkMode);
  factory _Item.logout() => _Item._special('Log out', Icons.logout_rounded,
      const ['logout', 'log out', 'sign out', 'logoff', 'log off'], _RowType.logout);
  factory _Item.replayTutorial() => _Item._special(
      'Replay Tutorial',
      Icons.school_outlined,
      const ['replay tutorial', 'tutorial', 'tour', 'walkthrough', 'guide', 'help', 'how to', 'onboarding', 'showcase', 'intro'],
      _RowType.replay);

  Widget builder() => _builder!.call();
}

class _DidYouMean extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;
  const _DidYouMean({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Did you mean:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Flexible(
          child: Wrap(
            spacing: 8,
            runSpacing: -6,
            children: suggestions.map((s) => ActionChip(label: Text(s), onPressed: () => onTap(s), elevation: 0)).toList(),
          ),
        ),
      ],
    );
  }
}
