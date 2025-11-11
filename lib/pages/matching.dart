// lib/pages/matching.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* ───────────────── Shared look & scaffold ───────────────── */

BoxDecoration _bg(BuildContext context) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xFF2A2336), Color(0xFF1B4F4A)]
          : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF6FD6C1)],
    ),
  );
}

const _ink = Colors.black;

/* Scaffold used by the game pages */
class _GameScaffold extends StatelessWidget {
  final String title;
  final String rule;
  final Widget child;
  final Widget? topBar;
  final List<Widget>? actions;

  const _GameScaffold({
    required this.title,
    required this.rule,
    required this.child,
    this.topBar,
    this.actions,
  });

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
        actions: actions,
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

/* ───────────────── Score store ───────────────── */

class ScoreStore {
  ScoreStore._();
  static final instance = ScoreStore._();

  String _bestKey(String game) => 'sb_best_$game';
  String _histKey(String game) => 'sb_hist_$game';

  Future<int> best(String game) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_bestKey(game)) ?? 0;
    }

  /// Update best if higher; returns true if a new best was set.
  Future<bool> updateBest(String game, int score) async {
    final p = await SharedPreferences.getInstance();
    final k = _bestKey(game);
    final prev = p.getInt(k) ?? 0;
    if (score > prev) {
      await p.setInt(k, score);
      return true;
    }
    return false;
  }

  Future<void> addHistory({
    required String game,
    required int score,
    required int count,
    required int seconds,
  }) async {
    final p = await SharedPreferences.getInstance();
    final key = _histKey(game);
    final list = (p.getStringList(key) ?? <String>[]);
    final now = DateTime.now().toIso8601String();
    list.insert(0, '$now|$score|$count|$seconds'); // ts|score|count|secs
    if (list.length > 50) list.removeRange(50, list.length);
    await p.setStringList(key, list);
  }

  Future<List<Map<String, dynamic>>> history(String game) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_histKey(game)) ?? <String>[];
    return list.map((row) {
      final parts = row.split('|');
      return {
        'ts': parts.elementAt(0),
        'score': int.tryParse(parts.elementAt(1)) ?? 0,
        'count': int.tryParse(parts.elementAt(2)) ?? 0,
        'seconds': int.tryParse(parts.elementAt(3)) ?? 0,
      };
    }).toList();
  }
}

/* ───────────────── Matching Game ───────────────── */

class MatchDifficultPage extends StatefulWidget {
  const MatchDifficultPage({super.key});
  @override
  State<MatchDifficultPage> createState() => _MatchDifficultPageState();
}

