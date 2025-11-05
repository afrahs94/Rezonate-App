// lib/pages/sleep_tracker.dart
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'sleep_entry_editor.dart';

enum RangeOption { week, month, all }

class SleepTrackerPage extends StatefulWidget {
  const SleepTrackerPage({super.key});
  @override
  State<SleepTrackerPage> createState() => _SleepTrackerPageState();
}

class _SleepTrackerPageState extends State<SleepTrackerPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser!.uid;
  CollectionReference<Map<String, dynamic>> get _sessionsCol =>
      _db.collection('users').doc(_uid).collection('sleepSessions');

  static const LinearGradient _toolsGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFDFBFF), Color(0xFFEAD7FF), Color(0xFFC7DDEA), Color(0xFF57C4B3)],
    stops: [0.00, 0.32, 0.66, 1.00],
  );

  String _durationString(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  RangeOption _range = RangeOption.week;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: _toolsGradient)),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _sessionsCol.orderBy('start', descending: true).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;

                // Stats (last 7 days)
                final now = DateTime.now();
                final sevenDaysAgo = now.subtract(const Duration(days: 7));
                int totalMin = 0, nights = 0;
                for (final d in docs) {
                  final end = (d['end'] as Timestamp?)?.toDate();
                  if (end != null && end.isAfter(sevenDaysAgo)) {
                    final start = (d['start'] as Timestamp).toDate();
                    final dur = (d['durationMin'] as int?) ?? end.difference(start).inMinutes;
                    totalMin += dur;
                    nights++;
                  }
                }
                final avg = nights == 0 ? 0 : totalMin ~/ nights;

                final trendPoints = _buildTrendPoints(docs, _range);

                return CustomScrollView(
                  slivers: [
                    // Scrollable header (title scrolls away)
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      centerTitle: true,
                      floating: false,
                      pinned: false,
                      snap: false,
                      title: const Text('Sleep Tracker',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                      actions: [
                        IconButton(
                          tooltip: 'Add sleep',
                          icon: const Icon(Icons.add_rounded, color: Colors.black),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SleepEntryEditorPage()),
                            );
                          },
                        ),
                      ],
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _StatsCard(
                          nights: nights,
                          avgStr: _durationString(avg),
                          totalStr: _durationString(totalMin),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _TrendCard(
                          range: _range,
                          onRangeChanged: (r) => setState(() => _range = r),
                          points: trendPoints,
                        ),
                      ),
                    ),
                    if (docs.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'No sleep logged yet.\nTap + to add your first night.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final d = docs[i];
                          final id = d.id;
                          final data = d.data();
                          final start = (data['start'] as Timestamp).toDate();
                          final end = (data['end'] as Timestamp).toDate();
                          final qual = (data['quality'] as int?) ?? 3;
                          final notes = (data['notes'] as String?) ?? '';
                          final durMin = (data['durationMin'] as int?) ??
                              end.difference(start).inMinutes;

                          final mood = (data['mood'] as int?) ?? 3;
                          final caffeine = (data['caffeine'] as bool?) ?? false;
                          final alcohol = (data['alcohol'] as bool?) ?? false;
                          final exercise = (data['exercise'] as bool?) ?? false;
                          final snoring = (data['snoring'] as bool?) ?? false;
                          final awakenings = (data['awakenings'] as int?) ?? 0;
                          final napMin = (data['napMin'] as int?) ?? 0;
                          final efficiency = (data['sleepEfficiency'] as int?) ?? -1;

                          final screenTimeMin = (data['screenTimeMin'] as int?) ?? 0;
                          final roomTempF = (data['roomTempF'] as int?) ?? 72;
                          final stress = (data['stress'] as int?) ?? 3;
                          final blueLight = (data['blueLight'] as bool?) ?? false;
                          final medication = (data['medication'] as bool?) ?? false;
                          final lateMeal = (data['lateMeal'] as bool?) ?? false;

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                            child: _SleepCard(
                              start: start,
                              end: end,
                              durationStr: _durationString(durMin),
                              quality: qual,
                              notes: notes,
                              mood: mood,
                              caffeine: caffeine,
                              alcohol: alcohol,
                              exercise: exercise,
                              snoring: snoring,
                              awakenings: awakenings,
                              napMin: napMin,
                              efficiency: efficiency,
                              screenTimeMin: screenTimeMin,
                              roomTempF: roomTempF,
                              stress: stress,
                              blueLight: blueLight,
                              medication: medication,
                              lateMeal: lateMeal,
                              onView: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => _SleepViewDialog(
                                    data: data,
                                    durationStr: _durationString(durMin),
                                  ),
                                );
                              },
                              onEdit: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SleepEntryEditorPage(sessionId: id, initialData: data),
                                  ),
                                );
                              },
                              onDelete: () async => _sessionsCol.doc(id).delete(),
                            ),
                          );
                        },
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_Point> _buildTrendPoints(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    RangeOption r,
  ) {
    final now = DateTime.now();
    DateTime start;
    if (r == RangeOption.week) {
      start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    } else if (r == RangeOption.month) {
      start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    } else {
      if (docs.isEmpty) return const [];
      final ends = docs
          .map((d) => (d['end'] as Timestamp?)?.toDate())
          .whereType<DateTime>()
          .toList()
        ..sort();
      start = DateTime(ends.first.year, ends.first.month, ends.first.day);
    }
    final endDay = DateTime(now.year, now.month, now.day);
    final dayCount = endDay.difference(start).inDays + 1;
    final buckets = List<int>.filled(dayCount, 0);

    for (final d in docs) {
      final a = (d['start'] as Timestamp?)?.toDate();
      final b = (d['end'] as Timestamp?)?.toDate();
      if (a == null || b == null) continue;
      final day = DateTime(b.year, b.month, b.day);
      if (day.isBefore(start) || day.isAfter(endDay)) continue;
      final idx = day.difference(start).inDays;
      final dur = (d['durationMin'] as int?) ?? b.difference(a).inMinutes;
      buckets[idx] += math.max(0, dur);
    }

    return List.generate(
      buckets.length,
      (i) => _Point(start.add(Duration(days: i)), buckets[i].toDouble()),
    );
  }
}

