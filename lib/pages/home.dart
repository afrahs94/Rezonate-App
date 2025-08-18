// lib/pages/home.dart
import 'dart:math';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // ---- Lifecycle
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final u = _user;
    if (u == null) return;

    // Trackers live snapshot
    _db
        .collection('users')
        .doc(u.uid)
        .collection('trackers')
        .orderBy('sort')
        .snapshots()
        .listen((snap) async {
      final list = snap.docs.map(Tracker.fromDoc).toList();
      if (list.isEmpty) {
        // seed a default tracker
        await _createTracker(label: 'add tracker');
        return;
      }
      setState(() {
        _trackers = list;
        if (_selectedForChart.isEmpty) {
          _selectedForChart.addAll(_trackers.map((t) => t.id));
        }
      });
    });

    // Pull last 120 days of logs and keep in memory
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
      for (final d in snap.docs) {
        final m = d.data();
        final vals = (m['values'] as Map?)?.map((k, v) => MapEntry('$k', (v as num).toDouble())) ??
            <String, double>{};
        map[d.id] = vals.cast<String, double>();
        if (vals.isNotEmpty) daysWithLogs.add(d.id);
      }
      setState(() {
        _daily
          ..clear()
          ..addAll(map);
        _daysWithAnyLog
          ..clear()
          ..addAll(daysWithLogs);
      });
    });
  }

  // ---- Helpers
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
    int s = 0;
    DateTime d = DateTime.now();
    bool hasDay(DateTime x) => _daysWithAnyLog.contains(_dayKey(x));
    while (hasDay(d)) {
      s++;
      d = d.subtract(const Duration(days: 1));
    }
    return s;
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
    final color = Colors.primaries[_rnd.nextInt(Colors.primaries.length)].shade700;
    final sort = _trackers.length;
    final t = Tracker(id: id, label: label, color: color, value: 5, sort: sort);
    await _db.collection('users').doc(u.uid).collection('trackers').doc(id).set(t.toMap());
  }

  Future<void> _updateTracker(Tracker t, {String? label, Color? color, double? latest}) async {
    final u = _user;
    if (u == null) return;
    final data = <String, dynamic>{
      if (label != null) 'label': label,
      if (color != null) 'color': color.value,
      if (latest != null) 'latest_value': latest,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('users').doc(u.uid).collection('trackers').doc(t.id).set(
          data,
          SetOptions(merge: true),
        );
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
    setState(() => t.value = v);

    // remote
    final dayInt = int.parse(DateFormat('yyyyMMdd').format(now));
    await _db.collection('users').doc(u.uid).collection('daily_logs').doc(key).set({
      'day': dayInt,
      'values': {t.id: v},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _updateTracker(t, latest: v);
  }

  Future<void> _deleteTracker(Tracker t) async {
    final u = _user;
    if (u == null) return;
    await _db.collection('users').doc(u.uid).collection('trackers').doc(t.id).delete();
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

    late List<double> xPoints;
    final List<List<double>> seriesValues = [];

    if (_view == ChartView.weekly) {
      final days = _currentWeekMonToSun();
      xPoints = List.generate(days.length, (i) => i.toDouble()); // 0..6
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
          chunks.map<double>((w) => w.isEmpty ? 0.0 : w.reduce((a, b) => a + b) / w.length).toList(),
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
          chunks.map<double>((w) => w.isEmpty ? 0.0 : w.reduce((a, b) => a + b) / w.length).toList(),
        );
      }
    }

    // EXTRA INNER PADDING so curves & dots never touch/cut the rounded edges.
    // (Bigger headroom than before to fully avoid clipping.)
    const double yPad = 2.0;     // vertical headroom (was 0.5)
    const double xPad = 0.8;     // horizontal headroom (was 0.15)
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
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: bars,
      // Keep everything inside the chart rect (after we added safe padding).
      clipData: const FlClipData.all(),
    );
  }

  // ---- UI
  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);
    final now = DateTime.now();
    final dateLine = DateFormat('EEEE • MMM d, yyyy').format(now);

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
                      // Logo
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Image.asset(
                          'assets/images/Logo.png',
                          height: 72,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.flash_on, size: 72, color: green.withOpacity(.85)),
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
                        style: TextStyle(color: Colors.black.withOpacity(.65), fontSize: 12),
                      ),

                      const SizedBox(height: 18),

                      // Streak pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.9),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department,
                                color: Colors.deepOrange, size: 18),
                            const SizedBox(width: 6),
                            Text('$_streak-day streak',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
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
                                    width: 140,
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 8,
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 9),
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
                                                borderRadius: BorderRadius.circular(16)),
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
                                                  child: const Text('Cancel')),
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
                                                borderRadius: BorderRadius.circular(16)),
                                            title: const Text('Delete tracker?'),
                                            content: Text(
                                                'This will remove "${t.label}" from your trackers.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Cancel')),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
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
                                    itemBuilder: (c) => [
                                      const PopupMenuItem(
                                          value: 'rename', child: Text('Rename')),
                                      const PopupMenuItem(value: 'color', child: Text('Color')),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete',
                                            style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.drag_indicator, size: 18),
                                ],
                              ),
                              const Divider(height: 0, indent: 4, endIndent: 4),
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
                        color: green,
                      ),

                      const SizedBox(height: 24),

                      // View selector
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
                              label: Text(lbl,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                              selected: sel,
                              selectedColor: green.withOpacity(.15),
                              onSelected: (_) => setState(() => _view = v),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 8),

                      // Date range + dropdown icon (selection dialog)
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
                            icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                            color: green,
                            onPressed: _openSelectDialog,
                            tooltip: 'Select trackers to view',
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Chart card
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        height: 320,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.88),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        ),
                        child: _selectedForChart.isEmpty
                            ? const Center(
                                child: Text('Select trackers to view',
                                    style: TextStyle(fontSize: 13)))
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

  // ---- Select trackers dialog (on-theme)
  Future<void> _openSelectDialog() async {
    final chosen = Set<String>.from(_selectedForChart);
    await showDialog(
      context: context,
      builder: (ctx) {
        final dark = app.ThemeControllerScope.of(context).isDark;
        return Dialog(
          backgroundColor: dark ? const Color(0xFF123A36) : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: const [
                    Icon(Icons.checklist, size: 20, color: Color(0xFF0D7C66)),
                    SizedBox(width: 8),
                    Text('Select trackers to view',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: _trackers.map((t) {
                        final checked = chosen.contains(t.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) {
                            if (v == true) {
                              chosen.add(t.id);
                            } else {
                              chosen.remove(t.id);
                            }
                            (ctx as Element).markNeedsBuild();
                          },
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(t.label),
                          secondary: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(color: t.color, shape: BoxShape.circle),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedForChart
                          ..clear()
                          ..addAll(chosen);
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Done', style: TextStyle(color: Color(0xFF0D7C66))),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Color picker bits -------------------------------------------------
  Future<void> _openColorPicker(Tracker t) async {
    HSVColor hsv = HSVColor.fromColor(t.color);

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
              var ang = atan2(vec.dy, vec.dx); // -pi..pi
              ang = (ang < 0) ? (ang + 2 * pi) : ang;
              final deg = ang * 180 / pi;
              setSheet(() => hsv = hsv.withHue(deg));
            }

            return Container(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 12, bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
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
                        final knob = Offset(
                          size.width / 2 + cos(rad) * radius,
                          size.height / 2 + sin(rad) * radius,
                        );

                        return GestureDetector(
                          onPanDown: (d) => setHueFromOffset(d.localPosition, size),
                          onPanUpdate: (d) => setHueFromOffset(d.localPosition, size),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(size: size, painter: _HueRingPainter(ringWidth: ringWidth)),
                              SizedBox(
                                width: size.width - ringWidth * 2.4,
                                height: size.height - ringWidth * 2.4,
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
                                child: CustomPaint(painter: _KnobPainter(position: knob), size: size),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: hsv.toColor(),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black26),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '#${hsv.toColor().value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
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
    final paint = Paint()
      ..shader = const SweepGradient(colors: <Color>[
        Color(0xFFFF0000),
        Color(0xFFFFFF00),
        Color(0xFF00FF00),
        Color(0xFF00FFFF),
        Color(0xFF0000FF),
        Color(0xFFFF00FF),
        Color(0xFFFF0000),
      ]).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;
    final radius = min(size.width, size.height) / 2 - ringWidth / 2;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
  }

  @override
  bool shouldRepaint(covariant _HueRingPainter oldDelegate) => false;
}

class _KnobPainter extends CustomPainter {
  _KnobPainter({required this.position});
  final Offset position;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final b = Paint()
      ..color = Colors.black.withOpacity(.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(position, 8, p);
    canvas.drawCircle(position, 8, b);
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) => oldDelegate.position != position;
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
                  gradient: const LinearGradient(
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

class _BottomNav extends StatelessWidget {
  final int index;
  final String userName;
  const _BottomNav({required this.index, required this.userName});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);
    Color c(int i) => i == index ? green : Colors.white;

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
              MaterialPageRoute(builder: (_) => JournalPage(userName: userName)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: c(2)),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => SettingsPage(userName: userName)),
            ),
          ),
        ],
      ),
    );
  }
}
