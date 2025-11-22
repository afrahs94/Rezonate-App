// lib/pages/home.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui' show FontFeature, ImageFilter;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding.dart';
import 'onboarding_keys.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:new_rezonate/main.dart' as app;
import 'journal.dart';
import 'settings.dart';
import 'edit_profile.dart';
import 'tools.dart';
import 'summaries.dart';

class Tracker {
  Tracker({
    required this.id,
    required this.label,
    required this.color,
    this.value = 5,
    this.sort = 0,
  });
  final String id;
  String label;
  Color color;
  double value;
  int sort;

  Map<String, dynamic> toMap() => {
        'label': label,
        'color': color.value,
        'latest_value': value,
        'sort': sort,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

  static Tracker fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Tracker(
      id: d.id,
      label: (m['label'] as String? ?? 'add tracker').trim(),
      color: Color((m['color'] as int?) ?? const Color(0xFF147C72).value),
      value: (m['latest_value'] as num?)?.toDouble() ?? 5,
      sort: (m['sort'] as num?)?.toInt() ?? 0,
    );
  }
}

enum ChartView { weekly, monthly, overall }

class HomePage extends StatefulWidget {
  final String userName;
  const HomePage({super.key, required this.userName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  User? get _user => _auth.currentUser;

  Timer? _replayAutoNext;
  int? _prevTrackerCount;
  bool _navigatedAfterHabit = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _trackersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _logsSub;

  BuildContext? _showcaseCtx;
  bool _tourActive = false;
  bool _showNextButton = false;

  final _rnd = Random();
  List<Tracker> _trackers = [];
  final Set<String> _selectedForChart = {};
  ChartView _view = ChartView.weekly;

  final Map<String, Map<String, double>> _daily = {};
  final Set<String> _daysWithAnyLog = {};

  DateTime? _lastLogAt;
  DateTime? _firstLogTodayAt;
  DateTime? _lastLogBeforeTodayAt;

  final List<double> _emojiTicks = const [0.0, 2.5, 5.0, 7.5, 10.0];

  final Map<double, String> _defaultEmojis = {
    0.0: "🙂",
    2.5: "🙂",
    5.0: "😐",
    7.5: "🙁",
    10.0: "😭",
  };

  late Map<double, String> _emojiForTick = Map<double, String>.from(_defaultEmojis);

  Timer? _midnightTimer;

  // ───── Rez currency state (stored in Firestore) ─────
  int _rezBalance = 0;
  List<_RezTransaction> _rezHistory = [];
  DateTime? _lastTrackDay;

  bool _rezPanelOpen = false;
  final double _rezPanelWidth = 280;
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _initRez();
    _loadProfilePhoto();
    _bootstrap().then((_) => _maybeStartHomeShowcase());
    _loadEmojis();
    _scheduleMidnightReset();
    _maybeShowQuoteOfDay();
  }

  @override
  void dispose() {
    _replayAutoNext?.cancel();
    _trackersSub?.cancel();
    _logsSub?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  Future<void> _initRez() async {
    final u = _user;
    if (u == null) return;
    try {
      final snap = await _db.collection('users').doc(u.uid).get();
      final data = snap.data() ?? {};
      final bal = (data['rez_balance'] as num?)?.toInt() ?? 0;

      final lastStr = data['rez_last_day'] as String?;
      DateTime? last;
      if (lastStr != null && lastStr.isNotEmpty) {
        try {
          last = DateTime.parse(lastStr);
        } catch (_) {}
      }

      List<_RezTransaction> history = [];
      final rawHist = data['rez_history'];
      if (rawHist is List) {
        history = rawHist
            .whereType<Map>()
            .map((e) => _RezTransaction.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }

      if (!mounted) return;
      setState(() {
        _rezBalance = bal;
        _lastTrackDay = last;
        _rezHistory = history;
      });
    } catch (_) {
      // fail silently for now
    }
  }

  Future<void> _saveRezState() async {
    final u = _user;
    if (u == null) return;
    final docRef = _db.collection('users').doc(u.uid);
    await docRef.set(
      {
        'rez_balance': _rezBalance,
        'rez_last_day': _lastTrackDay != null ? _dayKey(_lastTrackDay!) : null,
        'rez_history': _rezHistory.map((t) => t.toMap()).toList(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _loadProfilePhoto() async {
    final u = _user;
    if (u == null) return;
    try {
      final snap = await _db.collection('users').doc(u.uid).get();
      final data = snap.data();
      final photo = (data?['photoUrl'] ?? u.photoURL)?.toString();
      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = (photo != null && photo.isNotEmpty) ? photo : null;
      });
    } catch (_) {}
  }

  Future<void> _updateRezForTracking() async {
    final u = _user;
    if (u == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? lastDate = _lastTrackDay;

    int delta = 0;
    if (lastDate == null) {
      // First time ever tracking
      delta = 3;
    } else {
      final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final diff = today.difference(last).inDays;

      if (diff == 0) {
        // Already gave today's Rez
        return;
      } else {
        // +3 for tracking today
        delta += 3;
        // -3 for each full day missed in between
        if (diff > 1) {
          delta -= 3 * (diff - 1);
        }
      }
    }

    if (delta != 0) {
      final desc = delta > 0
          ? (delta == 3 ? 'Daily track bonus' : 'Daily bonus & missed-day penalty')
          : 'Missed day penalty';

      final tx = _RezTransaction(
        amount: delta,
        description: desc,
        timestamp: now,
      );

      setState(() {
        _rezBalance += delta;
        _rezHistory.insert(0, tx);
        if (_rezHistory.length > 30) {
          _rezHistory = _rezHistory.sublist(0, 30);
        }
        _lastTrackDay = today;
      });
    } else {
      setState(() => _lastTrackDay = today);
    }

    await _saveRezState();
  }

  Future<void> _maybeShowQuoteOfDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final last = prefs.getString('quote_last_shown');
    if (last == today) return;

    const quotes = [
      'Small steps are still steps.',
      'You don’t have to be perfect to be proud.',
      'Feelings are visitors—let them come and go.',
      'Rest is productive.',
      'You made it this far. Keep going.',
      'Name it to tame it.',
      'Progress beats perfection.',
      'Breathe. Then begin.',
      'One kind thought can change a day.',
      'You are allowed to start over.',
      'Healing is not linear.',
      'Do the next right thing.',
      'Be where your feet are.',
      'Tiny habits grow into big change.',
      'Your pace is your pace.',
      'You deserve the same kindness you give.',
      'You are more than your to-do list.',
      'You can do hard things.',
      'It’s okay to ask for help.',
      'Let today be a soft day.',
      'Choose progress, not speed.',
      'Rest, hydrate, move, repeat.',
      'A setback is a setup for a comeback.',
      'Pause is power.',
      'Make room for joy.',
      'One breath, one step, one thing.',
      'Your feelings are valid.',
      'Mistakes are proof you’re trying.',
      'Boundaries are self-respect.',
      'You are not your thoughts.',
      'Gratitude shifts the view.',
      'Say no when you need to.',
      'Celebrate small wins.',
      'Curiosity over judgment.',
      'Start where you are.',
      'Light is allowed to be gentle.',
      'Future you is thanking you.',
      'Keep the promise you made to yourself.',
      'Let go to grow.',
      'Slow is smooth, smooth is fast.',
      'Even clouds make shade for rest.',
      'Your worth isn’t measured by productivity.',
      'Notice one good thing right now.',
      'Speak to yourself like a friend.',
      'You’re learning, not failing.',
      'Take the scenic route.',
      'Be proud of getting through.',
      'Recovery loves routine.',
      'Peace is a practice.',
      'You’re doing better than you think.',
    ];
    final q = quotes[_rnd.nextInt(quotes.length)];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) {
          final dark = app.ThemeControllerScope.of(context).isDark;
          return AlertDialog(
            backgroundColor: dark ? const Color(0xFF123A36) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Quote of the day'),
            content: Text(q, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      );
    });

    await prefs.setString('quote_last_shown', today);
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final delay = nextMidnight.difference(now);
    _midnightTimer = Timer(delay, _handleMidnightReset);
  }

  void _handleMidnightReset() {
    if (!mounted) return;
    setState(() {
      for (final t in _trackers) {
        t.value = 5;
      }
    });
    _scheduleMidnightReset();
  }

  String _prefKeyForTick(double t) => 'emoji_tick_${(t * 10).round()}';

  Future<void> _loadEmojis() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<double, String> loaded = {};
    for (final t in _emojiTicks) {
      loaded[t] = prefs.getString(_prefKeyForTick(t)) ?? _defaultEmojis[t]!;
    }
    if (!mounted) return;
    setState(() => _emojiForTick = loaded);
  }

  Future<void> _saveEmojis(Map<double, String> next) async {
    final prefs = await SharedPreferences.getInstance();
    for (final t in _emojiTicks) {
      await prefs.setString(_prefKeyForTick(t), next[t] ?? _defaultEmojis[t]!);
    }
    if (!mounted) return;
    setState(() => _emojiForTick = Map<double, String>.from(next));
  }

  Future<void> _openEmojiPicker() async {
    final Map<double, String> draft = Map<double, String>.from(_emojiForTick);
    final controllers = {for (final t in _emojiTicks) t: TextEditingController(text: draft[t])};

    String sanitize(String v, double tick) {
      final trimmed = v.trim();
      if (trimmed.isEmpty) return _defaultEmojis[tick]!;
      return trimmed.characters.isNotEmpty ? trimmed.characters.first : _defaultEmojis[tick]!;
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        final dark = app.ThemeControllerScope.of(context).isDark;
        final labelStyle = const TextStyle(fontWeight: FontWeight.w600, fontSize: 13);
        Widget labelFor(double t) {
          if (t == 0.0) return Text('Low (0)', style: labelStyle);
          if (t == 10.0) return Text('High (10)', style: labelStyle);
          return const SizedBox(width: 74);
        }

        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF123A36) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Customize emojis'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in _emojiTicks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(width: 86, child: labelFor(t)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: controllers[t],
                            maxLength: 2,
                            buildCounter: (_, {required currentLength, required maxLength, required isFocused}) =>
                                const SizedBox.shrink(),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Enter emoji',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => draft[t] = sanitize(v, t),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        for (final t in _emojiTicks) {
                          controllers[t]!.text = _defaultEmojis[t]!;
                          draft[t] = _defaultEmojis[t]!;
                        }
                        setState(() {});
                      },
                      child: const Text('Reset'),
                    ),
                    const Spacer(),
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: () async {
                        await _saveEmojis(draft);
                        if (mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7C66),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _maybeStartHomeShowcase() async {
    var stage = await Onboarding.getStage();

    if (stage == OnboardingStage.notStarted) {
      await Onboarding.setStage(OnboardingStage.homeIntro);
      stage = OnboardingStage.homeIntro;
    }
    if (!mounted) return;

    final isRelevant = stage == OnboardingStage.homeIntro ||
        stage == OnboardingStage.needFirstHabit ||
        stage == OnboardingStage.replayingTutorial;

    setState(() {
      _tourActive = isRelevant;
      _showNextButton = false;
    });

    if (!isRelevant) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _showcaseCtx;
      if (ctx == null) return;
      try {
        ShowCaseWidget.of(ctx).startShowCase([
          OBKeys.addHabit,
          OBKeys.chartSelector,
          OBKeys.journalTab,
          OBKeys.settingsTab,
        ]);
      } catch (_) {}
    });

    if (stage == OnboardingStage.replayingTutorial) {
      _replayAutoNext?.cancel();
      _replayAutoNext = Timer(const Duration(milliseconds: 6000), () {
        if (!mounted) return;
        Navigator.pushReplacement(context, _slideTo(JournalPage(userName: widget.userName)));
      });
    }
  }