/* =====================  HEADER (Stats + Moon)  ===================== */

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.nights, required this.avgStr, required this.totalStr});
  final int nights;
  final String avgStr;
  final String totalStr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          _MoonProgress(nights: nights),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _StatBlock(label: 'This week', value: '$nights nights')),
                const SizedBox(width: 10),
                Expanded(child: _StatBlock(label: 'Avg', value: avgStr)),
                const SizedBox(width: 10),
                Expanded(child: _StatBlock(label: 'Total', value: totalStr)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}

/// Animated crescent moon that grows with `nights`.
class _MoonProgress extends StatefulWidget {
  const _MoonProgress({required this.nights});
  final int nights;

  @override
  State<_MoonProgress> createState() => _MoonProgressState();
}

class _MoonProgressState extends State<_MoonProgress> {
  double _prevPhase = 0;

  @override
  void didUpdateWidget(covariant _MoonProgress oldWidget) {
    _prevPhase = oldWidget.nights.clamp(0, 7) / 7.0;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final targetPhase = widget.nights.clamp(0, 7) / 7.0;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOut,
      tween: Tween(begin: _prevPhase, end: targetPhase),
      builder: (context, phase, _) {
        final size = ui.lerpDouble(18, 46, phase)!;
        return CustomPaint(
          painter: _MoonPainter(phase: phase),
          size: Size.square(size),
        );
      },
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter({required this.phase});
  final double phase; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    // Soft glow
    final glow = Paint()
      ..color = const Color(0xFFFFF8E1).withOpacity(.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, r * 0.92, glow);

    // Colors
    const ringColor = Color(0xFF37474F);
    const litColor = Color(0xFFFFF8E1);

    // Build paths
    final base = Path()..addOval(Rect.fromCircle(center: center, radius: r * 0.92));

    // Overlap circle to carve the crescent (moves left as phase increases)
    final maskRadius = r * ui.lerpDouble(0.90, 1.02, phase)!;
    final offsetX = ui.lerpDouble(r * 0.95, -r * 0.95, phase)!;
    final mask = Path()
      ..addOval(Rect.fromCircle(center: Offset(center.dx + offsetX, center.dy), radius: maskRadius));

    // Crescent = base MINUS mask
    final crescent = Path.combine(PathOperation.difference, base, mask);

    // Fill crescent
    final litPaint = Paint()..color = litColor;
    canvas.drawPath(crescent, litPaint);

    // Stroke crescent outer edge for definition
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = ringColor.withOpacity(.9);
    canvas.drawPath(crescent, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _MoonPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

/* =====================  TREND CARD + CHART  ===================== */

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.range,
    required this.onRangeChanged,
    required this.points,
  });

