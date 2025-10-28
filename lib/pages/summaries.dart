import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:new_rezonate/main.dart' as app;
// IMPORTANT: do NOT import 'home.dart' to avoid circular import.
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

  final Map<String, _TrackerMeta> _trackers = {};
  final Map<String, Map<String, double>> _daily = {};

  int _streak = 0;

  double _avgLast7 = 0;
  double _avgPrev7 = 0;
  double _delta7 = 0;
  double _pct7 = 0;

  double _avgLast30 = 0;
  double _avgPrev30 = 0;
  double _delta30 = 0;
  double _pct30 = 0;

  double _avgLast14 = 0;
  double _adherenceLast14 = 0;
  int _daysLoggedLast14 = 0;
  _TrackerStat? _bestTracker;
  _TrackerStat? _worstTracker;

  _Range _range = _Range.week;
  List<_TrackerStat> _rangeAverages = const [];

  DateTime _calMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

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

  LinearGradient _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    // Softer gradient: lighter top, less harsh teal bottom
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [
              Color(0xFF1F1F28),
              Color(0xFF123A36),
            ]
          : const [
              Color(0xFFF9F7FF), // near-white lilac
              Color(0xFFE5DBFF), // soft lavender
              Color(0xFFE0F5F0), // desaturated teal fade
            ],
    );
  }

  // ---------- Firestore bootstrap ----------
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
              color: Color(
                (m['color'] as int?) ?? const Color(0xFF147C72).value,
              ),
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
        .limit(365)
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
    final days =
        _daily.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toSet();
    if (days.isEmpty) return 0;

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
    return max(0, c - 1); // don't include in-progress day
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
    if (prev == 0) return 0;
    return (curr - prev) / prev;
  }

  void _recompute() {
    final last7 = _lastNDays(7);
    final prev7 = _lastNDaysWithOffset(7, offsetDays: 7);

    final last14 = _lastNDays(14);
    final last30 = _lastNDays(30);
    final prev30 = _lastNDaysWithOffset(30, offsetDays: 30);

    _avgLast7 = _meanForDays(last7);
    _avgLast14 = _meanForDays(last14);
    _avgLast30 = _meanForDays(last30);
    _avgPrev7 = _meanForDays(prev7);
    _avgPrev30 = _meanForDays(prev30);

    _delta7 = _avgLast7 - _avgPrev7;
    _delta30 = _avgLast30 - _avgPrev30;
    _pct7 = _safePctChange(_avgLast7, _avgPrev7);
    _pct30 = _safePctChange(_avgLast30, _avgPrev30);

    _daysLoggedLast14 =
        last14.where((d) => (_daily[_dayKey(d)]?.isNotEmpty ?? false)).length;
    _adherenceLast14 =
        last14.isEmpty ? 0 : _daysLoggedLast14 / last14.length;

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
      final stat = _TrackerStat(
        id: tid,
        label: meta.label,
        color: meta.color,
        mean: mean,
      );
      if (_bestTracker == null || mean > _bestTracker!.mean) {
        _bestTracker = stat;
      }
      if (_worstTracker == null || mean < _worstTracker!.mean) {
        _worstTracker = stat;
      }
    });

    _rangeAverages = _computeTrackerAveragesForRange(_range);
    _streak = _computeStreak();

    if (mounted) setState(() {});
    _schedulePersistSnapshot();
  }

  void _schedulePersistSnapshot() {
    _persistDebounce?.cancel();
    _persistDebounce =
        Timer(const Duration(milliseconds: 800), _persistSummarySnapshot);
  }

  Future<void> _persistSummarySnapshot() async {
    final u = _user;
    if (u == null) return;

    final doc = _db
        .collection('users')
        .doc(u.uid)
        .collection('summary_snapshots')
        .doc();

    await doc.set({
      'createdAt': FieldValue.serverTimestamp(),
      'avg_last7': _round1(_avgLast7),
      'avg_last14': _round1(_avgLast14),
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

  LineChartData _trend14Chart() {
    final days = _lastNDays(14);
    final points = <FlSpot>[
      for (int i = 0; i < days.length; i++)
        FlSpot(
          i.toDouble(),
          _avgOfDay(
            _daily[_dayKey(days[i])] ??
                const <String, double>{},
          ),
        ),
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
        getDrawingHorizontalLine: (v) =>
            FlLine(strokeWidth: 0.6, color: Colors.black12),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(
          sideTitles:
              SideTitles(showTitles: false, reservedSize: 0),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 3,
            getTitlesWidget: (v, meta) {
              final i = v.round();
              if (i < 0 || i >= days.length) {
                return const SizedBox.shrink();
              }
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
        rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
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
              colors: [
                Color(0xBF0D7C66),
                Color(0x100D7C66),
              ],
            ),
          ),
        ),
      ],
      clipData: const FlClipData.all(),
    );
  }

  void _showDayDetails(DateTime day) {
    final key = _dayKey(day);
    final values = _daily[key];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final dark =
            app.ThemeControllerScope.of(context).isDark;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16 +
                MediaQuery.of(ctx).padding.bottom,
            top: 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMM d, yyyy')
                    .format(day),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: dark
                      ? Colors.white
                      : const Color(0xFF20312F),
                ),
              ),
              const SizedBox(height: 8),
              if (values == null || values.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No entries for this day.',
                    style: TextStyle(
                      fontSize: 13,
                      color: (dark
                              ? Colors.white
                              : Colors.black)
                          .withOpacity(.7),
                    ),
                  ),
                )
              else
                ...values.entries.map((e) {
                  final meta = _trackers[e.key];
                  final label =
                      meta?.label ?? 'Tracker';
                  final color =
                      meta?.color ??
                          const Color(0xFF0D7C66);
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(
                            vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration:
                              BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w700,
                              color: dark
                                  ? Colors.white
                                  : const Color(
                                      0xFF20312F),
                            ),
                          ),
                        ),
                        Text(
                          e.value
                              .toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w900,
                            color: dark
                                ? Colors.white
                                : const Color(
                                    0xFF20312F),
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

  // ---------- UI ----------
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
              // Top app bar / header summary -----------------
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons
                          .arrow_back_ios_new_rounded),
                      color: dark
                          ? Colors.white
                          : const Color(0xFF20312F),
                      onPressed: () =>
                          Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _HeaderSummary(
                        userName: widget.userName,
                        streak: _streak,
                        avgLast7: _avgLast7,
                        adherencePct:
                            _adherenceLast14 * 100,
                        dark: dark,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics:
                      const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16 +
                        MediaQuery.of(context)
                            .padding
                            .bottom +
                        56,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      // Week/Month comparison chips ------------
                      _CardShell(
                        dark: dark,
                        child: _StatChipRow(
                          pct7: _pct7,
                          delta7: _delta7,
                          pct30: _pct30,
                          delta30: _delta30,
                          dark: dark,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Mood trend chart -----------------------
                      _CardShell(
                        dark: dark,
                        sectionTitle:
                            'Mood trend (last 14 days)',
                        sectionSubtitle:
                            'Higher is better',
                        child: SizedBox(
                          height: 200,
                          child: LineChart(
                              _trend14Chart()),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Logging calendar -----------------------
                      _CardShell(
                        dark: dark,
                        sectionTitle:
                            'Logging consistency',
                        sectionSubtitle:
                            'Days you made an entry',
                        child: _LoggingCalendar(
                          monthAnchor: _calMonth,
                          isLogged: _isLogged,
                          onPrev: () => setState(() {
                            _calMonth = DateTime(
                              _calMonth.year,
                              _calMonth.month - 1,
                              1,
                            );
                          }),
                          onNext: () => setState(() {
                            _calMonth = DateTime(
                              _calMonth.year,
                              _calMonth.month + 1,
                              1,
                            );
                          }),
                          onDayTap: (d) =>
                              _showDayDetails(d),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Trackers section (averages + signals) ---
                      _TrackersSection(
                        dark: dark,
                        range: _range,
                        onRangeChanged: (r) {
                          setState(() {
                            _range = r;
                            _rangeAverages =
                                _computeTrackerAveragesForRange(
                                    _range);
                          });
                        },
                        rangeAverages: _rangeAverages,
                        bestTracker: _bestTracker,
                        worstTracker: _worstTracker,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),
              _BottomNav3(
                index: 0,
                userName: widget.userName,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== NEW / UPDATED WIDGETS =====================

// Container shell used for each section to keep style consistent
class _CardShell extends StatelessWidget {
  final bool dark;
  final String? sectionTitle;
  final String? sectionSubtitle;
  final Widget child;

  const _CardShell({
    required this.dark,
    required this.child,
    this.sectionTitle,
    this.sectionSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark
        ? const Color(0xFF1F2E2C)
        : Colors.white.withOpacity(.95);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: dark
            ? []
            : const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                )
              ],
        border: dark
            ? Border.all(
                color: Colors.white24,
                width: 1,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (sectionTitle != null) ...[
            Text(
              sectionTitle!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: dark
                    ? Colors.white
                    : const Color(0xFF20312F),
              ),
            ),
            if (sectionSubtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                sectionSubtitle!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: (dark
                          ? Colors.white
                          : Colors.black)
                      .withOpacity(.6),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

// Header block that replaces "Insights" title + separate streak card
class _HeaderSummary extends StatelessWidget {
  final String userName;
  final int streak;
  final double avgLast7;
  final double adherencePct; // 0-100
  final bool dark;

  const _HeaderSummary({
    required this.userName,
    required this.streak,
    required this.avgLast7,
    required this.adherencePct,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor =
        dark ? Colors.white : const Color(0xFF20312F);
    final subColor = (dark ? Colors.white : Colors.black)
        .withOpacity(.65);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Insights',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: titleColor,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                '$streak-day streak • Avg mood ${avgLast7.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _MiniPill(
              icon: Icons.check_circle,
              label:
                  '${adherencePct.toStringAsFixed(0)}% logged',
              dark: dark,
            ),
          ],
        ),
      ],
    );
  }
}

// Row of two stat chips: last 7 days vs last 30 days
class _StatChipRow extends StatelessWidget {
  final double pct7;
  final double delta7;
  final double pct30;
  final double delta30;
  final bool dark;

  const _StatChipRow({
    required this.pct7,
    required this.delta7,
    required this.pct30,
    required this.delta30,
    required this.dark,
  });

  String _sign(double v) => v >= 0 ? '+' : '−';

  Widget _buildChip({
    required String label,
    required double pct,
    required double deltaPts,
  }) {
    final Color up = const Color(0xFF0D7C66);
    final Color down = const Color(0xFFD84A4A);
    final Color flat = Colors.grey.shade600;

    int dir;
    if (pct.abs() < 0.01 && deltaPts.abs() < 0.05) {
      dir = 0;
    } else {
      dir = pct >= 0 ? 1 : -1;
    }

    final Color accent =
        dir == 1 ? up : (dir == -1 ? down : flat);
    final IconData icon = dir == 1
        ? Icons.trending_up_rounded
        : (dir == -1
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded);

    final pctTxt =
        '${_sign(pct)}${(pct.abs() * 100).toStringAsFixed(0)}%';
    final deltaTxt =
        '${_sign(deltaPts)}${deltaPts.abs().toStringAsFixed(1)} pts';

    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: accent.withOpacity(.07),
          border: Border.all(
            color: accent.withOpacity(.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 18, color: accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w700,
                      color: accent,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              pctTxt,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: accent,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              deltaTxt,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
                color: accent
                    .withOpacity(.8),
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildChip(
          label: 'Last 7 days',
          pct: pct7,
          deltaPts: delta7,
        ),
        const SizedBox(width: 12),
        _buildChip(
          label: 'Last 30 days',
          pct: pct30,
          deltaPts: delta30,
        ),
      ],
    );
  }
}

// Trackers section = tabs + list + callouts
class _TrackersSection extends StatelessWidget {
  final bool dark;
  final _Range range;
  final ValueChanged<_Range> onRangeChanged;
  final List<_TrackerStat> rangeAverages;
  final _TrackerStat? bestTracker;
  final _TrackerStat? worstTracker;

  const _TrackersSection({
    required this.dark,
    required this.range,
    required this.onRangeChanged,
    required this.rangeAverages,
    required this.bestTracker,
    required this.worstTracker,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      dark: dark,
      sectionTitle: 'Your trackers',
      sectionSubtitle:
          'Averages + what to watch',
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // RANGE PICKER
          _RangePicker(
            range: range,
            onChanged: onRangeChanged,
          ),
          const SizedBox(height: 16),

          // AVERAGES LIST
          if (rangeAverages.isEmpty)
            _EmptyLine(
              text:
                  'No data yet. Log a few check-ins first.',
              dark: dark,
            )
          else
            Column(
              children: [
                for (final s in rangeAverages)
                  Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                                vertical: 6),
                    child:
                        _TrackerAverageRow(
                      stat: s,
                      dark: dark,
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 20),
          const Divider(
            thickness: 0.6,
            height: 0,
          ),
          const SizedBox(height: 16),

          // SIGNALS / CALL OUTS
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Signals',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w800,
                  color: dark
                      ? Colors.white
                      : const Color(
                          0xFF20312F),
                ),
              ),
              const SizedBox(height: 12),
              if (bestTracker != null)
                _SignalRow(
                  label:
                      'Improving the most',
                  stat: bestTracker!,
                  dark: dark,
                )
              else
                _EmptyLine(
                  text:
                      'Keep logging to spot improvements.',
                  dark: dark,
                ),
              const SizedBox(height: 12),
              if (worstTracker != null)
                _SignalRow(
                  label:
                      'Needs attention',
                  stat: worstTracker!,
                  dark: dark,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Tiny pill used in header row ("84% logged")
class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dark;
  const _MiniPill({
    required this.icon,
    required this.label,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = (dark ? Colors.white : Colors.black)
        .withOpacity(.07);
    final border =
        (dark ? Colors.white : Colors.black)
            .withOpacity(.15);
    final textColor =
        dark ? Colors.white : const Color(0xFF20312F);

    return Container(
      padding:
          const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            BorderRadius.circular(999),
        border: Border.all(
          color: border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: textColor
                  .withOpacity(.8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== REUSED WIDGETS / MODELS (unchanged logic) =====================

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
        color: (dark ? Colors.white : Colors.black)
            .withOpacity(.6),
      ),
    );
  }
}

// calendar, tracker rows, signal rows, bottom nav, models
// (copied straight from your file with no visual changes except what we've already done)
class _LoggingCalendar extends StatelessWidget {
  final DateTime monthAnchor;
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
    final monthStart =
        DateTime(monthAnchor.year, monthAnchor.month, 1);
    final startWeekday =
        monthStart.weekday % 7; // Sun=0
    final gridStart = monthStart
        .subtract(Duration(days: startWeekday));
    final days = List<DateTime>.generate(
      42,
      (i) => DateTime(
        gridStart.year,
        gridStart.month,
        gridStart.day + i,
      ),
    );
    final isDark =
        app.ThemeControllerScope.of(context).isDark;

    final Color onSurface = theme.colorScheme.onSurface;
    Color loggedColor = const Color(0xFF3E8F84);
    Color outMonthText = onSurface.withOpacity(.35);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              visualDensity:
                  VisualDensity.compact,
              onPressed: onPrev,
              icon: const Icon(
                  Icons.chevron_left),
            ),
            Text(
              DateFormat('MMMM yyyy')
                  .format(monthStart),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            IconButton(
              visualDensity:
                  VisualDensity.compact,
              onPressed: onNext,
              icon: const Icon(
                  Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            for (final d
                in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          onSurface.withOpacity(.6),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          padding: EdgeInsets.zero,
          physics:
              const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: days.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, idx) {
            final day = days[idx];
            final inMonth =
                day.month == monthStart.month;
            final logged = isLogged(day);

            return LayoutBuilder(
              builder:
                  (context, constraints) {
                final side = constraints
                    .biggest.shortestSide;
                final dia = side * 0.72;
                final bgColor = logged
                    ? loggedColor
                    : (isDark
                        ? Colors.white
                            .withOpacity(.06)
                        : Colors.black12
                            .withOpacity(.08));
                final border = logged
                    ? null
                    : Border.all(
                        color: Colors.black12,
                        width: 0.6,
                      );
                final textColor = inMonth
                    ? (logged
                        ? Colors.white
                        : onSurface)
                    : outMonthText;

                final circle = Center(
                  child: Container(
                    width: dia,
                    height: dia,
                    decoration:
                        BoxDecoration(
                      color: bgColor,
                      shape:
                          BoxShape.circle,
                      border: border,
                    ),
                    alignment:
                        Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize:
                            dia * 0.45,
                        fontWeight:
                            FontWeight.w800,
                        color: textColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                );

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(
                            dia / 2),
                    onTap: onDayTap == null
                        ? null
                        : () =>
                            onDayTap!(day),
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
    final chipBg = dark
        ? stat.color.withOpacity(.25)
        : stat.color.withOpacity(.12);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
              color: (dark
                      ? Colors.white
                      : Colors.black)
                  .withOpacity(.8),
            ),
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius:
                BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(
                  color: stat.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                stat.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                  color: dark
                      ? Colors.white
                      : const Color(
                          0xFF20312F),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                stat.mean
                    .toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w900,
                  color: dark
                      ? Colors.white
                      : const Color(
                          0xFF20312F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackerAverageRow
    extends StatelessWidget {
  final _TrackerStat stat;
  final bool dark;
  const _TrackerAverageRow({
    required this.stat,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final chipBg = dark
        ? stat.color.withOpacity(.25)
        : stat.color.withOpacity(.12);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(
                  color: stat.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  stat.label,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                    color: dark
                        ? Colors.white
                        : const Color(
                            0xFF20312F),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets
                  .symmetric(
                      horizontal: 12,
                      vertical: 6),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius:
                BorderRadius.circular(
                    999),
          ),
          child: Text(
            stat.mean
                .toStringAsFixed(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w900,
              color: dark
                  ? Colors.white
                  : const Color(
                      0xFF20312F),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomNav3 extends StatelessWidget {
  final int index;
  final String userName;
  const _BottomNav3({
    required this.index,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);
    const darkSelected = Color(0xFFBDA9DB);

    Color c(int i) {
      final dark =
          app.ThemeControllerScope.of(context).isDark;
      if (i == index) return dark
          ? darkSelected
          : green;
      return Colors.white;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: 8 +
            MediaQuery.of(context)
                .padding
                .bottom,
        top: 6,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              Icons.home,
              color: c(0),
            ),
            onPressed: () {
              if (Navigator.of(context)
                  .canPop()) {
                Navigator.of(context)
                    .pop();
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.menu_book,
              color: c(1),
            ),
            onPressed: () =>
                Navigator.pushReplacement(
              context,
              NoTransitionPageRoute(
                builder: (_) =>
                    JournalPage(
                  userName:
                      userName,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.settings,
              color: c(2),
            ),
            onPressed: () =>
                Navigator.pushReplacement(
              context,
              NoTransitionPageRoute(
                builder: (_) =>
                    SettingsPage(
                  userName:
                      userName,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NoTransitionPageRoute<T>
    extends MaterialPageRoute<T> {
  NoTransitionPageRoute({
    required WidgetBuilder builder,
  }) : super(builder: builder);
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> a,
    Animation<double> s,
    Widget child,
  ) =>
      child;
}

// Models
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