  Future<void> _bootstrap() async {
    final u = _user;
    if (u == null) return;

    _trackersSub = _db
        .collection('users')
        .doc(u.uid)
        .collection('trackers')
        .orderBy('sort')
        .snapshots()
        .listen((snap) async {
      final list = snap.docs.map(Tracker.fromDoc).toList();
      final count = list.length;

      if (!mounted) return;
      setState(() {
        _trackers = list;
        _selectedForChart
          ..clear()
          ..addAll(_trackers.map((t) => t.id));
      });

      final stage = await Onboarding.getStage();

      if (stage == OnboardingStage.homeIntro || stage == OnboardingStage.needFirstHabit) {
        if (count == 0) {
          await Onboarding.setStage(OnboardingStage.needFirstHabit);
          if (mounted) {
            setState(() {
              _tourActive = true;
              _showNextButton = false;
            });
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = _showcaseCtx;
            if (ctx == null) return;
            try {
              ShowCaseWidget.of(ctx).startShowCase([
                OBKeys.addHabit,
                OBKeys.chartSelector,
                OBKeys.journalTab,
                OBKeys.settingsTab,
              ]);
            } catch (_) {}
          });
        }

        final prev = _prevTrackerCount ?? 0;
        if (!_navigatedAfterHabit && prev == 0 && count >= 1) {
          await Onboarding.markHabitCreated();
          _navigatedAfterHabit = true;
          if (!mounted) return;
          Navigator.pushReplacement(context, _slideTo(JournalPage(userName: widget.userName)));
          return;
        }
      }

      _prevTrackerCount = count;

      if (stage == OnboardingStage.replayingTutorial) {
        if (mounted) {
          setState(() {
            _tourActive = true;
            _showNextButton = false;
          });
        }
      }
    });