  final RangeOption range;
  final void Function(RangeOption) onRangeChanged;
  final List<_Point> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Trends',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              _RangeChip(label: 'Week', selected: range == RangeOption.week, onTap: () => onRangeChanged(RangeOption.week)),
              const SizedBox(width: 6),
              _RangeChip(label: 'Month', selected: range == RangeOption.month, onTap: () => onRangeChanged(RangeOption.month)),
              const SizedBox(width: 6),
              _RangeChip(label: 'All', selected: range == RangeOption.all, onTap: () => onRangeChanged(RangeOption.all)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: _SleepChart(points: points),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D7C66) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? const Color(0xFF0D7C66) : Colors.black12),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }
}

class _Point {
  final DateTime day;
  final double minutes;
  const _Point(this.day, this.minutes);
}

class _SleepChart extends StatelessWidget {
  const _SleepChart({required this.points});
  final List<_Point> points;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox.expand(
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _ChartPainter(points),
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points);
  final List<_Point> points;

  static const _purple = Color(0xFF7E3FF2);

  @override
  void paint(Canvas canvas, Size size) {
    final bgRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(12));
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [Colors.white, const Color(0xFFF8FFFD)],
      );
    canvas.drawRRect(bgRRect, bgPaint);

    if (points.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(text: 'No data', style: TextStyle(color: Colors.black54)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }

    final left = 52.0, right = 18.0, top = 16.0, bottom = 34.0;
    final chart = Rect.fromLTWH(left, top, size.width - left - right, size.height - top - bottom);

    double maxMin = points.fold<double>(0, (m, p) => math.max(m, p.minutes));
    maxMin = math.max(480, maxMin); // at least 8h
    const yStep = 120.0; // 2h steps

    final grid = Paint()
      ..color = const Color(0xFF0D7C66).withOpacity(.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double m = 0; m <= maxMin; m += yStep) {
      final y = chart.bottom - (m / maxMin) * chart.height;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);

      final label = TextPainter(
        text: TextSpan(
            text: '${(m ~/ 60)}h',
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: left - 10);
      label.paint(canvas, Offset(8, y - label.height / 2));
    }

    final count = points.length;
    final stepX = count > 1 ? chart.width / (count - 1) : 0;

    Offset pt(int i) {
      final x = chart.left + stepX * i;
      final y = chart.bottom - (points[i].minutes / maxMin) * chart.height;
      return Offset(x, y);
    }

    final path = Path();
    final area = Path();

    final first = pt(0);
    path.moveTo(first.dx, first.dy);
    area.moveTo(chart.left, chart.bottom);
    area.lineTo(first.dx, first.dy);

    for (int i = 1; i < count; i++) {
      final p0 = pt(i - 1);
      final p1 = pt(i);
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      area.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    final last = pt(count - 1);
    path.lineTo(last.dx, last.dy);
    area.lineTo(last.dx, last.dy);
    area.lineTo(chart.right, chart.bottom);
    area.close();

    final mean = points.fold<double>(0, (s, p) => s + p.minutes) / points.length;
    final meanY = chart.bottom - (mean / maxMin) * chart.height;
    final dash = Paint()
      ..color = const Color(0xFF0D7C66).withOpacity(.45)
      ..strokeWidth = 1.2;
    const dashW = 6.0, gap = 4.0;
    for (double x = chart.left; x < chart.right; x += dashW + gap) {
      canvas.drawLine(Offset(x, meanY), Offset(math.min(x + dashW, chart.right), meanY), dash);
    }

    final areaPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(chart.left, chart.top),
        Offset(chart.left, chart.bottom),
        [const Color(0xFF0D7C66).withOpacity(.18), const Color(0xFF0D7C66).withOpacity(.06)],
      );
    canvas.drawPath(area, areaPaint);

    // Purple line + dots
    canvas.drawPath(
      path,
      Paint()
        ..color = _purple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final dotPaint = Paint()..color = _purple;
    for (int i = 0; i < count; i++) {
      final p = pt(i);
      canvas.drawCircle(p, 3.2, dotPaint);
    }

    final fmt = DateFormat('MM/dd');
    final startLab = TextPainter(
      text: TextSpan(text: fmt.format(points.first.day), style: const TextStyle(fontSize: 12, color: Colors.black54)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final midIdx = (count - 1) ~/ 2;
    final midLab = TextPainter(
      text: TextSpan(text: fmt.format(points[midIdx].day), style: const TextStyle(fontSize: 12, color: Colors.black45)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final endLab = TextPainter(
      text: TextSpan(text: fmt.format(points.last.day), style: const TextStyle(fontSize: 12, color: Colors.black54)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    startLab.paint(canvas, Offset(chart.left, chart.bottom + 8));
    midLab.paint(canvas, Offset(chart.left + chart.width / 2 - midLab.width / 2, chart.bottom + 8));
    endLab.paint(canvas, Offset(chart.right - endLab.width, chart.bottom + 8));

    canvas.drawLine(
      Offset(chart.left, chart.bottom),
      Offset(chart.right, chart.bottom),
      Paint()
        ..color = Colors.black12
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.points != points;
}

/* =====================  SLEEP LOG CARDS  ===================== */

class _SleepCard extends StatefulWidget {
  const _SleepCard({
    required this.start,
    required this.end,
    required this.durationStr,
    required this.quality,
    required this.notes,
    required this.mood,
    required this.caffeine,
    required this.alcohol,
    required this.exercise,
    required this.snoring,
    required this.awakenings,
    required this.napMin,
    required this.efficiency,
    required this.screenTimeMin,
    required this.roomTempF,
    required this.stress,
    required this.blueLight,
    required this.medication,
    required this.lateMeal,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final DateTime start;
  final DateTime end;
  final String durationStr;
  final int quality;
  final String notes;

  final int mood;
  final bool caffeine;
  final bool alcohol;
  final bool exercise;
  final bool snoring;
  final int awakenings;
  final int napMin;
  final int efficiency;

  final int screenTimeMin;
  final int roomTempF;
  final int stress;
  final bool blueLight;
  final bool medication;
  final bool lateMeal;

  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_SleepCard> createState() => _SleepCardState();
}

class _SleepCardState extends State<_SleepCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, h:mm a');
    return Material(
      color: Colors.white.withOpacity(0.62),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onView,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bedtime_rounded, size: 26, color: Color(0xFF0D7C66)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${fmt.format(widget.start)} → ${DateFormat('h:mm a').format(widget.end)}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _QualityStars(quality: widget.quality),
                            const SizedBox(width: 10),
                            Text(widget.durationStr, style: const TextStyle(color: Colors.black87)),
                          ],
                        ),
                        if (widget.notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(widget.notes,
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'view') widget.onView();
                      if (v == 'edit') widget.onEdit();
                      if (v == 'delete') widget.onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'view', child: Text('View')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Smaller "other options" row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _ViewPill(icon: Icons.coffee_rounded, label: 'Caffeine', value: widget.caffeine ? 'Yes' : 'No'),
                    const SizedBox(width: 6),
                    _ViewPill(icon: Icons.local_bar_rounded, label: 'Alcohol', value: widget.alcohol ? 'Yes' : 'No'),
                    const SizedBox(width: 6),
                    _ViewPill(icon: Icons.fitness_center_rounded, label: 'Exercise', value: widget.exercise ? 'Yes' : 'No'),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                    label: Text(_expanded ? 'Less details' : 'More details'),
                  ),
                ],
              ),

              AnimatedCrossFade(
                crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 180),
                firstChild: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ViewValue(icon: Icons.bed_rounded, label: 'Awakenings', value: '${widget.awakenings}'),
                      _ViewValue(icon: Icons.airline_seat_individual_suite_rounded, label: 'Naps', value: '${widget.napMin}m'),
                      _ViewValue(icon: Icons.percent_rounded, label: 'Efficiency',
                          value: widget.efficiency < 0 ? '—' : '${widget.efficiency}%'),
                      _ViewValue(icon: Icons.phone_android_rounded, label: 'Screen time', value: '${widget.screenTimeMin}m'),
                      _ViewValue(icon: Icons.thermostat_rounded, label: 'Room temp', value: '${widget.roomTempF}°F'),
                      _ViewValue(icon: Icons.mood_rounded, label: 'Score', value: '${widget.mood}'),
                      _ViewValue(icon: Icons.psychology_rounded, label: 'Stress', value: '${widget.stress}'),
                      _ViewPill(icon: Icons.light_mode_rounded, label: 'Blue light', value: widget.blueLight ? 'Yes' : 'No'),
                      _ViewPill(icon: Icons.medication_rounded, label: 'Medication', value: widget.medication ? 'Yes' : 'No'),
                      _ViewPill(icon: Icons.restaurant_rounded, label: 'Late meal', value: widget.lateMeal ? 'Yes' : 'No'),
                      _ViewPill(icon: Icons.snooze_rounded, label: 'Snoring', value: widget.snoring ? 'Yes' : 'No'),
                    ],
                  ),
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityStars extends StatelessWidget {
  const _QualityStars({required this.quality});
  final int quality;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (i) => Icon(
          i < quality ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 18,
          color: Colors.amber.shade700,
        ),
      ),
    );
  }
}

class _ViewPill extends StatelessWidget {
  const _ViewPill({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 5),
          Text(value, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ViewValue extends StatelessWidget {
  const _ViewValue({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 5),
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SleepViewDialog extends StatelessWidget {
  const _SleepViewDialog({required this.data, required this.durationStr});
  final Map<String, dynamic> data;
  final String durationStr;

  @override
  Widget build(BuildContext context) {
    final start = (data['start'] as Timestamp?)?.toDate();
    final end = (data['end'] as Timestamp?)?.toDate();
    final qual = (data['quality'] as int?) ?? 3;
    final notes = (data['notes'] as String?) ?? '';

    final fmt = DateFormat('EEE, MMM d • h:mm a');
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: Text(k, style: const TextStyle(color: Colors.black54))),
              const SizedBox(width: 8),
              Expanded(child: Text(v)),
            ],
          ),
        );

    return AlertDialog(
      title: const Text('Sleep log'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row('Start', start != null ? fmt.format(start) : '—'),
            row('End', end != null ? DateFormat('h:mm a').format(end) : '—'),
            row('Duration', durationStr),
            row('Quality', '$qual / 5'),
            row('Caffeine', ((data['caffeine'] as bool?) ?? false) ? 'Yes' : 'No'),
            row('Alcohol', ((data['alcohol'] as bool?) ?? false) ? 'Yes' : 'No'),
            row('Exercise', ((data['exercise'] as bool?) ?? false) ? 'Yes' : 'No'),
            row('Snoring', ((data['snoring'] as bool?) ?? false) ? 'Yes' : 'No'),
            if ((data['awakenings'] as int?) != null) row('Awakenings', '${data['awakenings']}'),
            if ((data['napMin'] as int?) != null) row('Naps', '${data['napMin']}m'),
            if ((data['sleepEfficiency'] as int?) != null) row('Efficiency', '${data['sleepEfficiency']}%'),
            if ((data['mood'] as int?) != null) row('Mood', '${data['mood']} / 5'),
            if ((data['screenTimeMin'] as int?) != null) row('Screen time', '${data['screenTimeMin']}m'),
            if ((data['roomTempF'] as int?) != null) row('Room temp', '${data['roomTempF']}°F'),
            if ((data['stress'] as int?) != null) row('Stress', '${data['stress']} / 5'),
            row('Blue light', ((data['blueLight'] as bool?) ?? false) ? 'Yes' : 'No'),
            row('Medication', ((data['medication'] as bool?) ?? false) ? 'Yes' : 'No'),
            row('Late meal', ((data['lateMeal'] as bool?) ?? false) ? 'Yes' : 'No'),
            if (notes.isNotEmpty) row('Notes', notes),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
