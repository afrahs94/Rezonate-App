// lib/pages/matching.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* Shared look & scaffold */
BoxDecoration _bg(BuildContext context) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xFF2A2336), Color(0xFF1B4F4A)]
          : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF6FD6C1)],
    ),
  );
}
const _ink = Colors.black;

class _GameScaffold extends StatelessWidget {
  final String title;
  final String rule;
  final Widget child;
  final Widget? topBar;
  const _GameScaffold({required this.title, required this.rule, required this.child, this.topBar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _ink),
                  ),
                  child: Text(rule, textAlign: TextAlign.center),
                ),
                if (topBar != null) ...[const SizedBox(height: 8), topBar!],
                const SizedBox(height: 10),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* Score store */
class ScoreStore {
  ScoreStore._();
  static final instance = ScoreStore._();
  Future<void> add(String gameKey, double v) async {
    final prefs = await SharedPreferences.getInstance();
    final k = 'sbp_$gameKey';
    final cur = prefs.getStringList(k) ?? [];
    cur.add(v.toString());
    await prefs.setStringList(k, cur);
  }
  Future<bool> reportBest(String gameKey, double score) async {
    final prefs = await SharedPreferences.getInstance();
    final bestKey = 'sbp_best_$gameKey';
    final prev = prefs.getDouble(bestKey) ?? double.negativeInfinity;
    if (score > prev) {
      await prefs.setDouble(bestKey, score);
      return true;
    }
    return false;
  }
}

class MatchDifficultPage extends StatefulWidget {
  const MatchDifficultPage({super.key});
  @override
  State<MatchDifficultPage> createState() => _MatchDifficultPageState();
}

class _MatchDifficultPageState extends State<MatchDifficultPage> with TickerProviderStateMixin {
  static const int pairs = 10; // 20 cards
  final rnd = Random();
  late List<int> deck;   // two of each id
  late List<bool> faceUp;
  late List<bool> removed; // NEW: cards removed after a successful match
  int? first;
  int moves = 0;
  int matched = 0;
  late DateTime _start;

  late List<IconData> _iconSet;

  // Win animation overlay
  OverlayEntry? _winOverlay;

  @override
  void initState() { super.initState(); _new(); }

  void _new() {
    _iconSet = [
      Icons.spa_rounded,
      Icons.ac_unit_rounded,
      Icons.waves_rounded,
      Icons.star_rounded,
      Icons.favorite_rounded,
      Icons.landscape_rounded,
      Icons.pets_rounded,
      Icons.local_florist_rounded,
      Icons.park_rounded,
      Icons.flutter_dash,
    ]..shuffle(rnd);
    deck = List.generate(pairs, (i) => i)..addAll(List.generate(pairs, (i) => i));
    deck.shuffle(rnd);
    faceUp = List.filled(deck.length, false);
    removed = List.filled(deck.length, false);
    first = null; moves = 0; matched = 0;
    _start = DateTime.now();
    setState(() {});
  }

