import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:new_rezonate/main.dart' as app;

/// Gentle app-wide gradient (matches Tools / Home look)
BoxDecoration _bg(BuildContext context) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
          : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
    ),
  );
}

const _ink = Colors.black;
const _kStoreKey = 'affirmations_custom_v1';
const _kPrefsKey = 'affirmations_prefs_v1';

class _AffPrefs {
  final bool notify;
  final int hour;
  final int minute;

  const _AffPrefs({this.notify = false, this.hour = 9, this.minute = 0});

  _AffPrefs copyWith({bool? notify, int? hour, int? minute}) =>
      _AffPrefs(
        notify: notify ?? this.notify,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  Map<String, dynamic> toJson() => {'n': notify, 'h': hour, 'm': minute};

  factory _AffPrefs.fromJson(Map<String, dynamic> j) => _AffPrefs(
        notify: (j['n'] ?? false) as bool,
        hour: (j['h'] ?? 9) as int,
        minute: (j['m'] ?? 0) as int,
      );
}

class AffirmationsPage extends StatefulWidget {
  const AffirmationsPage({super.key});

  @override
  State<AffirmationsPage> createState() => _AffirmationsPageState();
}

class _AffirmationsPageState extends State<AffirmationsPage> {
  final _ctrl = TextEditingController();
  final List<String> _suggested = const [
    "I am safe. I am grounded.",
    "My mind is calm and my body is relaxed.",
    "I can handle what today brings.",
    "I am worthy of rest and care.",
    "I choose progress over perfection.",
    "I am stronger than my anxious thoughts.",
    "I allow myself to feel and to heal.",
    "I am present, here and now.",
    "I am learning to trust myself.",
    "I deserve kindness—from others and from me.",
    "I can breathe through this moment.",
    "I’m doing my best, and that’s enough.",
    "I am resilient; I bounce back.",
    "I invite peace into my life.",
    "I release what I can’t control.",
  ];

  List<String> _custom = [];
  bool _showSuggested = true;
  bool _showCustom = true;

  /// text -> prefs
  Map<String, _AffPrefs> _prefsByText = {};

  /// Local notifications
  final FlutterLocalNotificationsPlugin _ln =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifs();
    _load();
  }

  Future<void> _initNotifs() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const init = InitializationSettings(android: android, iOS: ios);
    await _ln.initialize(init);
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _custom = p.getStringList(_kStoreKey) ?? []);
    // load per-text prefs
    final raw = p.getString(_kPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      _prefsByText = decoded.map(
        (k, v) => MapEntry(k, _AffPrefs.fromJson(Map<String, dynamic>.from(v))),
      );
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kStoreKey, _custom);
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    final jsonMap = {for (final e in _prefsByText.entries) e.key: e.value.toJson()};
    await p.setString(_kPrefsKey, jsonEncode(jsonMap));
  }

  void _add() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _custom.insert(0, text);
      _ctrl.clear();
    });
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Affirmation added')),
      );
    }
  }

  Future<void> _remove(int index) async {
    final text = _custom[index];
    final prefs = _prefsByText[text];
    if (prefs?.notify == true) {
      await _cancel(text);
    }
    setState(() => _custom.removeAt(index));
    await _save();
  }

  Future<void> _scheduleDaily(String text, int hour, int minute) async {
  final id = text.hashCode & 0x7fffffff;
  final now = tz.TZDateTime.now(tz.local);
  var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  if (when.isBefore(now)) when = when.add(const Duration(days: 1));

  await _ln.zonedSchedule(
    id,
    'Affirmation',
    text,
    when,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'affirmations_daily',
        'Affirmations',
        channelDescription: 'Daily affirmation reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    // ✅ Updated for v19+
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}



  Future<void> _cancel(String text) =>
      _ln.cancel(text.hashCode & 0x7fffffff);

  Future<void> _toggleNotifyFor(String text) async {
    final current = _prefsByText[text] ?? const _AffPrefs();
    final next = current.copyWith(notify: !current.notify);
    setState(() => _prefsByText[text] = next);
    await _savePrefs();

    if (next.notify) {
      await _pickTimeFor(text, initial: TimeOfDay(hour: next.hour, minute: next.minute));
    } else {
      await _cancel(text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications turned off')),
        );
      }
    }
  }

  Future<void> _pickTimeFor(String text, {TimeOfDay? initial}) async {
    final base = _prefsByText[text] ?? const _AffPrefs();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (picked == null) return;

    final updated = base.copyWith(
      notify: true,
      hour: picked.hour,
      minute: picked.minute,
    );
    setState(() => _prefsByText[text] = updated);
    await _savePrefs();
    await _scheduleDaily(text, picked.hour, picked.minute);

    if (mounted) {
      final hh = picked.hourOfPeriod.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      final ampm = picked.period == DayPeriod.am ? 'AM' : 'PM';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Will remind you daily at $hh:$mm $ampm')),
      );
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _ink, width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Add your affirmation",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Type something kind to yourself…",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _ink),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _add();
                      },
                      child: const Text('Add'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, bool open, VoidCallback onToggle) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _ink),
        ),
        child: Row(
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const Spacer(),
            Icon(open ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    );
  }

  /// Unified card used in both sections (keeps call sites the same)
  Widget _card(String text, {VoidCallback? onDelete}) {
    final prefs = _prefsByText[text] ?? const _AffPrefs();
    final timeLabel = prefs.notify
        ? '• ${TimeOfDay(hour: prefs.hour, minute: prefs.minute).format(context)}'
        : 'Off';

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _ink),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 1))
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_rounded, color: Color(0xFF0D7C66)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.25))),
          const SizedBox(width: 8),
          // Notification toggle + time
          InkWell(
            onTap: () => _toggleNotifyFor(text),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    prefs.notify
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color: prefs.notify ? const Color(0xFF0D7C66) : Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: prefs.notify ? Colors.black : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Set time',
            onPressed: () => _pickTimeFor(text),
            icon: const Icon(Icons.schedule_rounded),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Affirmations',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              // Suggested
              _sectionHeader('Suggested', _showSuggested, () {
                setState(() => _showSuggested = !_showSuggested);
              }),
              const SizedBox(height: 8),
              if (_showSuggested)
                ..._suggested
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _card(t),
                        ))
                    .toList(),

              const SizedBox(height: 12),

              // Custom
              _sectionHeader('Your affirmations', _showCustom, () {
                setState(() => _showCustom = !_showCustom);
              }),
              const SizedBox(height: 8),
              if (_showCustom)
                if (_custom.isEmpty)
                  Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _ink),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 1))
                      ],
                    ),
                    child: const Text(
                      "You don't have any yet. Tap “Add” to create your own.",
                      style: TextStyle(fontSize: 15),
                    ),
                  )
                else
                  ...List.generate(_custom.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _card(
                        _custom[i],
                        onDelete: () => _remove(i),
                      ),
                    );
                  }),
            ],
          ),
        ),
      ),
    );
  }
}
