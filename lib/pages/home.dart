// lib/pages/home.dart
import 'dart:math';
import 'dart:ui' show FontFeature, ImageFilter;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding.dart';
import 'onboarding_keys';
import 'package:showcaseview/showcaseview.dart';

import 'package:new_rezonate/main.dart' as app;
import 'journal.dart';
import 'settings.dart';

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
  // ---- Firebase
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  User? get _user => _auth.currentUser;

  // ---- Local UI state
  final _rnd = Random();
  List<Tracker> _trackers = [];
  final Set<String> _selectedForChart = {};
  ChartView _view = ChartView.weekly;

  // day-key -> values map; also used to compute streak
  final Map<String, Map<String, double>> _daily = {};
  final Set<String> _daysWithAnyLog = {};

  // Most recent log across all days (for 24h grace when no "today" log)
  DateTime? _lastLogAt;

  // To enforce strict 24h rule even when there IS a log today
  DateTime? _firstLogTodayAt; // earliest log time for "today"
  DateTime? _lastLogBeforeTodayAt; // most recent log time BEFORE "today"

  // ---- Custom emoji scale (applies to sliders & chart Y-axis)
  final List<int> _emojiTicks = const [0, 2, 4, 6, 8, 10];
  final Map<int, String> _defaultEmojis = const {
    0: "😄",
    2: "🙂",
    4: "😐",
    6: "😕",
    8: "☹️",
    10: "😢",
  };
  late Map<int, String> _emojiForTick = Map<int, String>.from(_defaultEmojis);

  // ---- Lifecycle
  @override
  void initState() {
    super.initState();
    _bootstrap().then((_) => _maybeStartHomeShowcase());
    _loadEmojis(); // load user custom emojis
  }

  Future<void> _loadEmojis() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<int, String> loaded = {};
    for (final t in _emojiTicks) {
      loaded[t] = prefs.getString('emoji_tick_$t') ?? _defaultEmojis[t]!;
    }
    setState(() => _emojiForTick = loaded);
  }

  Future<void> _saveEmojis(Map<int, String> next) async {
    final prefs = await SharedPreferences.getInstance();
    for (final t in _emojiTicks) {
      await prefs.setString('emoji_tick_$t', next[t] ?? _defaultEmojis[t]!);
    }
    setState(() => _emojiForTick = Map<int, String>.from(next));
  }

  Future<void> _openEmojiPicker() async {
    final Map<int, String> draft = Map<int, String>.from(_emojiForTick);
    final controllers = {
      for (final t in _emojiTicks) t: TextEditingController(text: draft[t])
    };

    await showDialog(
      context: context,
      builder: (ctx) {
        final dark = app.ThemeControllerScope.of(context).isDark;
        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF123A36) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Customize emoji scale'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'These emojis label the mood/value range at 0–10.\nUsed on sliders (ends) and Y-axis of the chart.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 12),
                for (final t in _emojiTicks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 54,
                          child: Text(
                            t == 0 || t == 10 ? '$t (end)' : '$t',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: controllers[t],
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Enter emoji (e.g., 🙂)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (v) => draft[t] = v.trim().isEmpty
                                ? _defaultEmojis[t]!
                                : v.trim(),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        // reset to defaults
                        for (final t in _emojiTicks) {
                          controllers[t]!.text = _defaultEmojis[t]!;
                          draft[t] = _defaultEmojis[t]!;
                        }
                        setState(() {});
                      },
                      child: const Text('Reset to default'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
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
    final stage = await Onboarding.getStage();

    // If first run, start at home intro
    if (stage == OnboardingStage.notStarted) {
      await Onboarding.setStage(OnboardingStage.homeIntro);
    }

    if (!mounted) return;

    if (stage == OnboardingStage.notStarted ||
        stage == OnboardingStage.homeIntro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase([
          OBKeys.addHabit,
          OBKeys.chartSelector,
          OBKeys.journalTab,
          OBKeys.settingsTab,
        ]);
      });
    }
  }

  Future<void> _bootstrap() async {
    final u = _user;
    if (u == null) return;

    // --- Trackers live snapshot
    _db
        .collection('users')
        .doc(u.uid)
        .collection('trackers')
        .orderBy('sort')
        .snapshots()
        .listen((snap) async {
      final list = snap.docs.map(Tracker.fromDoc).toList();

      // Update local state first
      setState(() {
        _trackers = list;
        _selectedForChart
          ..clear()
          ..addAll(_trackers.map((t) => t.id));
      });

      // Onboarding decisions
      final stage = await Onboarding.getStage();

      if (list.isEmpty) {
        // Do NOT auto-create a tracker; guide user to create the first one.
        if (stage == OnboardingStage.notStarted) {
          await Onboarding.setStage(OnboardingStage.homeIntro);
        } else if (stage.index < OnboardingStage.needFirstHabit.index) {
          await Onboarding.setStage(OnboardingStage.needFirstHabit);
        }

        // Start the intro on home; first cue is "Add Habit"
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // If user has 0 trackers, emphasize the add button first.
            ShowCaseWidget.of(context).startShowCase([
              OBKeys.addHabit,
              OBKeys.chartSelector,
              OBKeys.journalTab,
              OBKeys.settingsTab,
            ]);
          });
        }
      } else {
        // User already has at least one tracker; advance onboarding if needed.
        if (stage == OnboardingStage.homeIntro ||
            stage == OnboardingStage.needFirstHabit) {
          await Onboarding.markHabitCreated();
        }

        // If we’re still in the intro stage, start (or continue) the home tour.
        final nextStage = await Onboarding.getStage();
        if (mounted &&
            (stage == OnboardingStage.notStarted ||
                stage == OnboardingStage.homeIntro)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ShowCaseWidget.of(context).startShowCase([
              // Skip addHabit since they already have one, but harmless if left in.
              OBKeys.chartSelector,
              OBKeys.journalTab,
              OBKeys.settingsTab,
            ]);
          });
        }
      }
    });

    // --- Pull last 120 days of logs and keep in memory
    _db
        .collection('users')
        .doc(u.uid)
        .collection('daily_logs')
        .orderBy('day', descending: false)
        .limit(120)
        .snapshots()
        .listen((snap) {
      final map = <String, Map<String, double>>{};
      final daysWithLogs = <String>{};

      DateTime? newest; // most recent updatedAt across docs
      DateTime? firstToday; // earliest log today
      DateTime? prevBeforeToday; // last log before today

      final todayKey = _dayKey(DateTime.now());

      for (final d in snap.docs) {
        final m = d.data();
        final vals =
            (m['values'] as Map?)
                    ?.map((k, v) => MapEntry('$k', (v as num).toDouble())) ??
                <String, double>{};
        map[d.id] = vals.cast<String, double>();
        if (vals.isNotEmpty) daysWithLogs.add(d.id);

        final ts =
            (m['updatedAt'] is Timestamp) ? (m['updatedAt'] as Timestamp).toDate() : null;
        if (ts != null) {
          if (newest == null || ts.isAfter(newest)) newest = ts;
        } else if (vals.isNotEmpty) {
          final dayInt = (m['day'] as num?)?.toInt();
          if (dayInt != null) {
            final int y = dayInt ~/ 10000;
            final int mo = (dayInt % 10000) ~/ 100;
            final int da = dayInt % 100;
            final fallback = DateTime(y, mo, da, 23, 59, 59);
            if (newest == null || fallback.isAfter(newest)) newest = fallback;
          }
        }

        if (d.id == todayKey) {
          final f =
              (m['firstAt'] is Timestamp) ? (m['firstAt'] as Timestamp).toDate() : null;
          if (f != null) firstToday = f;
        } else {
          if (ts != null) {
            if (prevBeforeToday == null || ts.isAfter(prevBeforeToday)) {
              prevBeforeToday = ts;
            }
          }
        }
      }

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

  // ---- Helpers
  String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  List<DateTime> _currentWeekMonToSun() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: (now.weekday - DateTime.monday)));
    return List.generate(
      7,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
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

  // Strict 24h break enforcement + "starts after a day" rule
  int get _streak {
    if (_daysWithAnyLog.isEmpty) return 0;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final todayKey = _dayKey(now);
    final hasToday = _daysWithAnyLog.contains(todayKey);

    final within24h =
        _lastLogAt != null && now.difference(_lastLogAt!).inHours < 24;
    if (!hasToday && !within24h) {
      // >24h since any log → streak broken
      return 0;
    }

    bool brokeBetweenYesterdayAndToday = false;
    if (hasToday && _firstLogTodayAt != null && _lastLogBeforeTodayAt != null) {
      final gap = _firstLogTodayAt!.difference(_lastLogBeforeTodayAt!).inHours;
      if (gap > 24) brokeBetweenYesterdayAndToday = true;
    }

    int consecutive = 0;
    var d = todayMidnight;
    bool graceForToday = !hasToday && within24h;

    while (true) {
      final key = _dayKey(d);
      final isYesterday =
          d.isAtSameMomentAs(todayMidnight.subtract(const Duration(days: 1)));
      final filled =
          _daysWithAnyLog.contains(key) ||
          (graceForToday && d.isAtSameMomentAs(todayMidnight));

      if (isYesterday && brokeBetweenYesterdayAndToday) break;
      if (!filled) break;

      consecutive++;
      graceForToday = false;
      d = d.subtract(const Duration(days: 1));
    }

    // Require at least 2 filled days; display consecutive-1
    if (consecutive <= 1) return 0;
    return consecutive - 1;
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

  // ---- Firestore writes
  Future<void> _createTracker({required String label}) async {
    final u = _user;
    if (u == null) return;
    final id = 't${DateTime.now().microsecondsSinceEpoch}';
    final color = const Color(0xFF0D7C66);
    final sort = _trackers.length;
    final t = Tracker(id: id, label: label, color: color, value: 5, sort: sort);
    await _db
        .collection('users')
        .doc(u.uid)
        .collection('trackers')
        .doc(id)
        .set(t.toMap());
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
    await _db
        .collection('users')
        .doc(u.uid)
        .collection('trackers')
        .doc(t.id)
        .set(data, SetOptions(merge: true));
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

    // local
    final now = DateTime.now();
    final key = _dayKey(now);
    _daily.putIfAbsent(key, () => {});
    _daily[key]![t.id] = v;
    _daysWithAnyLog.add(key);
    _lastLogAt = now;
    _firstLogTodayAt ??= now;
    setState(() => t.value = v);

    // remote
    final dayInt = int.parse(DateFormat('yyyyMMdd').format(now));
    final docRef =
        _db.collection('users').doc(u.uid).collection('daily_logs').doc(key);
    final snap = await docRef.get();

    final data = <String, dynamic>{
      'day': dayInt,
      'values': {t.id: v},
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snap.exists || !(snap.data()?['firstAt'] is Timestamp))
        'firstAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data, SetOptions(merge: true));
    await _updateTracker(t, latest: v);
  }

  Future<void> _deleteTracker(Tracker t) async {
    final u = _user;
    if (u == null) return;
    await _db
        .collection('users')
        .doc(u.uid)
        .collection('trackers')
        .doc(t.id)
        .delete();
    setState(() {
      _trackers.removeWhere((x) => x.id == t.id);
      _selectedForChart.remove(t.id);
    });
  }

  // ---- Chart helpers
  List<double> _valuesForDates(Tracker t, List<DateTime> days) {
    return days.map((d) => _daily[_dayKey(d)]?[t.id] ?? 0.0).toList();
  }

  String _dateRangeHeading() {
    if (_view == ChartView.weekly) {
      final days = _currentWeekMonToSun();
      final a =
          '${DateFormat('MMM').format(days.first)} ${_ordinal(days.first.day)}';
      final b =
          '${DateFormat('MMM').format(days.last)} ${_ordinal(days.last.day)}';
      return '$a – $b';
    } else if (_view == ChartView.monthly) {
      final days = _lastNDays(28);
      final a =
          '${DateFormat('MMM').format(days.first)} ${_ordinal(days.first.day)}';
      final b =
          '${DateFormat('MMM').format(days.last)} ${_ordinal(days.last.day)}';
      return 'Last 28 days • $a – $b';
    } else {
      final days = _lastNDays(84);
      final a =
          '${DateFormat('MMM').format(days.first)} ${_ordinal(days.first.day)}';
      final b =
          '${DateFormat('MMM').format(days.last)} ${_ordinal(days.last.day)}';
      return 'Last 12 weeks • $a – $b';
    }
  }

  LineChartData _chartData() {
    final sel =
        _trackers.where((t) => _selectedForChart.contains(t.id)).toList();

    late List<double> xPoints;
    final List<List<double>> seriesValues = [];

    if (_view == ChartView.weekly) {
      final days = _currentWeekMonToSun();
      xPoints = List.generate(days.length, (i) => i.toDouble());
      for (final t in sel) {
        seriesValues.add(_valuesForDates(t, days));
      }
    } else if (_view == ChartView.monthly) {
      final days = _lastNDays(28);
      xPoints = [0, 1, 2, 3];
      for (final t in sel) {
        final vals = _valuesForDates(t, days);
        final chunks = [
          vals.sublist(0, 7),
          vals.sublist(7, 14),
          vals.sublist(14, 21),
          vals.sublist(21, 28),
        ];
        seriesValues.add(
          chunks
              .map<double>(
                (w) => w.isEmpty ? 0.0 : w.reduce((a, b) => a + b) / w.length,
              )
              .toList(),
        );
      }
    } else {
      final days = _lastNDays(84);
      xPoints = [0, 1, 2, 3];
      for (final t in sel) {
        final vals = _valuesForDates(t, days);
        const size = 21;
        final chunks = [
          vals.sublist(0, size),
          vals.sublist(size, size * 2),
          vals.sublist(size * 2, size * 3),
          vals.sublist(size * 3, size * 4),
        ];
        seriesValues.add(
          chunks
              .map<double>(
                (w) => w.isEmpty ? 0.0 : w.reduce((a, b) => a + b) / w.length,
              )
              .toList(),
        );
      }
    }

    const double yPad = 2.0;
    const double xPad = 0.8;
    final double minX = (xPoints.isEmpty ? 0 : xPoints.first) - xPad;
    final double maxX = (xPoints.isEmpty ? 0 : xPoints.last) + xPad;
    const double minY = 0 - yPad;
    const double maxY = 10 + yPad;

    final bars = <LineChartBarData>[];
    for (int s = 0; s < sel.length; s++) {
      final t = sel[s];
      final vals = seriesValues[s];
      final spots = <FlSpot>[
        for (int i = 0; i < xPoints.length; i++) FlSpot(xPoints[i], vals[i]),
      ];
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 3,
          color: t.color,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [t.color.withOpacity(.25), t.color.withOpacity(.02)],
            ),
          ),
        ),
      );
    }

    return LineChartData(
      minX: -0.3,
      maxX: _view == ChartView.weekly ? 7 : 4,
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 2,
        getDrawingHorizontalLine:
            (v) => FlLine(strokeWidth: 0.6, color: Colors.black12),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 2,
            getTitlesWidget: (value, meta) {
              final v = value.toInt();
              if (_emojiForTick.containsKey(v)) {
                return Text(
                  _emojiForTick[v]!,
                  style: const TextStyle(fontSize: 20),
                );
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
              if (_view == ChartView.weekly) {
                final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
                if (value >= 0 && value < days.length) {
                  return Text(
                    days[value.toInt()],
                    style: const TextStyle(fontSize: 12.5),
                  );
                }
              } else if (_view == ChartView.monthly) {
                final weeks = ["Week 1", "Week 2", "Week 3", "Week 4"];
                if (value >= 0 && value < 4) {
                  return Text(
                    weeks[value.toInt()],
                    style: const TextStyle(fontSize: 12),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: bars,
      clipData: const FlClipData.all(),
    );
  }

  // ---- UI
  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);
    final now = DateTime.now();
    final dateLine = DateFormat('EEEE • MMM d, yyyy').format(now);
    final streakNow = _streak;
    final bool _isDark = app.ThemeControllerScope.of(context).isDark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: _bg(context)),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ===== Logo with green glow + green-tinted logo in dark mode =====
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
                                    imageFilter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: ColorFiltered(
                                      colorFilter: ColorFilter.mode(
                                        const Color(0xFF0D7C66)
                                            .withOpacity(0.85),
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
                                      colorFilter: const ColorFilter.mode(
                                        Color(0xFF0D7C66), // dark green logo tint
                                        BlendMode.srcATop,
                                      ),
                                      child: Image.asset(
                                        'assets/images/Logo.png',
                                        height: 72,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.flash_on,
                                          size: 72,
                                          color: green.withOpacity(.85),
                                        ),
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/images/Logo.png',
                                      height: 72,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.flash_on,
                                        size: 72,
                                        color: green.withOpacity(.85),
                                      ),
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

                      // ===== Streak pill (dark mode toned down) =====
                      if (streakNow > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _isDark
                                ? const Color(0xFF0D7C66).withOpacity(.14) // less pop
                                : Colors.white.withOpacity(.9),
                            borderRadius: BorderRadius.circular(24),
                            border: _isDark
                                ? Border.all(
                                    color: Colors.white.withOpacity(.10),
                                  )
                                : null,
                            boxShadow: [
                              if (_isDark)
                                ...[] // no shadow in dark to reduce pop
                              else
                                const BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                ),
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
                              color: _isDark
                                  ? Colors.white.withOpacity(.85)
                                  : Colors.black.withOpacity(.7),
                            ),
                          ),
                        ),

                      const SizedBox(height: 14),

                      // Trackers list
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
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
                                          _emojiForTick[0] ?? "😄",
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                              trackHeight: 8,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                enabledThumbRadius: 8,
                                              ),
                                            ),
                                            child: Slider(
                                              value: t.value,
                                              min: 0,
                                              max: 10,
                                              divisions: 20,
                                              activeColor: t.color,
                                              onChanged: (v) =>
                                                  _recordTrackerValue(t, v),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _emojiForTick[10] ?? "😢",
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
                                        final ctl = TextEditingController(
                                          text: t.label,
                                        );
                                        await showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            title:
                                                const Text('Rename tracker'),
                                            content: TextField(
                                              controller: ctl,
                                              decoration:
                                                  const InputDecoration(
                                                hintText: 'Name',
                                              ),
                                              autofocus: true,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  final v2 = ctl.text.trim();
                                                  if (v2.isNotEmpty) {
                                                    setState(
                                                        () => t.label = v2);
                                                    await _updateTracker(t,
                                                        label: v2);
                                                  }
                                                  if (context.mounted)
                                                    Navigator.pop(context);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFF0D7C66),
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
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            title:
                                                const Text('Delete tracker?'),
                                            content: Text(
                                              'This will remove "${t.label}" from your trackers.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context, true),
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
                                  const Icon(Icons.drag_indicator, size: 18),
                                ],
                              ),
                              //const Divider(height: 0, indent: 4, endIndent: 4),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 14),
                      // Plus under trackers
                      IconButton(
                        tooltip: 'Add tracker',
                        onPressed: () => _createTracker(label: 'add tracker'),
                        icon: const Icon(Icons.add_circle_outline, size: 28),
                        color: const Color(0xFF0D7C66),
                      ),

                      const SizedBox(height: 24),

                      // View selector (higher contrast in dark mode)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: ChartView.values.map((v) {
                          final sel = v == _view;
                          String lbl = switch (v) {
                            ChartView.weekly => 'Weekly',
                            ChartView.monthly => 'Monthly',
                            ChartView.overall => 'Overall',
                          };
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: ChoiceChip(
                              label: Text(
                                lbl,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              selected: sel,
                              showCheckmark: false,
                              selectedColor: _isDark
                                  ? const Color(0xFF0D7C66).withOpacity(.55)
                                  : const Color(0xFF0D7C66).withOpacity(.15),
                              backgroundColor: _isDark
                                  ? Colors.white.withOpacity(.08)
                                  : Colors.black.withOpacity(.04),
                              side: _isDark
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

                      const SizedBox(height: 8),

                      // Date range + dropdown icon (selection dialog) + emoji scale editor
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
                          // Open emoji scale editor (small, unobtrusive)
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions_outlined),
                            color: const Color(0xFF0D7C66),
                            tooltip: 'Customize emojis',
                            onPressed: _openEmojiPicker,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_drop_down_circle_outlined,
                            ),
                            color: const Color(0xFF0D7C66),
                            onPressed: _openSelectDialog,
                            tooltip: 'Select trackers to view',
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Chart card
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        height: 320,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.55),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6),
                          ],
                        ),
                        child: _selectedForChart.isEmpty
                            ? const Center(
                                child: Text(
                                  'Select trackers to view',
                                  style: TextStyle(fontSize: 13),
                                ),
                              )
                            : LineChart(_chartData()),
                      ),
                    ],
                  ),
                ),
              ),

              _BottomNav(index: 0, userName: widget.userName),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Select trackers dialog (clean, obvious selection, searchable)
  Future<void> _openSelectDialog() async {
    final chosen = Set<String>.from(_selectedForChart);

    await showDialog(
      context: context,
      builder: (ctx) {
        final dark = app.ThemeControllerScope.of(context).isDark;
        final bg = dark ? const Color(0xFF102D29) : Colors.white;
        final surface =
            dark ? const Color(0xFF123A36) : const Color(0xFFF4F6F6);
        final accent = const Color(0xFF0D7C66);
        final textColor = dark ? Colors.white : const Color(0xFF20312F);

        String query = '';
        final searchCtl = TextEditingController();

        return Dialog(
          backgroundColor: bg,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              final filtered =
                  _trackers
                      .where(
                        (t) =>
                            t.label.toLowerCase().contains(query.toLowerCase()),
                      )
                      .toList();

              void toggle(String id, bool v) {
                if (v) {
                  chosen.add(id);
                } else {
                  chosen.remove(id);
                }
                setSheet(() {});
              }

              final allSelected =
                  chosen.length == _trackers.length && _trackers.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Select trackers to view',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
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
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
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
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),

                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No trackers found',
                                style: TextStyle(
                                  color: textColor.withOpacity(.7),
                                ),
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
                                      fontWeight: checked
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  visualDensity:
                                      const VisualDensity(vertical: -4),
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
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                            ),
                            label: Text(
                              'Done (${chosen.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
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

  // ---- Color picker bits -------------------------------------------------
  Future<void> _openColorPicker(Tracker t) async {
    HSVColor hsv = HSVColor.fromColor(t.color);

    String _hex6(Color c) =>
        c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    bool _validHex(String s) =>
        RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(s) ||
        RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(s);
    Color _fromHex(String s) {
      var h = s.trim().replaceAll('#', '');
      if (h.length == 6) h = 'FF$h';
      final v = int.parse(h, radix: 16);
      return Color(v);
    }

    // Start with empty hex as requested
    final hexCtl = TextEditingController(text: '');

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

            void applyHex([String? raw]) {
              final text = (raw ?? hexCtl.text).trim();
              if (!_validHex(text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid hex like 34C3A3')),
                );
                return;
              }
              final c = _fromHex(text);
              setSheet(() => hsv = HSVColor.fromColor(c));
            }

            final presets = <Color>[
              const Color(0xFF0D7C66),
              Colors.teal,
              Colors.blue,
              Colors.indigo,
              Colors.purple,
              Colors.pinkAccent,
              Colors.orange,
              Colors.amber,
              Colors.redAccent,
              Colors.brown,
              Colors.grey,
            ];

            return Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF123A36) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
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
                  const Text(
                    'Pick color',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  // Ring + (smaller) SV square inside
                  SizedBox(
                    height: 220,
                    width: 220,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final size = Size(c.maxWidth, c.maxHeight);
                        const ringWidth = 18.0;
                        final radius = size.width / 2 - ringWidth / 2;
                        final rad = hsv.hue * pi / 180;
                        final knob = Offset(
                          size.width / 2 + cos(rad) * radius,
                          size.height / 2 + sin(rad) * radius,
                        );

                        final innerDiameter = size.width - ringWidth * 2;
                        final squareSize = innerDiameter * 0.76; // smaller than circle

                        return GestureDetector(
                          onPanDown:
                              (d) => setHueFromOffset(d.localPosition, size),
                          onPanUpdate:
                              (d) => setHueFromOffset(d.localPosition, size),
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

                  // HEX input row: leading '#', live preview
                  Row(
                    children: [
                      // Live preview circle
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
                      const Text(
                        '#',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: hexCtl,
                          onChanged: (v) {
                            final txt = v.trim();
                            if (_validHex(txt)) {
                              setSheet(() => hsv = HSVColor.fromColor(_fromHex(txt)));
                            }
                          },
                          textInputAction: TextInputAction.done,
                          onSubmitted: (v) {
                            if (_validHex(v.trim())) applyHex(v.trim());
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'RRGGBB',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => applyHex(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D7C66),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(90, 36),
                        ),
                        child: const Text('Apply HEX'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Quick swatches
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in presets)
                          GestureDetector(
                            onTap: () =>
                                setSheet(() => hsv = HSVColor.fromColor(c)),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.black26, width: 1),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#${_hex6(hsv.toColor())}',
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => t.color = hsv.toColor());
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
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HueRingPainter extends CustomPainter {
  _HueRingPainter({required this.ringWidth});
  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint =
        Paint()
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
    final p =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    final b =
        Paint()
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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
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
  NoTransitionPageRoute({required WidgetBuilder builder})
      : super(builder: builder);

  @override
  Widget buildTransitions(BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    return child; // no animation
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
      if (i == index) {
        return dark ? darkSelected : green;
      }
      return Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: Icon(Icons.home, color: c(0)), onPressed: () {}),
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
            icon: Icon(Icons.settings, color: c(2)),
            onPressed: () => Navigator.pushReplacement(
              context,
              NoTransitionPageRoute(
                builder: (_) => SettingsPage(userName: userName),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