    _logsSub = _db
        .collection('users')
        .doc(u.uid)
        .collection('daily_logs')
        .orderBy('day', descending: false)
        .limit(120)
        .snapshots()
        .listen((snap) {
      final map = <String, Map<String, double>>{};
      final daysWithLogs = <String>{};

      DateTime? newest;
      DateTime? firstToday;
      DateTime? prevBeforeToday;

      final todayKey = _dayKey(DateTime.now());

      for (final d in snap.docs) {
        final m = d.data();
        final vals = (m['values'] as Map?)?.map((k, v) => MapEntry('$k', (v as num).toDouble())) ??
            <String, double>{};
        map[d.id] = vals.cast<String, double>();
        if (vals.isNotEmpty) daysWithLogs.add(d.id);

        final ts = (m['updatedAt'] is Timestamp) ? (m['updatedAt'] as Timestamp).toDate() : null;
        if (ts != null) {
          if (newest == null || ts.isAfter(newest)) newest = ts;
        } else if (vals.isNotEmpty) {
          final dayInt = (m['day'] as num?)?.toInt();
          if (dayInt != null) {
            final int y = dayInt ~/ 10000;
            final int mo = (m['day'] % 10000) ~/ 100;
            final int da = m['day'] % 100;
            final fallback = DateTime(y, mo, da, 23, 59, 59);
            if (newest == null || fallback.isAfter(newest)) newest = fallback;
          }
        }

        if (d.id == todayKey) {
          final f = (m['firstAt'] is Timestamp) ? (m['firstAt'] as Timestamp).toDate() : null;
          if (f != null) firstToday = f;
        } else {
          if (ts != null) {
            if (prevBeforeToday == null || ts.isAfter(prevBeforeToday)) {
              prevBeforeToday = ts;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _daily
          ..clear()
          ..addAll(map);
        _daysWithAnyLog
          ..clear()
          ..addAll(daysWithLogs);
        _lastLogAt = newest;
        _firstLogTodayAt = firstToday;
        _lastLogBeforeTodayAt = prevBeforeToday;
      });
    });
  }

  String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  List<DateTime> _currentWeekMonToSun() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: (now.weekday - DateTime.monday)));
    return List.generate(7, (i) => DateTime(start.year, start.month, start.day + i));
  }

  List<DateTime> _lastNDays(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      final d = now.subtract(Duration(days: n - 1 - i));
      return DateTime(d.year, d.month, d.day);
    });
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  int get _streak {
    if (_daysWithAnyLog.isEmpty) return 0;

    final today = DateTime.now();
    final todayKey = _dayKey(today);
    final hasToday = _daysWithAnyLog.contains(todayKey);

    final loggedDates = _daysWithAnyLog.map((k) => DateTime.parse(k)).toSet();

    DateTime anchor;
    if (hasToday) {
      anchor = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1));
    } else {
      final all = loggedDates.toList()..sort();
      anchor = all.last;
    }

    if (!loggedDates.contains(DateTime(anchor.year, anchor.month, anchor.day))) {
      return 0;
    }

    int count = 0;
    DateTime d = anchor;
    while (loggedDates.contains(DateTime(d.year, d.month, d.day))) {
      count++;
      d = d.subtract(const Duration(days: 1));
    }
    return count;
  }

  LinearGradient _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
          : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
    );
  }

  Future<void> _createTracker({required String label}) async {
    final u = _user;
    if (u == null) return;
    final id = 't${DateTime.now().microsecondsSinceEpoch}';
    final color = const Color(0xFF0D7C66);
    final sort = _trackers.length;
    final t = Tracker(id: id, label: label, color: color, value: 5, sort: sort);
    await _db.collection('users').doc(u.uid).collection('trackers').doc(id).set(t.toMap());
  }

  Future<void> _updateTracker(
    Tracker t, {
    String? label,
    Color? color,
    double? latest,
  }) async {
    final u = _user;
    if (u == null) return;
    final data = <String, dynamic>{
      if (label != null) 'label': label,
      if (color != null) 'color': color.value,
      if (latest != null) 'latest_value': latest,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('users').doc(u.uid).collection('trackers').doc(t.id).set(data, SetOptions(merge: true));
  }

  Future<void> _persistOrder() async {
    final u = _user;
    if (u == null) return;
    final batch = _db.batch();
    for (var i = 0; i < _trackers.length; i++) {
      final t = _trackers[i];
      t.sort = i;
      batch.set(
        _db.collection('users').doc(u.uid).collection('trackers').doc(t.id),
        {'sort': i, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> _recordTrackerValue(Tracker t, double v) async {
    final u = _user;
    if (u == null) return;

    final now = DateTime.now();

    // Rez currency update (3 Rez per tracked day, -3 per missed day)
    await _updateRezForTracking();

    final key = _dayKey(now);
    _daily.putIfAbsent(key, () => {});
    _daily[key]![t.id] = v;
    _daysWithAnyLog.add(key);
    _lastLogAt = now;
    _firstLogTodayAt ??= now;
    if (mounted) setState(() => t.value = v);

    final dayInt = int.parse(DateFormat('yyyyMMdd').format(now));
    final docRef = _db.collection('users').doc(u.uid).collection('daily_logs').doc(key);
    final snap = await docRef.get();

    final data = <String, dynamic>{
      'day': dayInt,
      'values': {t.id: v},
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snap.exists || !(snap.data()?['firstAt'] is Timestamp)) 'firstAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data, SetOptions(merge: true));
    await _updateTracker(t, latest: v);
  }

  Future<void> _deleteTracker(Tracker t) async {
    final u = _user;
    if (u == null) return;
    await _db.collection('users').doc(u.uid).collection('trackers').doc(t.id).delete();
    if (!mounted) return;
    setState(() {
      _trackers.removeWhere((x) => x.id == t.id);
      _selectedForChart.remove(t.id);
    });
  }

  List<double> _valuesForDates(Tracker t, List<DateTime> days) {
    return days.map((d) => _daily[_dayKey(d)]?[t.id] ?? 0.0).toList();
  }

  String _dateRangeHeading() {
    if (_view == ChartView.weekly) {
      final days = _currentWeekMonToSun();
      final a = '${DateFormat('MMM').format(days.first)} ${_ordinal(days.first.day)}';
      final b = '${DateFormat('MMM').format(days.last)} ${_ordinal(days.last.day)}';
      return '$a – $b';
    } else if (_view == ChartView.monthly) {
      final days = _lastNDays(28);
      final a = '${DateFormat('MMM').format(days.first)} ${_ordinal(days.first.day)}';
      final b = '${DateFormat('MMM').format(days.last)} ${_ordinal(days.last.day)}';
      return 'Last 28 days • $a – $b';
    } else {
      final days = _lastNDays(84);
      final a = '${DateFormat('MMM').format(days.first)} ${_ordinal(days.first.day)}';
      final b = '${DateFormat('MMM').format(days.last)} ${_ordinal(days.last.day)}';
      return 'Last 12 weeks • $a – $b';
    }
  }

  LineChartData _chartData() {
    final sel = _trackers.where((t) => _selectedForChart.contains(t.id)).toList();

    final List<List<double>> seriesValues = [];
    int pointCount;

    if (_view == ChartView.weekly) {
      final days = _currentWeekMonToSun();
      pointCount = 7;
      for (final t in sel) {
        seriesValues.add(_valuesForDates(t, days));
      }
    } else if (_view == ChartView.monthly) {
      final days = _lastNDays(28);
      pointCount = 4;
      for (final t in sel) {
        final vals = _valuesForDates(t, days);
        final chunks = [
          vals.sublist(0, 7),
          vals.sublist(7, 14),
          vals.sublist(14, 21),
          vals.sublist(21, 28),
        ];
        seriesValues.add(chunks.map<double>((w) => w.isEmpty ? 0.0 : w.reduce((a, b) => a + b) / w.length).toList());
      }
    } else {
      final days = _lastNDays(84);
      pointCount = 4;
      for (final t in sel) {
        final vals = _valuesForDates(t, days);
        const size = 21;
        final chunks = [
          vals.sublist(0, size),
          vals.sublist(size, size * 2),
          vals.sublist(size * 2, size * 3),
          vals.sublist(size * 3, size * 4),
        ];
        seriesValues.add(chunks.map<double>((w) => w.isEmpty ? 0.0 : w.reduce((a, b) => a + b) / w.length).toList());
      }
    }

    const double yPad = 2.0;
    const double minY = 0 - yPad;
    const double maxY = 10 + yPad;

    final bars = <LineChartBarData>[];
    for (int s = 0; s < sel.length; s++) {
      final t = sel[s];
      final vals = seriesValues[s];
      final spots = <FlSpot>[for (int i = 0; i < pointCount; i++) FlSpot(i.toDouble(), vals[i])];
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 3,
          color: t.color,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    const pad = 0.5;
    final double minX = -pad;
    final double maxX = (pointCount - 1) + pad;

    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 2,
        getDrawingHorizontalLine: (v) => FlLine(strokeWidth: 0.6, color: Colors.black12),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 10,
            getTitlesWidget: (value, meta) {
              if (value.toInt() == 0) {
                return Text(_emojiForTick[0.0]!, style: const TextStyle(fontSize: 20));
              }
              if (value.toInt() == 10) {
                return Text(_emojiForTick[10.0]!, style: const TextStyle(fontSize: 20));
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (value % 1 != 0) return const SizedBox.shrink();
              final i = value.toInt();
              if (_view == ChartView.weekly) {
                final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
                if (i >= 0 && i < days.length) {
                  return Text(days[i], style: const TextStyle(fontSize: 12.5));
                }
              } else if (_view == ChartView.monthly) {
                final weeks = ["Week 1", "Week 2", "Week 3", "Week 4"];
                if (i >= 0 && i < 4) {
                  return Text(weeks[i], style: const TextStyle(fontSize: 12));
                }
              } else if (_view == ChartView.overall) {
                final labels = ["Q1", "Q2", "Q3", "Q4"];
                if (i >= 0 && i < 4) {
                  return Text(labels[i], style: const TextStyle(fontSize: 12));
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: bars,
      clipData: const FlClipData.all(),
    );
  }

  PageRouteBuilder _slideTo(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  Future<void> _goNextFromHome() async {
    if (!mounted) return;
    Navigator.pushReplacement(context, _slideTo(JournalPage(userName: widget.userName)));
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);
    final now = DateTime.now();
    final dateLine = DateFormat('EEEE • MMM d, yyyy').format(now);
    final streakNow = _streak;
    final bool _isDark = app.ThemeControllerScope.of(context).isDark;

    return ShowCaseWidget(
      builder: (ctx) {
        _showcaseCtx = ctx;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Main content
              Container(
                decoration: BoxDecoration(gradient: _bg(context)),
                child: SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _HeaderShadowIcon(
                                    icon: Icons.settings_outlined,
                                    tooltip: 'Settings',
                                    onTap: () => Navigator.push(
                                      context,
                                      NoTransitionPageRoute(
                                        builder: (_) => SettingsPage(userName: widget.userName),
                                      ),
                                    ),
                                  ),
                                  _HeaderShadowIcon(
                                    icon: Icons.person_outline_rounded,
                                    tooltip: 'Edit profile',
                                    onTap: () => Navigator.push(
                                      context,
                                      NoTransitionPageRoute(
                                        builder: (_) => EditProfilePage(userName: widget.userName),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: SizedBox(
                                  height: 72,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (_isDark)
                                        Transform.scale(
                                          scale: 1.08,
                                          child: ImageFiltered(
                                            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                            child: ColorFiltered(
                                              colorFilter: ColorFilter.mode(
                                                const Color(0xFF0D7C66).withOpacity(0.85),
                                                BlendMode.srcATop,
                                              ),
                                              child: Image.asset(
                                                'assets/images/Logo.png',
                                                height: 72,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ),
                                      _isDark
                                          ? ColorFiltered(
                                              colorFilter:
                                                  const ColorFilter.mode(Color(0xFF0D7C66), BlendMode.srcATop),
                                              child: Image.asset(
                                                'assets/images/Logo.png',
                                                height: 72,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) =>
                                                    Icon(Icons.flash_on, size: 72, color: green.withOpacity(.85)),
                                              ),
                                            )
                                          : Image.asset(
                                              'assets/images/Logo.png',
                                              height: 72,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(Icons.flash_on, size: 72, color: green.withOpacity(.85)),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Hello, ${widget.userName}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateLine,
                                style: TextStyle(
                                  color: Colors.black.withOpacity(.65),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (streakNow > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isDark
                                        ? const Color(0xFF0D7C66).withOpacity(.14)
                                        : Colors.white.withOpacity(.9),
                                    borderRadius: BorderRadius.circular(24),
                                    border: _isDark ? Border.all(color: Colors.white.withOpacity(.10)) : null,
                                    boxShadow: [
                                      if (!_isDark) const BoxShadow(color: Colors.black12, blurRadius: 4),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_fire_department,
                                        color: _isDark
                                            ? Colors.deepOrange.withOpacity(.85)
                                            : Colors.deepOrange,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$streakNow-day streak',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: _isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'Track daily to start a streak',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _isDark ? Colors.white.withOpacity(.85) : Colors.black.withOpacity(.7),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 14),
                              ReorderableListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _trackers.length,
                                onReorder: (oldIndex, newIndex) async {
                                  setState(() {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final t = _trackers.removeAt(oldIndex);
                                    _trackers.insert(newIndex, t);
                                  });
                                  await _persistOrder();
                                },
                                itemBuilder: (context, i) {
                                  final t = _trackers[i];
                                  return Column(
                                    key: ValueKey(t.id),
                                    children: [
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 105,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                              child: Text(
                                                t.label,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Text(
                                                  _emojiForTick[0.0] ?? "🙂",
                                                  style: const TextStyle(fontSize: 20),
                                                ),
                                                Expanded(
                                                  child: SliderTheme(
                                                    data: SliderTheme.of(context).copyWith(
                                                      trackHeight: 8,
                                                      thumbShape: const RoundSliderThumbShape(
                                                        enabledThumbRadius: 8,
                                                      ),
                                                    ),
                                                    child: Slider(
                                                      value: t.value,
                                                      min: 0,
                                                      max: 10,
                                                      divisions: 20,
                                                      activeColor: t.color,
                                                      onChanged: (v) => _recordTrackerValue(t, v),
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  _emojiForTick[10.0] ?? "😭",
                                                  style: const TextStyle(fontSize: 20),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            color: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            elevation: 6,
                                            offset: const Offset(0, 8),
                                            onSelected: (v) async {
                                              if (v == 'rename') {
                                                final ctl = TextEditingController(text: t.label);
                                                await showDialog(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    title: const Text('Rename tracker'),
                                                    content: TextField(
                                                      controller: ctl,
                                                      decoration:
                                                          const InputDecoration(hintText: 'Name'),
                                                      autofocus: true,
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context),
                                                        child: const Text('Cancel'),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () async {
                                                          final v2 = ctl.text.trim();
                                                          if (v2.isNotEmpty) {
                                                            setState(() => t.label = v2);
                                                            await _updateTracker(t, label: v2);
                                                          }
                                                          if (context.mounted) Navigator.pop(context);
                                                        },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF0D7C66),
                                                          foregroundColor: Colors.white,
                                                        ),
                                                        child: const Text('Save'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              } else if (v == 'color') {
                                                await _openColorPicker(t);
                                                await _updateTracker(t, color: t.color);
                                              } else if (v == 'delete') {
                                                final ok = await showDialog<bool>(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    title: const Text('Delete tracker?'),
                                                    content: Text(
                                                      'This will remove "${t.label}" from your trackers.',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(context, false),
                                                        child: const Text('Cancel'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(context, true),
                                                        style: TextButton.styleFrom(
                                                          foregroundColor: Colors.red,
                                                        ),
                                                        child: const Text('Delete'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (ok == true) {
                                                  await _deleteTracker(t);
                                                }
                                              }
                                            },
                                            itemBuilder: (c) => const [
                                              PopupMenuItem(
                                                value: 'rename',
                                                child: Text('Rename'),
                                              ),
                                              PopupMenuItem(
                                                value: 'color',
                                                child: Text('Color'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text(
                                                  'Delete',
                                                  style: TextStyle(color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              Showcase(
                                key: OBKeys.addHabit,
                                description: 'Tap here to add your first habit tracker.',
                                disposeOnTap: true,
                                onTargetClick: () {},
                                onToolTipClick: () {},
                                onBarrierClick: () {},
                                child: IconButton(
                                  tooltip: 'Add tracker',
                                  onPressed: () => _createTracker(label: 'add tracker'),
                                  icon: const Icon(Icons.add_circle_outline, size: 28),
                                  color: const Color(0xFF0D7C66),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Showcase(
                                key: OBKeys.chartSelector,
                                description: 'Switch between Weekly, Monthly, or Overall views.',
                                disposeOnTap: true,
                                onTargetClick: () {},
                                onToolTipClick: () {},
                                onBarrierClick: () {},
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: ChartView.values.map((v) {
                                    final sel = v == _view;
                                    String lbl = switch (v) {
                                      ChartView.weekly => 'Weekly',
                                      ChartView.monthly => 'Monthly',
                                      ChartView.overall => 'Overall',
                                    };
                                    final dark = app.ThemeControllerScope.of(context).isDark;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: ChoiceChip(
                                        label: Text(
                                          lbl,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: dark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        selected: sel,
                                        showCheckmark: false,
                                        selectedColor: dark
                                            ? const Color(0xFF0D7C66).withOpacity(.55)
                                            : const Color(0xFF0D7C66).withOpacity(.15),
                                        backgroundColor: dark
                                            ? Colors.white.withOpacity(.08)
                                            : Colors.black.withOpacity(.04),
                                        side: dark
                                            ? BorderSide(
                                                color: sel
                                                    ? Colors.transparent
                                                    : Colors.white.withOpacity(.28),
                                              )
                                            : BorderSide.none,
                                        onSelected: (_) => setState(() => _view = v),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        _dateRangeHeading(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black.withOpacity(.75),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.emoji_emotions_outlined),
                                    color: const Color(0xFF0D7C66),
                                    tooltip: 'Customize emojis',
                                    onPressed: _openEmojiPicker,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                                    color: const Color(0xFF0D7C66),
                                    onPressed: _openSelectDialog,
                                    tooltip: 'Select trackers to view',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                height: 340,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.55),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 6),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 44),
                                        child: _selectedForChart.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'Select trackers to view',
                                                  style: TextStyle(fontSize: 13),
                                                ),
                                              )
                                            : LineChart(_chartData()),
                                      ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.insights_outlined),
                                        label: const Text(
                                          'More insights',
                                          style: TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(0xFF0D7C66),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            NoTransitionPageRoute(
                                              builder: (_) => SummariesPage(userName: widget.userName),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                      _BottomNav(index: 0, userName: widget.userName),
                    ],
                  ),
                ),
              ),

              // Rez sidebar overlay widget (scrim + panel + handle)
              RezSidebar(
                isOpen: _rezPanelOpen,
                panelWidth: _rezPanelWidth,
                rezBalance: _rezBalance,
                rezHistory: _rezHistory,
                userName: widget.userName,
                profilePhotoUrl: _profilePhotoUrl,
                isDark: _isDark,
                onOpen: () => setState(() => _rezPanelOpen = true),
                onClose: () => setState(() => _rezPanelOpen = false),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSelectDialog() async {
    final chosen = Set<String>.from(_selectedForChart);

    await showDialog(
      context: context,
      builder: (ctx) {
        final dark = app.ThemeControllerScope.of(context).isDark;
        final bg = dark ? const Color(0xFF102D29) : Colors.white;
        final surface = dark ? const Color(0xFF123A36) : const Color(0xFFF4F6F6);
        final accent = const Color(0xFF0D7C66);
        final textColor = dark ? Colors.white : const Color(0xFF20312F);

        String query = '';
        final searchCtl = TextEditingController();

        return Dialog(
          backgroundColor: bg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              final filtered =
                  _trackers.where((t) => t.label.toLowerCase().contains(query.toLowerCase())).toList();

              void toggle(String id, bool v) {
                if (v) {
                  chosen.add(id);
                } else {
                  chosen.remove(id);
                }
                setSheet(() {});
              }

              final allSelected = chosen.length == _trackers.length && _trackers.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Select trackers to view',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            if (allSelected) {
                              chosen.clear();
                            } else {
                              chosen
                                ..clear()
                                ..addAll(_trackers.map((e) => e.id));
                            }
                            setSheet(() {});
                          },
                          child: Text(
                            allSelected ? 'Clear' : 'Select all',
                            style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: searchCtl,
                        onChanged: (v) => setSheet(() => query = v),
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search trackers',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No trackers found',
                                style: TextStyle(color: textColor.withOpacity(.7)),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final t = filtered[i];
                                final checked = chosen.contains(t.id);
                                return CheckboxListTile(
                                  value: checked,
                                  onChanged: (v) => toggle(t.id, v ?? false),
                                  activeColor: t.color,
                                  title: Text(
                                    t.label,
                                    style: TextStyle(
                                      fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  visualDensity: const VisualDensity(vertical: -4),
                                  side: const BorderSide(color: Colors.black26, width: 1),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: textColor.withOpacity(.8)),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _selectedForChart
                                  ..clear()
                                  ..addAll(chosen);
                              });
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D7C66),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                            ),
                            label: const Text(
                              'Done (selected)',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openColorPicker(Tracker t) async {
    HSVColor hsv = HSVColor.fromColor(t.color);

    Color _fromHex(String s) {
      var h = s.trim().replaceAll('#', '');
      if (h.length == 6) h = 'FF$h';
      final v = int.parse(h, radix: 16);
      return Color(v);
    }

    final prefs = await SharedPreferences.getInstance();
    final hexCtl = TextEditingController(text: '');

    List<Color> recentColors =
        (prefs.getStringList('recent_colors') ?? []).map((e) => Color(int.parse(e))).toList();

    void _saveRecent(Color c) async {
      recentColors.removeWhere((x) => x.value == c.value);
      recentColors.insert(0, c);
      if (recentColors.length > 6) {
        recentColors = recentColors.sublist(0, 6);
      }
      await prefs.setStringList('recent_colors', recentColors.map((c) => c.value.toString()).toList());
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        final dark = app.ThemeControllerScope.of(context).isDark;
        return StatefulBuilder(
          builder: (context, setSheet) {
            void setHueFromOffset(Offset localPos, Size size) {
              final center = Offset(size.width / 2, size.height / 2);
              final vec = localPos - center;
              var ang = atan2(vec.dy, vec.dx);
              ang = (ang < 0) ? (ang + 2 * pi) : ang;
              final deg = ang * 180 / pi;
              setSheet(() => hsv = hsv.withHue(deg));
            }

            return Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF123A36) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    width: 44,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const Text('Pick color', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    width: 220,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final size = Size(c.maxWidth, c.maxHeight);
                        const ringWidth = 18.0;
                        final radius = size.width / 2 - ringWidth / 2;
                        final rad = hsv.hue * pi / 180;
                        final knob =
                            Offset(size.width / 2 + cos(rad) * radius, size.height / 2 + sin(rad) * radius);
                        final innerDiameter = size.width - ringWidth * 2;
                        final squareSize = innerDiameter * 0.60;

                        return GestureDetector(
                          onPanDown: (d) => setHueFromOffset(d.localPosition, size),
                          onPanUpdate: (d) => setHueFromOffset(d.localPosition, size),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: size,
                                painter: _HueRingPainter(ringWidth: ringWidth),
                              ),
                              SizedBox(
                                width: squareSize,
                                height: squareSize,
                                child: _SVSquare(
                                  hue: hsv.hue,
                                  s: hsv.saturation,
                                  v: hsv.value,
                                  onChanged: (s, v) => setSheet(() {
                                    hsv = hsv.withSaturation(s).withValue(v);
                                  }),
                                ),
                              ),
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _KnobPainter(position: knob, r: 6),
                                  size: size,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: hsv.toColor(),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black26),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('#', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: hexCtl,
                          onChanged: (v) {
                            final txt = v.trim();
                            if (RegExp(r'^[0-9a-fA-F]{6,8}$').hasMatch(txt)) {
                              setSheet(() => hsv = HSVColor.fromColor(_fromHex(txt)));
                            }
                          },
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'RRGGBB',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () {
                          final chosen = hsv.toColor();
                          setState(() => t.color = chosen);
                          _saveRecent(chosen);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D7C66),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RezTransaction {
  final int amount;
  final String description;
  final DateTime timestamp;

  _RezTransaction({
    required this.amount,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'description': description,
        'timestamp': timestamp,
      };

  factory _RezTransaction.fromMap(Map<String, dynamic> map) {
    final rawTs = map['timestamp'];
    DateTime ts;
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is DateTime) {
      ts = rawTs;
    } else if (rawTs is String) {
      ts = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }
    return _RezTransaction(
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      description: (map['description'] ?? '') as String,
      timestamp: ts,
    );
  }
}

/// Reusable Rez sidebar overlay: scrim + panel + handle
class RezSidebar extends StatelessWidget {
  final bool isOpen;
  final double panelWidth;
  final int rezBalance;
  final List<_RezTransaction> rezHistory;
  final String userName;
  final String? profilePhotoUrl;
  final bool isDark;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const RezSidebar({
    super.key,
    required this.isOpen,
    required this.panelWidth,
    required this.rezBalance,
    required this.rezHistory,
    required this.userName,
    required this.profilePhotoUrl,
    required this.isDark,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // Scrim
        if (isOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: Container(
                color: Colors.black.withOpacity(0.25),
              ),
            ),
          ),

        // Panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          left: isOpen ? 0 : -panelWidth,
          top: 0,
          bottom: 0,
          child: SafeArea(
            child: Container(
              width: panelWidth,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? [
                          const Color(0xFF0B2522).withOpacity(0.90),
                          const Color(0xFF0D7C66).withOpacity(0.82),
                        ]
                      : [
                          const Color(0xFFFFFFFF).withOpacity(0.90),
                          const Color(0xFFF5F5F5).withOpacity(0.82),
                        ],
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(4, 0),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close button at top-right, no circle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 6, 6, 4),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: dark ? Colors.white70 : Colors.black87,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onClose,
                      ),
                    ),
                  ),

                  // Header with avatar + label
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              dark ? Colors.white.withOpacity(.12) : const Color(0xFFE4F3F0),
                          backgroundImage: profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty
                              ? NetworkImage(profilePhotoUrl!)
                              : null,
                          child: (profilePhotoUrl == null || profilePhotoUrl!.isEmpty)
                              ? const Icon(Icons.person, size: 30, color: Color(0xFF0D7C66))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: dark ? Colors.white : Colors.black,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Premium or regular plan - ADD LATER',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: dark ? Colors.white70 : Colors.black54,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Rez balance row (no background card)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: dark ? Colors.white70 : const Color(0xFF0D7C66),
                              width: 1.6,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.diamond, size: 20, color: Color(0xFF0D7C66)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$rezBalance Rez',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: dark ? Colors.white : Colors.black,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Current balance',
                              style: TextStyle(
                                fontSize: 11,
                                color: dark ? Colors.white70 : Colors.black54,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Recent activity',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: dark ? Colors.white70 : Colors.black87,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Expanded(
                    child: rezHistory.isEmpty
                        ? Center(
                            child: Text(
                              'No Rez activity yet',
                              style: TextStyle(
                                fontSize: 12,
                                color: dark ? Colors.white60 : Colors.black54,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            itemCount: rezHistory.length,
                            itemBuilder: (context, index) {
                              final tx = rezHistory[index];
                              final isGain = tx.amount >= 0;
                              final sign = isGain ? '+' : '';
                              final color =
                                  isGain ? const Color(0xFF0D7C66) : Colors.redAccent;
                              final timeStr =
                                  DateFormat('MMM d • h:mm a').format(tx.timestamp);
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      isGain ? Icons.trending_up : Icons.trending_down,
                                      size: 18,
                                      color: color,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.description,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: dark ? Colors.white : Colors.black,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: dark ? Colors.white60 : Colors.black54,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.diamond, size: 16),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$sign${tx.amount}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: color,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // iOS-style slim line handle tab
        if (!isOpen)
          Positioned(
            left: 0,
            top: (screenHeight / 2) - 40, // vertically centered (height 80)
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx > 6) {
                  onOpen();
                }
              },
              onTap: onOpen,
              child: SizedBox(
                width: 20,
                height: 80,
                child: Center(
                  child: Container(
                    width: 3.5,
                    height: 46,
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF707070)
                          : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HueRingPainter extends CustomPainter {
  _HueRingPainter({required this.ringWidth});
  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const SweepGradient(
        colors: <Color>[
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF00FFFF),
          Color(0xFF0000FF),
          Color(0xFFFF00FF),
          Color(0xFFFF0000),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;
    final radius = min(size.width, size.height) / 2 - ringWidth / 2;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
  }

  @override
  bool shouldRepaint(covariant _HueRingPainter oldDelegate) => false;
}

class _KnobPainter extends CustomPainter {
  _KnobPainter({required this.position, this.r = 8});
  final Offset position;
  final double r;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final b = Paint()
      ..color = Colors.black.withOpacity(.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(position, r, p);
    canvas.drawCircle(position, r, b);
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) =>
      oldDelegate.position != position || oldDelegate.r != r;
}

class _SVSquare extends StatelessWidget {
  const _SVSquare({
    required this.hue,
    required this.s,
    required this.v,
    required this.onChanged,
  });

  final double hue;
  final double s;
  final double v;
  final void Function(double s, double v) onChanged;

  @override
  Widget build(BuildContext context) {
    final base = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final knob = Offset(s * size.width, (1 - v) * size.height);

        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition, size),
          onPanUpdate: (d) => _update(d.localPosition, size),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.white, base],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                foregroundDecoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
              ),
              Positioned(
                left: knob.dx - 8,
                top: knob.dy - 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _update(Offset p, Size size) {
    var ss = (p.dx / size.width).clamp(0.0, 1.0);
    var vv = (1 - p.dy / size.height).clamp(0.0, 1.0);
    onChanged(ss, vv);
  }
}

class NoTransitionPageRoute<T> extends MaterialPageRoute<T> {
  NoTransitionPageRoute({required WidgetBuilder builder}) : super(builder: builder);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class _HeaderShadowIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderShadowIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(icon, size: 26, color: green),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final String userName;
  const _BottomNav({required this.index, required this.userName});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);
    const darkSelected = Color(0xFFBDA9DB);

    Color c(int i) {
      final dark = app.ThemeControllerScope.of(context).isDark;
      if (i == index) return dark ? darkSelected : green;
      return Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.home, color: c(0)),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.menu_book, color: c(1)),
            onPressed: () => Navigator.pushReplacement(
              context,
              NoTransitionPageRoute(
                builder: (_) => JournalPage(userName: userName),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.widgets_rounded, color: c(2)),
            onPressed: () => Navigator.pushReplacement(
              context,
              NoTransitionPageRoute(
                builder: (_) => ToolsPage(userName: userName),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