  Future<void> _flip(int i) async {
    if (removed[i] || faceUp[i]) return;
    setState(() { faceUp[i] = true; });
    if (first == null) {
      first = i;
    } else if (first != i) {
      moves++;
      if (deck[first!] == deck[i]) {
        final a = first!;
        final b = i;
        first = null;
        // brief delay so the second card is visible, then animate removal
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        setState(() {
          removed[a] = true;
          removed[b] = true;
        });
        matched += 2;

        if (matched == deck.length) {
          final secs = DateTime.now().difference(_start).inSeconds.clamp(1, 99999);
          final score = (pairs / secs);
          await ScoreStore.instance.add('matchhard', score);
          final high = await ScoreStore.instance.reportBest('matchhard', score);
          if (!mounted) return;

          _showWinAnimation();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(high ? 'New high score!' : 'Done in $moves moves'),
          ));
          await Future.delayed(const Duration(milliseconds: 1400));
          _hideWinAnimation();
        }
      } else {
        final prev = first!;
        first = null;
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        setState(() { faceUp[i] = false; faceUp[prev] = false; });
      }
    }
  }

  void _showWinAnimation() {
    if (_winOverlay != null) return;
    final entry = OverlayEntry(
      builder: (ctx) => _WinConfettiOverlay(vsync: this),
    );
    _winOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  void _hideWinAnimation() {
    _winOverlay?.remove();
    _winOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = Colors.primaries.take(pairs).toList();
    return _GameScaffold(
      title: 'Matching',
      rule: 'Flip cards to find pairs. New icons & colors each shuffle.',
      topBar: Row(
        children: [
          Text('Moves: $moves', style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _new,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Restart'), // was "Shuffle"
          ),
        ],
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: deck.length,
        itemBuilder: (_, i) {
          final open = faceUp[i];
          final gone = removed[i];
          final id = deck[i];

          // When removed, fade & scale out and ignore taps.
          final tile = AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: gone ? 0.0 : 1.0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: gone ? 0.85 : 1.0,
              child: GestureDetector(
                onTap: gone ? null : () => _flip(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: Matrix4.identity()..scale(open ? 1.0 : 0.98),
                  decoration: BoxDecoration(
                    gradient: open
                        ? LinearGradient(colors: [palette[id].shade200, palette[id].shade400])
                        : const LinearGradient(colors: [Colors.white, Color(0xFFF6F6F6)]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _ink),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: open
                        ? Icon(_iconSet[id], key: const ValueKey('open'), size: 28, color: palette[id].shade900)
                        : const Icon(Icons.help_outline_rounded, key: ValueKey('closed'), color: Colors.black54),
                  ),
                ),
              ),
            ),
          );

          // Even if removed, we keep the grid cell (it animates invisible and ignores input).
          return tile;
        },
      ),
    );
  }
}

/* ─────────── Win confetti overlay ─────────── */

class _WinConfettiOverlay extends StatefulWidget {
  final TickerProvider vsync;
  const _WinConfettiOverlay({required this.vsync});

  @override
  State<_WinConfettiOverlay> createState() => _WinConfettiOverlayState();
}

class _WinConfettiOverlayState extends State<_WinConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  final _particles = <_Particle>[];
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: widget.vsync,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _spawn();
    _ctrl.forward();
  }

  void _spawn() {
    for (int i = 0; i < 60; i++) {
      _particles.add(
        _Particle(
          dx: (_rnd.nextDouble() * 2 - 1) * 180,
          dy: (_rnd.nextDouble() * 2 - 1) * 180,
          size: 6 + _rnd.nextDouble() * 10,
          rotation: _rnd.nextDouble() * pi,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final double t = _anim.value;
          final double clamped = (t.clamp(0.0, 1.0) as double);
          final double opacity = 1.0 - clamped;

          return Positioned.fill(
            child: Opacity(
              opacity: opacity,
              child: Stack(
                children: [
                  Container(color: const Color(0xFFFFFFFF).withOpacity(0.2 * opacity)),
                  ..._particles.map((p) {
                    final dx = p.dx * t;
                    final dy = p.dy * t;
                    final scale = 0.6 + 0.6 * (1 - (t - 0.3).abs());
                    return Align(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset(dx, dy),
                        child: Transform.rotate(
                          angle: p.rotation * (1 + t),
                          child: Transform.scale(
                            scale: scale,
                            child: Container(
                              width: p.size,
                              height: p.size,
                              decoration: BoxDecoration(
                                color: _randColor(p.hashCode),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  Align(
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * (1 - (t - 0.2).abs()),
                      child: const Icon(Icons.emoji_events_rounded, size: 96, color: Color(0xFF0D7C66)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _randColor(int seed) {
    final r = (seed * 97) % 255;
    final g = (seed * 57) % 255;
    final b = (seed * 127) % 255;
    return Color.fromARGB(255, r, g, b);
  }
}

class _Particle {
  final double dx, dy, size, rotation;
  _Particle({required this.dx, required this.dy, required this.size, required this.rotation});
}
