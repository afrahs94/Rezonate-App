// lib/pages/sleep_entry_editor.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SleepEntryEditorPage extends StatefulWidget {
  const SleepEntryEditorPage({super.key, this.sessionId, this.initialData});

  final String? sessionId;
  final Map<String, dynamic>? initialData;

  @override
  State<SleepEntryEditorPage> createState() => _SleepEntryEditorPageState();
}

class _SleepEntryEditorPageState extends State<SleepEntryEditorPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get _doc => _db
      .collection('users')
      .doc(_uid)
      .collection('sleepSessions')
      .doc(widget.sessionId ?? _db.collection('_').doc().id);

  late DateTime _date;
  late TimeOfDay _sleepTime;
  late TimeOfDay _wakeTime;

  int _quality = 3;
  String _notes = '';

  bool _caffeine = false;
  bool _alcohol = false;
  bool _exercise = false;
  bool _snoring = false;
  int _awakenings = 0;
  int _napMin = 0;
  int _efficiency = -1;
  int _mood = 3;

  int _screenTimeMin = 0;
  int _roomTempF = 72;
  int _stress = 3;
  bool _blueLight = false;
  bool _medication = false;
  bool _lateMeal = false;

  final _notesCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _sleepTime = const TimeOfDay(hour: 23, minute: 0);
    _wakeTime = const TimeOfDay(hour: 7, minute: 0);

    if (widget.initialData != null) {
      final d = widget.initialData!;
      final start = (d['start'] as Timestamp?)?.toDate() ?? now;
      final end = (d['end'] as Timestamp?)?.toDate() ?? now.add(const Duration(hours: 8));
      _date = DateTime(start.year, start.month, start.day);
      _sleepTime = TimeOfDay(hour: start.hour, minute: start.minute);
      _wakeTime = TimeOfDay(hour: end.hour, minute: end.minute);
      _quality = (d['quality'] as int?) ?? 3;
      _notes = (d['notes'] as String?) ?? '';
      _notesCtl.text = _notes;

      _caffeine = (d['caffeine'] as bool?) ?? false;
      _alcohol = (d['alcohol'] as bool?) ?? false;
      _exercise = (d['exercise'] as bool?) ?? false;
      _snoring = (d['snoring'] as bool?) ?? false;
      _awakenings = (d['awakenings'] as int?) ?? 0;
      _napMin = (d['napMin'] as int?) ?? 0;
      _efficiency = (d['sleepEfficiency'] as int?) ?? -1;
      _mood = (d['mood'] as int?) ?? 3;

      _screenTimeMin = (d['screenTimeMin'] as int?) ?? 0;
      _roomTempF = (d['roomTempF'] as int?) ?? 72;
      _stress = (d['stress'] as int?) ?? 3;
      _blueLight = (d['blueLight'] as bool?) ?? false;
      _medication = (d['medication'] as bool?) ?? false;
      _lateMeal = (d['lateMeal'] as bool?) ?? false;
    }
  }

  DateTime _combine(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p != null) setState(() => _date = p);
  }

  Future<void> _pickTime({required bool sleep}) async {
    final init = sleep ? _sleepTime : _wakeTime;
    final p = await showTimePicker(context: context, initialTime: init);
    if (p != null) setState(() => sleep ? _sleepTime = p : _wakeTime = p);
  }

  Future<void> _save() async {
    final start = _combine(_date, _sleepTime);
    var end = _combine(_date, _wakeTime);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    final durMin = end.difference(start).inMinutes;

    final data = <String, dynamic>{
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'durationMin': durMin,
      'quality': _quality,
      'notes': _notesCtl.text.trim(),
      'caffeine': _caffeine,
      'alcohol': _alcohol,
      'exercise': _exercise,
      'snoring': _snoring,
      'awakenings': _awakenings,
      'napMin': _napMin,
      'sleepEfficiency': _efficiency,
      'mood': _mood,
      'screenTimeMin': _screenTimeMin,
      'roomTempF': _roomTempF,
      'stress': _stress,
      'blueLight': _blueLight,
      'medication': _medication,
      'lateMeal': _lateMeal,
    };

    await _doc.set(data, SetOptions(merge: true));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE, MMM d, yyyy');
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.sessionId == null ? 'Add Sleep' : 'Edit Sleep',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check_rounded)),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFDFBFF), // near-white
                    Color(0xFFEAD7FF), // lavender
                    Color(0xFFC7DDEA), // misty blue
                    Color(0xFF57C4B3), // teal
                  ],
                  stops: [0.00, 0.32, 0.66, 1.00],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const _SectionHeader('When'),
                _PickerTile(
                  icon: Icons.calendar_month_rounded,
                  label: 'Date',
                  trailing: fmt.format(_date),
                  onTap: _pickDate,
                ),
                _PickerTile(
                  icon: Icons.nightlight_round,
                  label: 'Sleep time',
                  trailing: _sleepTime.format(context),
                  onTap: () => _pickTime(sleep: true),
                ),
                _PickerTile(
                  icon: Icons.wb_sunny_rounded,
                  label: 'Wake time',
                  trailing: _wakeTime.format(context),
                  onTap: () => _pickTime(sleep: false),
                ),

                const SizedBox(height: 16),
                const _SectionHeader('Quality'),
                _StarsPicker(
                  value: _quality,
                  onChanged: (v) => setState(() => _quality = v),
                ),

                const SizedBox(height: 16),
                const _SectionHeader('Habits & Environment'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ToggleChip(
                      icon: Icons.coffee_rounded,
                      label: 'Caffeine',
                      value: _caffeine,
                      onChanged: (v) => setState(() => _caffeine = v),
                    ),
                    _ToggleChip(
                      icon: Icons.local_bar_rounded,
                      label: 'Alcohol',
                      value: _alcohol,
                      onChanged: (v) => setState(() => _alcohol = v),
                    ),
                    _ToggleChip(
                      icon: Icons.fitness_center_rounded,
                      label: 'Exercise',
                      value: _exercise,
                      onChanged: (v) => setState(() => _exercise = v),
                    ),
                    _ToggleChip(
                      icon: Icons.light_mode_rounded,
                      label: 'Blue light',
                      value: _blueLight,
                      onChanged: (v) => setState(() => _blueLight = v),
                    ),
                    _ToggleChip(
                      icon: Icons.medication_rounded,
                      label: 'Medication',
                      value: _medication,
                      onChanged: (v) => setState(() => _medication = v),
                    ),
                    _ToggleChip(
                      icon: Icons.restaurant_rounded,
                      label: 'Late meal',
                      value: _lateMeal,
                      onChanged: (v) => setState(() => _lateMeal = v),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const _SectionHeader('Metrics'),
                _NumberField(
                  icon: Icons.bed_rounded,
                  label: 'Awakenings',
                  initial: _awakenings,
                  min: 0,
                  max: 20,
                  onChanged: (v) => _awakenings = v,
                ),
                _NumberField(
                  icon: Icons.airline_seat_individual_suite_rounded,
                  label: 'Naps (min)',
                  initial: _napMin,
                  min: 0,
                  max: 600,
                  onChanged: (v) => _napMin = v,
                ),
                _NumberField(
                  icon: Icons.percent_rounded,
                  label: 'Efficiency %',
                  initial: _efficiency < 0 ? 0 : _efficiency,
                  min: 0,
                  max: 100,
                  onChanged: (v) => _efficiency = v,
                ),
                _NumberField(
                  icon: Icons.phone_android_rounded,
                  label: 'Screen time (min)',
                  initial: _screenTimeMin,
                  min: 0,
                  max: 600,
                  onChanged: (v) => _screenTimeMin = v,
                ),
                _NumberField(
                  icon: Icons.thermostat_rounded,
                  label: 'Room temp (°F)',
                  initial: _roomTempF,
                  min: 40,
                  max: 95,
                  onChanged: (v) => _roomTempF = v,
                ),

                const SizedBox(height: 12),
                const _SectionHeader('Scores'),
                _SliderRow(
                  icon: Icons.mood_rounded,
                  label: 'Mood',
                  value: _mood.toDouble(),
                  onChanged: (d) => setState(() => _mood = d.round()),
                ),
                _SliderRow(
                  icon: Icons.psychology_rounded,
                  label: 'Stress',
                  value: _stress.toDouble(),
                  onChanged: (d) => setState(() => _stress = d.round()),
                ),

                const SizedBox(height: 16),
                const _SectionHeader('Notes'),
                TextField(
                  controller: _notesCtl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'How did you sleep?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    filled: true,
                  ),
                ),

                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7C66),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------- UI bits (unchanged in behavior) -------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      );
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF0D7C66)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Text(trailing, style: const TextStyle(color: Colors.black54)),
      ),
    );
  }
}

class _StarsPicker extends StatelessWidget {
  const _StarsPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < value;
        return IconButton(
          onPressed: () => onChanged(i + 1),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: Colors.amber.shade700,
          ),
        );
      }),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final sel = value;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF0D7C66) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? const Color(0xFF0D7C66) : Colors.black12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: sel ? Colors.white : Colors.black87),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: sel ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.icon,
    required this.label,
    required this.initial,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final int initial;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ctl = TextEditingController(text: '$initial');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF0D7C66)),
          labelText: label,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          filled: true,
        ),
        onChanged: (s) {
          final v = int.tryParse(s) ?? initial;
          onChanged(v.clamp(min, max));
        },
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0D7C66)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 1,
            max: 5,
            divisions: 4,
            label: value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
