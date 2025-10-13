// lib/pages/sleep_entry_editor.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SleepEntryEditorPage extends StatefulWidget {
  const SleepEntryEditorPage({
    super.key,
    this.sessionId,
    this.initialData,
  });

  /// If provided, we edit this existing session.
  final String? sessionId;
  final Map<String, dynamic>? initialData;

  @override
  State<SleepEntryEditorPage> createState() => _SleepEntryEditorPageState();
}

class _SleepEntryEditorPageState extends State<SleepEntryEditorPage> {
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
      Color(0xFFFDFBFF),
      Color(0xFFEAD7FF),
      Color(0xFFC7DDEA),
      Color(0xFF57C4B3),
    ],
    stops: [0.00, 0.32, 0.66, 1.00],
  );

  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 7, minute: 0);
  int _quality = 3;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      final start = (d['start'] as Timestamp).toDate();
      final end = (d['end'] as Timestamp).toDate();
      _date = DateTime(start.year, start.month, start.day);
      _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
      _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
      _quality = (d['quality'] as int?) ?? 3;
      _notesCtrl.text = (d['notes'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  DateTime _compose(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _save() async {
    var start = _compose(_date, _startTime);
    var end = _compose(_date, _endTime);
    // If the end time is <= start, assume it ends the next day (overnight)
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    final durationMin = end.difference(start).inMinutes;

    final data = {
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'durationMin': durationMin,
      'quality': _quality,
      'notes': _notesCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (widget.sessionId == null) 'createdAt': FieldValue.serverTimestamp(),
    };

    if (widget.sessionId == null) {
      await _sessionsCol.add(data);
    } else {
      await _sessionsCol.doc(widget.sessionId).update(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(_date);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.sessionId == null ? 'Add Sleep' : 'Edit Sleep',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: _toolsGradient)),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _Section(title: 'When'),
                _PickerTile(
                  icon: Icons.calendar_month_rounded,
                  label: 'Date',
                  value: dateStr,
                  onTap: _pickDate,
                ),
                _PickerTile(
                  icon: Icons.nightlight_round,
                  label: 'Sleep time',
                  value: _startTime.format(context),
                  onTap: _pickStart,
                ),
                _PickerTile(
                  icon: Icons.wb_sunny_rounded,
                  label: 'Wake time',
                  value: _endTime.format(context),
                  onTap: _pickEnd,
                ),
                const SizedBox(height: 16),
                _Section(title: 'Quality'),
                Row(
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      icon: Icon(
                        i < _quality ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber.shade700,
                      ),
                      onPressed: () => setState(() => _quality = i + 1),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Section(title: 'Notes'),
                Material(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _notesCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'How did you sleep?',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save'),
                ),
                const SizedBox(height: 12),
                if (widget.sessionId != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete sleep entry?'),
                          content: const Text('This action cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await _sessionsCol.doc(widget.sessionId).delete();
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF0D7C66)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(value, style: const TextStyle(color: Colors.black87)),
      ),
    );
  }
}
