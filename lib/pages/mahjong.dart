// lib/pages/mahjong.dart
//
// Mahjong Solitaire – Garden Theme
// - Single-player matching game (pair identical tiles).
// - Tiles must be "free" (no tile on top, at least one side open).
// - Garden icons (flowers, leaves, bugs, etc.) as tile faces.
// - Includes restart + win / no-moves dialog.
// - No external image assets needed.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:new_rezonate/main.dart' as app;

/* ─────────────────── Garden background ─────────────────── */

BoxDecoration _bg(BuildContext context) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [
              Color(0xFF0B1F16),
              Color(0xFF163829),
              Color(0xFF285D3B),
            ]
          : const [
              Color(0xFFE8F8EC),
              Color(0xFFC6EBD1),
              Color(0xFF9BD8B5),
            ],
    ),
  );
}

/* ─────────────────── Model ─────────────────── */

class _Pos {
  final int x, y, z;
  const _Pos(this.x, this.y, this.z);
}

class _MahjongTile {
  final int id;
  final String symbol;
  final int x;
  final int y;
  final int z;
  bool removed;
  _MahjongTile({
    required this.id,
    required this.symbol,
    required this.x,
    required this.y,
    required this.z,
    this.removed = false,
  });
}

/* ─────────────────── Page ─────────────────── */

class MahjongPage extends StatefulWidget {
  const MahjongPage({super.key});

  @override
  State<MahjongPage> createState() => _MahjongPageState();
}

class _MahjongPageState extends State<MahjongPage> {
  final _rnd = Random();

  final List<String> _gardenSymbols = const [
    '🌸', '🌷', '🌼', '🌻', '🌺', '🌹',
    '🍀', '🍃', '🍂', '🍁',
    '🪴', '🌱', '🌾', '🌿',
    '🦋', '🐞', '🐝', '🐛',
  ];

  late List<_MahjongTile> _tiles;
  _MahjongTile? _selected;
  bool _won = false;
  int _moves = 0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  /* ─────────────── Game setup ─────────────── */

  void _newGame() {
    final positions = _createLayout();
    final pairs = positions.length ~/ 2;

    // Build list of symbols (each appears exactly twice).
    final List<String> symbols = [];
    for (int i = 0; i < pairs; i++) {
      final sym = _gardenSymbols[i % _gardenSymbols.length];
      symbols.add(sym);
      symbols.add(sym);
    }
    symbols.shuffle(_rnd);

    _tiles = List.generate(
      positions.length,
      (i) => _MahjongTile(
        id: i,
        symbol: symbols[i],
        x: positions[i].x,
        y: positions[i].y,
        z: positions[i].z,
      ),
    );

    _selected = null;
    _moves = 0;
    _won = false;
    _startTime = DateTime.now();
    setState(() {});
  }

  // A simple layered layout ~72 tiles.
  List<_Pos> _createLayout() {
    final List<_Pos> pos = [];

    // Base layer (z=0): 12 x 4 rectangle
    for (int x = 0; x < 12; x++) {
      for (int y = 0; y < 4; y++) {
        pos.add(_Pos(x, y, 0));
      }
    }

    // Inner layer (z=1): 8 x 2 rectangle
    for (int x = 2; x < 10; x++) {
      for (int y = 1; y < 3; y++) {
        pos.add(_Pos(x, y, 1));
      }
    }

    // Two side tiles on z=1
    pos.add(const _Pos(0, 1, 1));
    pos.add(const _Pos(11, 1, 1));

    // Smaller layer (z=2)
    for (int x = 4; x < 8; x++) {
      pos.add(_Pos(x, 1, 2));
    }

    // Top 2 tiles (z=3)
    pos.add(const _Pos(5, 1, 3));
    pos.add(const _Pos(6, 1, 3));

    // 72 positions total (36 pairs)
    return pos;
  }

  /* ─────────────── Rules ─────────────── */

  bool _isCovered(_MahjongTile tile) {
    // Any tile with higher z that visually overlaps (within 1 step).
    return _tiles.any((t) {
      if (t.removed) return false;
      if (t.z <= tile.z) return false;
      final dx = (t.x - tile.x).abs();
      final dy = (t.y - tile.y).abs();
      return dx <= 1 && dy <= 1;
    });
  }

  bool _isFree(_MahjongTile tile) {
    if (tile.removed) return false;
    if (_isCovered(tile)) return false;

    // Check left / right neighbors on same layer + row.
    final leftBlocked = _tiles.any((t) =>
        !t.removed &&
        t.z == tile.z &&
        t.y == tile.y &&
        t.x == tile.x - 1);
    final rightBlocked = _tiles.any((t) =>
        !t.removed &&
        t.z == tile.z &&
        t.y == tile.y &&
        t.x == tile.x + 1);

    // Must have at least one free side.
    return !leftBlocked || !rightBlocked;
  }

