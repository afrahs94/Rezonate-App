import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _custom = p.getStringList(_kStoreKey) ?? []);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kStoreKey, _custom);
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
    setState(() => _custom.removeAt(index));
    await _save();
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

  Widget _card(String text, {VoidCallback? onDelete}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _ink),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite_rounded, color: Color(0xFF0D7C66)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _ink),
                    ),
                    child: const Text(
                      "You don't have any yet. Tap “Add” to create your own.",
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
