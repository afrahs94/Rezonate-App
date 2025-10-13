// lib/pages/sleep_tracker.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'sleep_entry_editor.dart';

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

  // Same gradient used by Tools page
  static const LinearGradient _toolsGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFDFBFF), // near-white
      Color(0xFFEAD7FF), // lavender
      Color(0xFFC7DDEA), // misty blue
      Color(0xFF57C4B3), // teal
    ],
    stops: [0.00, 0.32, 0.66, 1.00],
  );

  String _durationString(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Sleep Tracker',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            tooltip: 'Add sleep',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SleepEntryEditorPage(),
                ),
              );
            },
          ),
        ],
      ),
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

                // --- Weekly stats (last 7 nights ending today) ---
                final now = DateTime.now();
                final sevenDaysAgo = now.subtract(const Duration(days: 7));
                int totalMin = 0;
                int nights = 0;
                for (final d in docs) {
                  final end = (d['end'] as Timestamp?)?.toDate();
                  if (end != null && end.isAfter(sevenDaysAgo)) {
                    final dur = (d['durationMin'] as int?) ??
                        end.difference((d['start'] as Timestamp).toDate()).inMinutes;
                    totalMin += dur;
                    nights++;
                  }
                }
                final avg = nights == 0 ? 0 : totalMin ~/ nights;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: _StatsCard(
                          nights: nights,
                          avgStr: _durationString(avg),
                          totalStr: _durationString(totalMin),
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

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                            child: _SleepCard(
                              start: start,
                              end: end,
                              durationStr: _durationString(durMin),
                              quality: qual,
                              notes: notes,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SleepEntryEditorPage(
                                      sessionId: id,
                                      initialData: data,
                                    ),
                                  ),
                                );
                              },
                              onDelete: () async {
                                await _sessionsCol.doc(id).delete();
                              },
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
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.nights,
    required this.avgStr,
    required this.totalStr,
  });

  final int nights;
  final String avgStr;
  final String totalStr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.nightlight_round, color: Color(0xFF0D7C66)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                _StatChip(label: 'This week', value: '$nights nights'),
                const SizedBox(width: 8),
                _StatChip(label: 'Avg', value: avgStr),
                const SizedBox(width: 8),
                _StatChip(label: 'Total', value: totalStr),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard({
    required this.start,
    required this.end,
    required this.durationStr,
    required this.quality,
    required this.notes,
    required this.onTap,
    required this.onDelete,
  });

  final DateTime start;
  final DateTime end;
  final String durationStr;
  final int quality;
  final String notes;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, h:mm a');
    return Material(
      color: Colors.white.withOpacity(0.62),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bedtime_rounded, size: 26, color: Color(0xFF0D7C66)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${fmt.format(start)} → ${DateFormat('h:mm a').format(end)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _QualityStars(quality: quality),
                        const SizedBox(width: 10),
                        Text(durationStr, style: const TextStyle(color: Colors.black87)),
                      ],
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
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