  bool _hasMoves() {
    final freeTiles =
        _tiles.where((t) => !t.removed && _isFree(t)).toList();
    for (int i = 0; i < freeTiles.length; i++) {
      for (int j = i + 1; j < freeTiles.length; j++) {
        if (freeTiles[i].symbol == freeTiles[j].symbol) return true;
      }
    }
    return false;
  }

  void _onTileTap(_MahjongTile tile) {
    if (tile.removed) return;

    if (!_isFree(tile)) {
      _showSnack('That tile is blocked.');
      return;
    }

    setState(() {
      if (_selected?.id == tile.id) {
        // Deselect
        _selected = null;
        return;
      }

      if (_selected == null) {
        _selected = tile;
        return;
      }

      // Second tile chosen
      _moves++;
      if (_selected!.symbol == tile.symbol && _selected!.id != tile.id) {
        // Match!
        tile.removed = true;
        _selected!.removed = true;
        final matchedSymbol = tile.symbol;
        _selected = null;

        // Brief visual delay for user feedback.
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(() {});
        });

        // Win check
        if (_tiles.every((t) => t.removed)) {
          _won = true;
          _showWinDialog();
        } else if (!_hasMoves()) {
          _showNoMovesDialog();
        } else {
          _showSnack('Matched $matchedSymbol!');
        }
      } else {
        // Not a match – switch selection
        _selected = tile;
      }
    });
  }

  /* ─────────────── UI helpers ─────────────── */

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _showWinDialog() {
    final elapsed = _startTime == null
        ? Duration.zero
        : DateTime.now().difference(_startTime!);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Garden Cleared! 🌸',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Moves: $_moves'),
            const SizedBox(height: 4),
            Text(
              'Time: ${elapsed.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
              '${(elapsed.inSeconds.remainder(60)).toString().padLeft(2, '0')}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _newGame();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  void _showNoMovesDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'No More Moves 🌿',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'There are no more valid pairs. Try reshuffling the garden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _newGame();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  /* ─────────────── Build ─────────────── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Mahjong Garden',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New Game',
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            onPressed: _newGame,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: DecoratedBox(decoration: _bg(context))),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildStatsBar(),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: _buildBoard(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final elapsed = _startTime == null
        ? Duration.zero
        : DateTime.now().difference(_startTime!);
    final timeStr =
        '${elapsed.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${elapsed.inSeconds.remainder(60).toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.grass_rounded, color: Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          const Text(
            'Garden Mahjong',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  size: 18, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: const TextStyle(fontSize: 13.5),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              const Icon(Icons.touch_app_rounded,
                  size: 18, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                'Moves: $_moves',
                style: const TextStyle(fontSize: 13.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    final visibleTiles =
        _tiles.where((t) => !t.removed).toList()
          ..sort((a, b) {
            // Lower z first, then y, then x (so higher z draws on top).
            final z = a.z.compareTo(b.z);
            if (z != 0) return z;
            final y = a.y.compareTo(b.y);
            if (y != 0) return y;
            return a.x.compareTo(b.x);
          });

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final tileWidth = maxWidth / 14; // some margin left/right
        final tileHeight = tileWidth * 1.3;

        final List<Widget> children = [];

        for (final tile in visibleTiles) {
          final dx = (tile.x + 1) * tileWidth * 0.9;
          final dy =
              tile.y * tileHeight * 0.72 - tile.z * tileHeight * 0.2 + 8.0;

          final isSelected = _selected?.id == tile.id;
          final isFree = _isFree(tile);

          children.add(
            Positioned(
              left: dx,
              top: dy,
              child: _buildTileWidget(
                tile,
                tileWidth,
                tileHeight,
                isSelected: isSelected,
                isFree: isFree,
              ),
            ),
          );
        }

        return Stack(children: children);
      },
    );
  }

  Widget _buildTileWidget(
    _MahjongTile tile,
    double w,
    double h, {
    required bool isSelected,
    required bool isFree,
  }) {
    final Color face = isFree ? Colors.white : Colors.grey.shade300;
    final Color border =
        isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade500;
    final Color accent = isSelected
        ? const Color(0xFF66BB6A)
        : (isFree ? const Color(0xFF8BC34A) : Colors.grey.shade400);

    return GestureDetector(
      onTap: () => _onTileTap(tile),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: face,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1.4),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              face,
              face.withOpacity(0.9),
              Colors.white.withOpacity(0.9),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Slight top edge highlight (mahjong style)
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: h * 0.18,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.9),
                        face.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Colored corner pip
            Positioned(
              top: 5,
              left: 5,
              child: Container(
                width: w * 0.22,
                height: w * 0.22,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: accent.withOpacity(0.6), width: 1.0),
                ),
              ),
            ),
            // Symbol center
            Center(
              child: Text(
                tile.symbol,
                style: TextStyle(
                  fontSize: w * 0.7,
                  shadows: [
                    Shadow(
                        blurRadius: 4,
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(1, 2))
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
