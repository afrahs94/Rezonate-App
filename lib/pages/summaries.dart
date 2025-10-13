import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:new_rezonate/main.dart' as app;
import 'home.dart';
import 'journal.dart';
import 'settings.dart';

class SummariesPage extends StatefulWidget {
  final String userName;
  const SummariesPage({super.key, required this.userName});

  @override
  State<SummariesPage> createState() => _SummariesPageState();
}

class _SummariesPageState extends State<SummariesPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  User? get _user => _auth.currentUser;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _trackersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _logsSub;

  // Trackers meta: id -> info
  final Map<String, _TrackerMeta> _trackers = {};

  // Per-day values for ~last 365 days: "yyyy-MM-dd" -> { trackerId: value }
  final Map<String, Map<String, double>> _daily = {};

  // Derived analytics
  int _streak = 0;

  // Windows for trends
  double _avgLast7 = 0;
  double _avgPrev7 = 0;
  double _delta7 = 0;
  double _pct7 = 0;

  double _avgLast30 = 0;
  double _avgPrev30 = 0;
  double _delta30 = 0;
  double _pct30 = 0;

  // Still compute for charts/persistence
  double _avgLast14 = 0;
  double _adherenceLast14 = 0; // 0..1
  int _daysLoggedLast14 = 0;
  _TrackerStat? _bestTracker;
  _TrackerStat? _worstTracker;

  // Tracker-averages range selector
  _Range _range = _Range.week; // default tab
  List<_TrackerStat> _rangeAverages = const [];

  // Calendar month anchor (first day of shown month)
  DateTime _calMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Firestore snapshot debounce
  Timer? _persistDebounce;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _trackersSub?.cancel();
    _logsSub?.cancel();
    _persistDebounce?.cancel();
    super.dispose();
  }

  // Same background as Home
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

  // ===== Firestore bootstrap =====
  Future<void> _bootstrap() async {
    final u = _user;
    if (u == null) return;

    _trackersSub = _db
        .collection('users')
        .doc(u.uid)
        .collection('trackers')
        .orderBy('sort')
        .snapshots()
        .listen((snap) {
      _trackers
        ..clear()
        ..addEntries(snap.docs.map((d) {
          final m = d.data();
          return MapEntry(
            d.id,
            _TrackerMeta(
              id: d.id,
              label: (m['label'] as String? ?? 'Tracker').trim(),
              color: Color((m['color'] as int?) ?? const Color(0xFF147C72).value),
              latest: (m['latest_value'] as num?)?.toDouble() ?? 0,
              sort: (m['sort'] as num?)?.toInt() ?? 0,
            ),
          );
        }));
      _recompute();
    });

    _logsSub = _db
        .collection('users')
        .doc(u.uid)
        .collection('daily_logs')
        .orderBy('day', descending: false)
        .limit(365) // keep a year for "Yearly"
        .snapshots()
        .listen((snap) {
      _daily.clear();
      for (final d in snap.docs) {
        final map = (d.data()['values'] as Map?)?.map(
              (k, v) => MapEntry('$k', (v as num).toDouble()),
            ) ??
            <String, double>{};
        _daily[d.id] = map;
      }
      _recompute();
    });
  }

  // ===== Helpers =====
  String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  List<DateTime> _lastNDays(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      final d = now.subtract(Duration(days: n - 1 - i));
      return DateTime(d.year, d.month, d.day);
    });
  }

  List<DateTime> _lastNDaysWithOffset(int n, {int offsetDays = 0}) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      final d = now.subtract(Duration(days: offsetDays + (n - 1 - i)));
      return DateTime(d.year, d.month, d.day);
    });
  }

  bool _isLogged(DateTime day) => (_daily[_dayKey(day)]?.isNotEmpty ?? false);

  int _computeStreak() {
    if (_daily.isEmpty) return 0;
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    final days = _daily.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toSet();
    if (days.isEmpty) return 0;

    // allow 24h grace if the most recent logged day is within last 24h
    String anchor = todayKey;
    if (!days.contains(todayKey)) {
      final latest = days.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      final lastDay = DateTime.parse(latest);
      if (now.difference(lastDay).inHours < 24) {
        anchor = latest;
      } else {
        return 0;
      }
    }

    int c = 0;
    DateTime d = DateTime.parse(anchor);
    while (true) {
      final key = _dayKey(d);
      if (!days.contains(key)) break;
      c++;
      d = d.subtract(const Duration(days: 1));
    }
    // UI rule: don’t include current day-in-progress
    return max(0, c - 1);
  }

  double _avgOfDay(Map<String, double> vals) {
    if (vals.isEmpty) return 0;
    double s = 0;
    int n = 0;
    vals.forEach((_, v) {
      s += v;
      n++;
    });
    return n == 0 ? 0 : s / n;
  }

  double _meanForDays(List<DateTime> days) {
    if (days.isEmpty) return 0;
    double s = 0;
    for (final d in days) {
      s += _avgOfDay(_daily[_dayKey(d)] ?? const <String, double>{});
    }
    return s / days.length;
  }

  double _safePctChange(double curr, double prev) {
    if (prev == 0) return 0; // avoid /0; treat as 0% if no baseline
    return (curr - prev) / prev;
  }

  void _recompute() {
    // windows
    final last7 = _lastNDays(7);
    final prev7 = _lastNDaysWithOffset(7, offsetDays: 7);

    final last14 = _lastNDays(14);
    final last30 = _lastNDays(30);
    final prev30 = _lastNDaysWithOffset(30, offsetDays: 30);

    // means
    _avgLast7 = _meanForDays(last7);
    _avgLast14 = _meanForDays(last14);
    _avgLast30 = _meanForDays(last30);
    _avgPrev7 = _meanForDays(prev7);
    _avgPrev30 = _meanForDays(prev30);

    // deltas / percent
    _delta7 = _avgLast7 - _avgPrev7;
    _delta30 = _avgLast30 - _avgPrev30;
    _pct7 = _safePctChange(_avgLast7, _avgPrev7);
    _pct30 = _safePctChange(_avgLast30, _avgPrev30);

    // adherence (14-day)
    _daysLoggedLast14 = last14.where((d) => (_daily[_dayKey(d)]?.isNotEmpty ?? false)).length;
    _adherenceLast14 = last14.isEmpty ? 0 : _daysLoggedLast14 / last14.length;

    // best/worst trackers (mean over last 14)
    final meansByTracker = <String, _Accumulator>{};
    for (final d in last14) {
      final m = _daily[_dayKey(d)];
      if (m == null) continue;
      m.forEach((tid, v) {
        (meansByTracker[tid] ??= _Accumulator()).add(v);
      });
    }
    _bestTracker = null;
    _worstTracker = null;
    meansByTracker.forEach((tid, acc) {
      final meta = _trackers[tid];
      if (meta == null || acc.n == 0) return;
      final mean = acc.sum / acc.n;
      final stat = _TrackerStat(id: tid, label: meta.label, color: meta.color, mean: mean);
      if (_bestTracker == null || mean > _bestTracker!.mean) _bestTracker = stat;
      if (_worstTracker == null || mean < _worstTracker!.mean) _worstTracker = stat;
    });

    // update range-averages section
    _rangeAverages = _computeTrackerAveragesForRange(_range);

    _streak = _computeStreak();

    if (mounted) setState(() {});
    _schedulePersistSnapshot();
  }

  void _schedulePersistSnapshot() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 800), _persistSummarySnapshot);
  }

  Future<void> _persistSummarySnapshot() async {
    final u = _user;
    if (u == null) return;

    final doc = _db
        .collection('users')
        .doc(u.uid)
        .collection('summary_snapshots')
        .doc(); // auto-id

    await doc.set({
      'createdAt': FieldValue.serverTimestamp(),
      'avg_last7': _round1(_avgLast7),
      'avg_last14': _round1(_avgLast14), // kept for backward-compatibility
      'adherence_last14': _round2(_adherenceLast14),
      'days_logged_last14': _daysLoggedLast14,
      'streak': _streak,
      'best_tracker': _bestTracker == null
          ? null
          : {
              'id': _bestTracker!.id,
              'label': _bestTracker!.label,
              'mean': _round1(_bestTracker!.mean),
            },
      'worst_tracker': _worstTracker == null
          ? null
          : {
              'id': _worstTracker!.id,
              'label': _worstTracker!.label,
              'mean': _round1(_worstTracker!.mean),
            },
    });
  }

  double _round1(double v) => (v * 10).round() / 10.0;
  double _round2(double v) => (v * 100).round() / 100.0;

  // ===== Range-based tracker averages =====
  List<_TrackerStat> _computeTrackerAveragesForRange(_Range r) {
    List<DateTime> days;
    switch (r) {
      case _Range.week:
        days = _lastNDays(7);
        break;
      case _Range.month:
        days = _lastNDays(30);
        break;
      case _Range.year:
        days = _lastNDays(365);
        break;
      case _Range.overall:
        final keys = _daily.keys.toList()..sort();
        days = [for (final k in keys) DateTime.parse(k)];
        break;
    }

    final acc = <String, _Accumulator>{};
    for (final d in days) {
      final map = _daily[_dayKey(d)];
      if (map == null) continue;
      map.forEach((tid, v) {
        (acc[tid] ??= _Accumulator()).add(v);
      });
    }

    final out = <_TrackerStat>[];
    acc.forEach((tid, a) {
      if (a.n == 0) return;
      final meta = _trackers[tid];
      if (meta == null) return;
      out.add(_TrackerStat(
        id: tid,
        label: meta.label,
        color: meta.color,
        mean: a.sum / a.n,
      ));
    });

    out.sort((a, b) => b.mean.compareTo(a.mean));
    return out;
  }

  // ===== Charts =====
  LineChartData _trend14Chart() {
    final days = _lastNDays(14);
    final points = <FlSpot>[
      for (int i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), _avgOfDay(_daily[_dayKey(days[i])] ?? const <String, double>{})),
    ];

    return LineChartData(
      minX: 0,
      maxX: 13,
      minY: -0.5,
      maxY: 10.5,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 2,
        getDrawingHorizontalLine: (v) => FlLine(strokeWidth: 0.6, color: Colors.black12),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false, reservedSize: 0),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 3,
            getTitlesWidget: (v, meta) {
              final i = v.round();
              if (i < 0 || i >= days.length) return const SizedBox.shrink();
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 6,
                child: Text(
                  DateFormat('MM/dd').format(days[i]),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: points,
          isCurved: true,
          barWidth: 3,
          color: const Color(0xFF0D7C66),
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xBF0D7C66), Color(0x100D7C66)],
            ),
          ),
        ),
      ],
      clipData: const FlClipData.all(),
    );
  }

  // ===== Day details bottom sheet =====
  void _showDayDetails(DateTime day) {
    final key = _dayKey(day);
    final values = _daily[key];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final dark = app.ThemeControllerScope.of(context).isDark;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(ctx).padding.bottom,
            top: 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMM d, yyyy').format(day),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: dark ? Colors.white : const Color(0xFF20312F),
                ),
              ),
              const SizedBox(height: 8),
              if (values == null || values.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No entries for this day.',
                    style: TextStyle(
                      fontSize: 13,
                      color: (dark ? Colors.white : Colors.black).withOpacity(.7),
                    ),
                  ),
                )
              else
                ...values.entries.map((e) {
                  final meta = _trackers[e.key];
                  final label = meta?.label ?? 'Tracker';
                  final color = meta?.color ?? const Color(0xFF0D7C66);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: dark ? Colors.white : const Color(0xFF20312F),
                            ),
                          ),
                        ),
                        Text(
                          e.value.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: dark ? Colors.white : const Color(0xFF20312F),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: _bg(context)),
        child: SafeArea(
          child: Column(
            children: [
              // Header (extra top padding, no date line)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: dark ? Colors.white : const Color(0xFF20312F),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.pushReplacement(
                            context,
                            NoTransitionPageRoute(builder: (_) => HomePage(userName: widget.userName)),
                          );
                        }
                      },
                    ),
                    const Spacer(),
                    const Text(
                      'Insights',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    12,
                    8,
                    12,
                    16 + MediaQuery.of(context).padding.bottom + 56,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top indicators: 7-day / 30-day / streak
                      Row(
                        children: [
                          Expanded(
                            child: _TrendCard(
                              title: '7-day trend',
                              subtitle: 'vs prior week',
                              percent: _pct7,
                              deltaPts: _delta7,
                              dark: dark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TrendCard(
                              title: '30-day trend',
                              subtitle: 'vs prior 30 days',
                              percent: _pct30,
                              deltaPts: _delta30,
                              dark: dark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _StreakCard(streak: _streak, dark: dark)),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Trend line (14 days)
                      _SectionCard(
                        dark: dark,
                        title: 'Average mood • last 14 days',
                        subtitle: 'Higher is better',
                        child: SizedBox(height: 220, child: LineChart(_trend14Chart())),
                      ),

                      const SizedBox(height: 12),

                      // Calendar-style logging consistency
                      _SectionCard(
                        dark: dark,
                        title: 'Logging calendar • ${DateFormat('MMMM yyyy').format(_calMonth)}',
                        subtitle: 'Days you logged are highlighted',
                        child: _LoggingCalendar(
                          monthAnchor: _calMonth,
                          isLogged: _isLogged,
                          onPrev: () => setState(() {
                            _calMonth = DateTime(_calMonth.year, _calMonth.month - 1, 1);
                          }),
                          onNext: () => setState(() {
                            _calMonth = DateTime(_calMonth.year, _calMonth.month + 1, 1);
                          }),
                          onDayTap: (d) => _showDayDetails(d),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Tracker averages with range filter
                      _SectionCard(
                        dark: dark,
                        title: 'Tracker averages',
                        subtitle: _range.subtitle,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RangePicker(
                              range: _range,
                              onChanged: (_Range r) {
                                setState(() {
                                  _range = r;
                                  _rangeAverages = _computeTrackerAveragesForRange(_range);
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            if (_rangeAverages.isEmpty)
                              _EmptyLine(
                                text: 'No data yet. Add a few logs on the Home page.',
                                dark: dark,
                              )
                            else
                              Column(
                                children: [
                                  for (final s in _rangeAverages)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: _TrackerAverageRow(stat: s, dark: dark),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Best / Worst trackers
                      _SectionCard(
                        dark: dark,
                        title: 'Tracker signals',
                        subtitle: 'Based on 14-day averages',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_bestTracker != null)
                              _SignalRow(
                                label: 'Most positive trend',
                                stat: _bestTracker!,
                                dark: dark,
                              )
                            else
                              _EmptyLine(text: 'Add a few logs to see tracker insights', dark: dark),
                            const SizedBox(height: 8),
                            if (_worstTracker != null)
                              _SignalRow(
                                label: 'Needs attention',
                                stat: _worstTracker!,
                                dark: dark,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),
              _BottomNav3(index: 0, userName: widget.userName),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Reusable UI Bits =====

/// Polished Streak card: hero number + single-line pill subtitle.
class _StreakCard extends StatelessWidget {
  final int streak;
  final bool dark;
  const _StreakCard({required this.streak, required this.dark});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF123A36) : Colors.white.withOpacity(.94);
    final textColor = dark ? Colors.white : const Color(0xFF20312F);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: dark ? [] : const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        border: dark ? Border.all(color: Colors.white24) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE3B0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_fire_department, color: Color(0xFFCC6A00)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Streak',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: textColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (dark ? Colors.white : const Color(0xFF20312F)).withOpacity(.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.black12.withOpacity(.15)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Consecutive days',
                softWrap: false,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: (dark ? Colors.white : Colors.black).withOpacity(.75),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final bool dark;
  final IconData? icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.dark,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF123A36) : Colors.white.withOpacity(.92);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: dark ? [] : const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        border: dark ? Border.all(color: Colors.white24) : null,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: dark ? Colors.orange : const Color(0xFF0D7C66)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: (dark ? Colors.white : const Color(0xFF20312F)),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: (dark ? Colors.white : Colors.black).withOpacity(.6),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: dark ? Colors.white : const Color(0xFF20312F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Readable, overflow-safe trend card.
class _TrendCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double percent;   // e.g. 0.23 == +23%
  final double deltaPts;  // absolute delta in points
  final bool dark;

  const _TrendCard({
    required this.title,
    required this.subtitle,
    required this.percent,
    required this.deltaPts,
    required this.dark,
  });

  String _sign(double v) => v >= 0 ? '+' : '−';

  @override
  Widget build(BuildContext context) {
    final Color up = const Color(0xFF0D7C66);
    final Color down = const Color(0xFFD84A4A);
    final Color flat = Colors.grey.shade600;

    int dir;
    if (percent.abs() < 0.01 && deltaPts.abs() < 0.05) {
      dir = 0; // flat
    } else {
      dir = percent >= 0 ? 1 : -1;
    }

    final Color accent = dir == 1 ? up : (dir == -1 ? down : flat);
    final IconData icon = dir == 1
        ? Icons.trending_up_rounded
        : (dir == -1 ? Icons.trending_down_rounded : Icons.trending_flat_rounded);

    // Format numbers
    final pctTxt = '${_sign(percent)}${(percent.abs() * 100).clamp(0, 999).toStringAsFixed(0)}%';
    final deltaTxt = '${_sign(deltaPts)}${deltaPts.abs().toStringAsFixed(1)} pts';

    final bg = dark ? const Color(0xFF123A36) : Colors.white.withOpacity(.94);
    final subColor = (dark ? Colors.white : Colors.black).withOpacity(.65);
    final textColor = dark ? Colors.white : const Color(0xFF20312F);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 120; // hide subtitle if very tight

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: dark ? [] : const [BoxShadow(color: Colors.black12, blurRadius: 6)],
            border: dark ? Border.all(color: Colors.white24) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // allow wrapping so it stays readable
                        Text(
                          title,
                          softWrap: true,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            height: 1.1,
                          ),
                        ),
                        if (!narrow)
                          Text(
                            subtitle,
                            softWrap: true,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: subColor,
                              height: 1.1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Big % value
              Text(
                pctTxt,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              // delta chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withOpacity(.25)),
                ),
                child: Text(
                  deltaTxt,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool dark;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.dark,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF123A36) : Colors.white.withOpacity(.92);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: dark ? [] : const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        border: dark ? Border.all(color: Colors.white24) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : const Color(0xFF20312F),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: (dark ? Colors.white : Colors.black).withOpacity(.65),
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  final String label;
  final _TrackerStat stat;
  final bool dark;

  const _SignalRow({
    required this.label,
    required this.stat,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final chipBg = dark ? stat.color.withOpacity(.25) : stat.color.withOpacity(.12);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: (dark ? Colors.white : Colors.black).withOpacity(.8),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: stat.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(
                stat.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : const Color(0xFF20312F),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                stat.mean.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: dark ? Colors.white : const Color(0xFF20312F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackerAverageRow extends StatelessWidget {
  final _TrackerStat stat;
  final bool dark;
  const _TrackerAverageRow({required this.stat, required this.dark});

  @override
  Widget build(BuildContext context) {
    final chipBg = dark ? stat.color.withOpacity(.25) : stat.color.withOpacity(.12);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: stat.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  stat.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: dark ? Colors.white : const Color(0xFF20312F),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            stat.mean.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: dark ? Colors.white : const Color(0xFF20312F),
            ),
          ),
        ),
      ],
    );
  }
}

class _RangePicker extends StatelessWidget {
  final _Range range;
  final ValueChanged<_Range> onChanged;
  const _RangePicker({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final opts = _Range.values;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final r in opts)
          ChoiceChip(
            label: Text(r.label),
            selected: r == range,
            onSelected: (_) => onChanged(r),
          ),
      ],
    );
  }
}

enum _Range { week, month, year, overall }

extension on _Range {
  String get label {
    switch (this) {
      case _Range.week:
        return 'Weekly';
      case _Range.month:
        return 'Monthly';
      case _Range.year:
        return 'Yearly';
      case _Range.overall:
        return 'Overall';
    }
  }

  String get subtitle {
    switch (this) {
      case _Range.week:
        return 'Average per tracker (last 7 days)';
      case _Range.month:
        return 'Average per tracker (last 30 days)';
      case _Range.year:
        return 'Average per tracker (last 365 days)';
      case _Range.overall:
        return 'Average per tracker (all time loaded)';
    }
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;
  final bool dark;
  const _EmptyLine({required this.text, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: (dark ? Colors.white : Colors.black).withOpacity(.6),
      ),
    );
  }
}

// ===== Logging Calendar Widget (now supports day taps) =====
class _LoggingCalendar extends StatelessWidget {
  final DateTime monthAnchor; // first day of month
  final bool Function(DateTime day) isLogged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime>? onDayTap;

  const _LoggingCalendar({
    required this.monthAnchor,
    required this.isLogged,
    required this.onPrev,
    required this.onNext,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthStart = DateTime(monthAnchor.year, monthAnchor.month, 1);
    final startWeekday = monthStart.weekday % 7; // Sun=0, Mon=1...
    final gridStart = monthStart.subtract(Duration(days: startWeekday));
    final days = List<DateTime>.generate(42, (i) => DateTime(gridStart.year, gridStart.month, gridStart.day + i));
    final isDark = app.ThemeControllerScope.of(context).isDark;

    Color loggedColor = const Color(0xFF3E8F84);
    Color outMonthText = theme.textTheme.bodySmall!.color!.withOpacity(.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(DateFormat('MMMM yyyy').format(monthStart),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.bodySmall!.color!.withOpacity(.6),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, idx) {
            final day = days[idx];
            final inMonth = day.month == monthStart.month;
            final logged = isLogged(day);

            return LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.biggest.shortestSide;
                final dia = side * 0.72;
                final bgColor = logged
                    ? loggedColor
                    : (isDark ? Colors.white.withOpacity(.06) : Colors.black12.withOpacity(.08));
                final border = logged ? null : Border.all(color: Colors.black12, width: 0.6);
                final textColor = inMonth
                    ? (logged ? Colors.white : theme.textTheme.bodySmall!.color)
                    : outMonthText;

                final circle = Center(
                  child: Container(
                    width: dia,
                    height: dia,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                      border: border,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: dia * 0.45,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                );

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(dia / 2),
                    onTap: onDayTap == null ? null : () => onDayTap!(day),
                    child: circle,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ===== Bottom Nav (3 items: Home / Journal / Settings) =====
class _BottomNav3 extends StatelessWidget {
  final int index;
  final String userName;
  const _BottomNav3({required this.index, required this.userName});

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
      padding: EdgeInsets.only(
        bottom: 8 + MediaQuery.of(context).padding.bottom,
        top: 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.home, color: c(0)),
            onPressed: () => Navigator.pushReplacement(
              context,
              NoTransitionPageRoute(builder: (_) => HomePage(userName: userName)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.menu_book, color: c(1)),
            onPressed: () => Navigator.pushReplacement(
              context,
              NoTransitionPageRoute(builder: (_) => JournalPage(userName: userName)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: c(2)),
            onPressed: () => Navigator.pushReplacement(
              context,
              NoTransitionPageRoute(builder: (_) => SettingsPage(userName: userName)),
            ),
          ),
        ],
      ),
    );
  }
}

class NoTransitionPageRoute<T> extends MaterialPageRoute<T> {
  NoTransitionPageRoute({required WidgetBuilder builder}) : super(builder: builder);
  @override
  Widget buildTransitions(BuildContext context, Animation<double> a, Animation<double> s, Widget child) => child;
}

// ===== Models / Stats helpers =====
class _TrackerMeta {
  _TrackerMeta({
    required this.id,
    required this.label,
    required this.color,
    required this.latest,
    required this.sort,
  });

  final String id;
  String label;
  Color color;
  double latest;
  int sort;
}

class _Accumulator {
  double sum = 0;
  int n = 0;
  void add(double v) {
    sum += v;
    n += 1;
  }
}

class _TrackerStat {
  final String id;
  final String label;
  final Color color;
  final double mean;
  _TrackerStat({
    required this.id,
    required this.label,
    required this.color,
    required this.mean,
  });
}