class _MatchDifficultPageState extends State<MatchDifficultPage>
    with TickerProviderStateMixin {
  static const int pairs = 10; // fixed
  static const String _gameKey = 'matching';

  final rnd = Random();
  late List<int> deck;
  late List<bool> faceUp;
  late List<bool> removed;
  late List<bool> _pressed;
  late List<bool> _burst;
  int? first;
  int moves = 0;
  int matched = 0;
  late DateTime _start;

  int _best = 0;

  late List<IconData> _iconSet;
  final List<String> _emojiSet = const [
    '🌊','✨','🍀','🦋','🧩','🎧','🌙','🌵','🍩','🦊',
  ];

  OverlayEntry? _winOverlay;

  @override
  void initState() {
    super.initState();
    _loadBest();
    _new();
  }

  Future<void> _loadBest() async {
    final b = await ScoreStore.instance.best(_gameKey);
    if (mounted) setState(() => _best = b);
  }

  void _new() {
    _iconSet = [
      Icons.rocket_launch_rounded,
      Icons.coffee_rounded,
      Icons.camera_alt_rounded,
      Icons.spa_rounded,
      Icons.palette_rounded,
      Icons.sports_esports_rounded,
      Icons.music_note_rounded,
      Icons.beach_access_rounded,
      Icons.bolt_rounded,
      Icons.face_retouching_natural_rounded,
    ]..shuffle(rnd);

    deck = List.generate(pairs, (i) => i)..addAll(List.generate(pairs, (i) => i));
    deck.shuffle(rnd);

    faceUp  = List.filled(deck.length, false);
    removed = List.filled(deck.length, false);
    _pressed = List.filled(deck.length, false);
    _burst   = List.filled(deck.length, false);

    first = null;
    moves = 0;
    matched = 0;
    _start = DateTime.now();
    setState(() {});
  }

  void _setPressed(int i, bool v) {
    if (!mounted || removed[i]) return;
    setState(() => _pressed[i] = v);
  }

  Future<void> _flip(int i) async {
    if (removed[i] || faceUp[i]) return;
    setState(() { faceUp[i] = true; });

    if (first == null) { first = i; return; }
    if (first == i) return;

    moves++;
    if (deck[first!] == deck[i]) {
      final a = first!;
      final b = i;
      first = null;

      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;

      setState(() { _burst[a] = true; _burst[b] = true; });
      await Future.delayed(const Duration(milliseconds: 240));
      if (!mounted) return;

      setState(() { removed[a] = true; removed[b] = true; });
      matched += 2;

      Future.delayed(const Duration(milliseconds: 380), () {
        if (!mounted) return;
        setState(() { _burst[a] = false; _burst[b] = false; });
      });

      if (matched == deck.length) {
        final secs = DateTime.now().difference(_start).inSeconds.clamp(1, 99999);
        // Integer score similar to Word Search scale
        final score = (1000 * pairs / secs).round();

        await ScoreStore.instance.addHistory(
          game: _gameKey,
          score: score,
          count: pairs,
          seconds: secs,
        );
        final isHigh = await ScoreStore.instance.updateBest(_gameKey, score);

        // ── Compatibility: also update legacy keys Stress Busters may read ──
        final prefs = await SharedPreferences.getInstance();
        final bestNow = await ScoreStore.instance.best(_gameKey);
        await prefs.setInt('sbp_best_matchhard', bestNow);
        await prefs.setInt('sbp_best_matching', bestNow);
        await prefs.setInt('sb_best_matchhard', bestNow);

        await _loadBest();

        if (!mounted) return;
        _showWinAnimation();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isHigh ? 'New high score!' : 'Completed • Score $score')),
        );
        await Future.delayed(const Duration(milliseconds: 1400));
        _hideWinAnimation();
      }
    } else {
      final prev = first!;
      first = null;
      await Future.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      setState(() { faceUp[i] = false; faceUp[prev] = false; });
    }
  }

  Future<void> _showHistory() async {
    final hist = await ScoreStore.instance.history(_gameKey);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _ink),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4, width: 44, margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const Text('Matching – Score History',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _ink),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        color: Color(0xFF0D7C66), size: 18),
                    const SizedBox(width: 8),
                    Text('Best Score: $_best',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ],
                ),
              ),
              if (hist.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('No scores yet. Finish a game to record one!'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: hist.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = hist[i];
                      final when = DateTime.tryParse(e['ts'] as String? ?? '') ?? DateTime.now();
                      final stamp =
                          '${when.month}/${when.day}/${when.year} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.emoji_events_rounded,
                            color: Color(0xFF0D7C66)),
                        title: Text('Score ${e['score']}'),
                        subtitle: Text('${e['count']}\n$stamp'),
                        isThreeLine: true,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWinAnimation() {
    if (_winOverlay != null) return;
    final entry = OverlayEntry(builder: (ctx) => _WinConfettiOverlay(vsync: this));
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
      rule: 'Flip cards to find pairs. Try to win in as little moves as possible.',
      actions: [
        IconButton(
          tooltip: 'Score history',
          icon: const Icon(Icons.bar_chart_rounded, color: _ink),
          onPressed: _showHistory,
        ),
      ],
      topBar: Row(
        children: [
          Text('Moves: $moves', style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _new,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Restart'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
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

          final targetScale = gone ? 0.85 : (_pressed[i] ? 0.94 : (open ? 1.03 : 1.0));
          final targetTurns = _pressed[i] ? -0.005 : (open ? 0.002 : 0.0);

          final cardFace = AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(anim), child: child),
            ),
            child: open
                ? Center(key: const ValueKey('open'), child: _faceFor(id, palette[id].shade900))
                : const Icon(Icons.help_outline_rounded,
                    key: ValueKey('closed'), color: Colors.black54),
          );

          final card = AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              gradient: open
                  ? LinearGradient(colors: [palette[id].shade200, palette[id].shade400])
                  : const LinearGradient(colors: [Colors.white, Color(0xFFF6F6F6)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _ink),
              boxShadow: [
                const BoxShadow(color: Colors.black12, blurRadius: 6),
                if (open) BoxShadow(color: palette[id].shade200.withOpacity(.6), blurRadius: 16, spreadRadius: 1),
              ],
            ),
            child: cardFace,
          );

          final interactive = GestureDetector(
            onTapDown: (_) => _setPressed(i, true),
            onTapUp:   (_) => _setPressed(i, false),
            onTapCancel: () => _setPressed(i, false),
            onTap: gone ? null : () => _flip(i),
            child: AnimatedScale(
              scale: targetScale,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              child: AnimatedRotation(
                turns: targetTurns,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: card,
              ),
            ),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: gone ? 0.0 : 1.0,
                child: interactive,
              ),
              Positioned.fill(child: _SparkleBurst(show: _burst[i], color: palette[id])),
            ],
          );
        },
      ),
    );
  }

  Widget _faceFor(int id, Color color) {
    if (id % 2 == 0) {
      return Text(_emojiSet[id], style: const TextStyle(fontSize: 30));
    } else {
      return Icon(_iconSet[id], size: 30, color: color);
    }
  }
}

/* ───────────────── Sparkles ───────────────── */

class _SparkleBurst extends StatelessWidget {
  final bool show;
  final MaterialColor color;
  const _SparkleBurst({required this.show, required this.color});

  @override
  Widget build(BuildContext context) {
    final dots = List.generate(6, (i) {
      final angle = (i / 6) * 2 * pi;
      final offset = Offset(cos(angle), sin(angle));
      return _RadialDot(offset: offset, color: color);
    });

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        opacity: show ? 1 : 0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 260),
          scale: show ? 1 : .6,
          child: Stack(children: dots),
        ),
      ),
    );
  }
}

class _RadialDot extends StatelessWidget {
  final Offset offset;
  final MaterialColor color;
  const _RadialDot({required this.offset, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(0, 0),
      child: Transform.translate(
        offset: Offset(offset.dx * 22, offset.dy * 22),
        child: Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            color: color.shade400,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [BoxShadow(color: color.shade200, blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

/* ───────────────── Win confetti ───────────────── */

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
    _ctrl = AnimationController(vsync: widget.vsync, duration: const Duration(milliseconds: 1200));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    for (int i = 0; i < 60; i++) {
      _particles.add(_Particle(
        dx: (_rnd.nextDouble() * 2 - 1) * 180,
        dy: (_rnd.nextDouble() * 2 - 1) * 180,
        size: 6 + _rnd.nextDouble() * 10,
        rotation: _rnd.nextDouble() * pi,
      ));
    }
    _ctrl.forward();
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
          final t = _anim.value;
          final opacity = 1.0 - t;
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
                  const Align(
                    alignment: Alignment.center,
                    child: Icon(Icons.emoji_events_rounded, size: 96, color: Color(0xFF0D7C66)),
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
