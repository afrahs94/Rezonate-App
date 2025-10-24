// lib/pages/sudoku.dart
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
  final String title, rule;
  final Widget child;
  final Widget? topBar, bottom;
  const _GameScaffold({required this.title, required this.rule, required this.child, this.topBar, this.bottom});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
                if (bottom != null) ...[const SizedBox(height: 10), bottom!],
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
    final p = await SharedPreferences.getInstance();
    final k = 'sbp_$gameKey';
    final cur = p.getStringList(k) ?? [];
    cur.add(v.toString());
    await p.setStringList(k, cur);
  }
  Future<bool> reportBest(String gameKey, double score) async {
    final p = await SharedPreferences.getInstance();
    final bestKey = 'sbp_best_$gameKey';
    final prev = p.getDouble(bestKey) ?? double.negativeInfinity;
    if (score > prev) { await p.setDouble(bestKey, score); return true; }
    return false;
  }
}

class SudokuPage extends StatefulWidget {
  const SudokuPage({super.key});
  @override
  State<SudokuPage> createState() => _SudokuPageState();
}

class _SudokuPageState extends State<SudokuPage> {
  // One easy, one medium, one hard (0 denotes empty)
  static const puzzles = [
    // Easy
    [
      [5,3,0, 0,7,0, 0,0,0],
      [6,0,0, 1,9,5, 0,0,0],
      [0,9,8, 0,0,0, 0,6,0],
      [8,0,0, 0,6,0, 0,0,3],
      [4,0,0, 8,0,3, 0,0,1],
      [7,0,0, 0,2,0, 0,0,6],
      [0,6,0, 0,0,0, 2,8,0],
      [0,0,0, 4,1,9, 0,0,5],
      [0,0,0, 0,8,0, 0,7,9],
    ],
    // Medium
    [
      [0,0,0, 2,6,0, 7,0,1],
      [6,8,0, 0,7,0, 0,9,0],
      [1,9,0, 0,0,4, 5,0,0],
      [8,2,0, 1,0,0, 0,4,0],
      [0,0,4, 6,0,2, 9,0,0],
      [0,5,0, 0,0,3, 0,2,8],
      [0,0,9, 3,0,0, 0,7,4],
      [0,4,0, 0,5,0, 0,3,6],
      [7,0,3, 0,1,8, 0,0,0],
    ],
    // Hard (still solvable logically)
    [
      [0,0,0, 0,0,0, 0,1,2],
      [0,0,0, 0,0,0, 0,0,0],
      [0,0,1, 0,9,0, 0,0,0],
      [0,0,0, 0,0,0, 3,0,0],
      [0,0,0, 0,0,0, 0,0,0],
      [0,0,2, 0,0,0, 0,0,0],
      [0,0,0, 6,0,0, 0,0,0],
      [0,0,0, 0,0,0, 0,0,0],
      [4,0,0, 0,0,0, 0,0,0],
    ],
  ];

  late List<List<int>> givens;  // immutable cells (non-zero)
  late List<List<int>> board;   // current state
  late DateTime _start;
  int difficulty = 0; // 0=easy,1=med,2=hard
  int? selR, selC;

  @override
  void initState() { super.initState(); _newGame(); }

  void _newGame() {
    final src = puzzles[difficulty];
    givens = List.generate(9, (r) => List.generate(9, (c) => src[r][c]));
    board  = List.generate(9, (r) => List.generate(9, (c) => src[r][c]));
    _start = DateTime.now();
    setState(() {});
  }

  void _reset() {
    for (int r=0;r<9;r++) {
      for (int c=0;c<9;c++) {
        if (givens[r][c] == 0) board[r][c] = 0;
      }
    }
    _start = DateTime.now();
    setState(() {});
  }

  bool _valid(int r, int c, int v) {
    for (int i=0;i<9;i++) {
      if (i!=c && board[r][i]==v) return false;
      if (i!=r && board[i][c]==v) return false;
    }
    final br = (r~/3)*3, bc=(c~/3)*3;
    for (int rr=br; rr<br+3; rr++) {
      for (int cc=bc; cc<bc+3; cc++) {
        if ((rr!=r || cc!=c) && board[rr][cc]==v) return false;
      }
    }
    return true;
  }

  bool _isComplete() {
    for (int r=0;r<9;r++) {
      for (int c=0;c<9;c++) {
        final v = board[r][c];
        if (v==0 || !_valid(r,c,v)) return false;
      }
    }
    return true;
  }

  void _place(int v) async {
    if (selR==null || selC==null) return;
    if (givens[selR!][selC!] != 0) return;
    setState(() { board[selR!][selC!] = v; });
    if (_isComplete()) {
      final secs = DateTime.now().difference(_start).inSeconds.clamp(1, 99999);
      final score = 1.0 / secs;
      await ScoreStore.instance.add('sudoku', score);
      final high = await ScoreStore.instance.reportBest('sudoku', score);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(high ? 'New High Score!' : 'Sudoku Complete'),
          content: Text('Time: ${secs}s'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
      _newGame();
    }
  }

  void _hint() {
    // Simple hint: fill one random empty valid cell using brute force single-candidate.
    final empties = <Point<int>>[];
    for (int r=0;r<9;r++) for (int c=0;c<9;c++) if (board[r][c]==0) empties.add(Point(r,c));
    if (empties.isEmpty) return;
    empties.shuffle();
    for (final p in empties) {
      final candidates = <int>[];
      for (int v=1; v<=9; v++) {
        board[p.x][p.y] = v;
        if (_valid(p.x, p.y, v)) candidates.add(v);
        board[p.x][p.y] = 0;
      }
      if (candidates.length == 1) {
        setState(() { board[p.x][p.y] = candidates.first; });
        return;
      }
    }
    // If no single-candidate found, just place a valid random candidate to keep things chill.
    final p = empties.first;
    final cands = <int>[];
    for (int v=1; v<=9; v++) { board[p.x][p.y]=v; if (_valid(p.x,p.y,v)) cands.add(v); }
    board[p.x][p.y] = 0;
    if (cands.isNotEmpty) setState(() { board[p.x][p.y] = cands.first; });
  }

  @override
  Widget build(BuildContext context) {
    final topBar = Row(
      children: [
        const Text('Difficulty:', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: difficulty,
          items: const [
            DropdownMenuItem(value: 0, child: Text('Easy')),
            DropdownMenuItem(value: 1, child: Text('Medium')),
            DropdownMenuItem(value: 2, child: Text('Hard')),
          ],
          onChanged: (v) { if (v==null) return; setState(() => difficulty=v); _newGame(); },
        ),
        const Spacer(),
        OutlinedButton.icon(onPressed: _hint, icon: const Icon(Icons.lightbulb_outline, size: 18), label: const Text('Hint')),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Reset')),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: _newGame, icon: const Icon(Icons.fiber_new_rounded, size: 18), label: const Text('New')),
      ],
    );

    final keypad = Wrap(
      spacing: 8, runSpacing: 8,
      children: List.generate(9, (i) => i+1).map((v) {
        return SizedBox(
          width: 40, height: 40,
          child: ElevatedButton(
            onPressed: () => _place(v),
            child: Text('$v', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        );
      }).toList(),
    );

    return _GameScaffold(
      title: 'Sudoku',
      rule: 'Fill 1..9 so each row, column, and 3×3 box has all digits exactly once.',
      topBar: topBar,
      bottom: Center(child: keypad),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: 81,
          itemBuilder: (_, i) {
            final r = i ~/ 9, c = i % 9;
            final given = givens[r][c] != 0;
            final selected = (selR==r && selC==c);
            final v = board[r][c];
            return GestureDetector(
              onTap: () => setState(() { selR=r; selC=c; }),
              child: Container(
                decoration: BoxDecoration(
                  color: given
                      ? const Color(0xFFA7E0C9)
                      : (selected ? const Color(0xFFFFF1A6) : Colors.white),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _ink),
                ),
                child: Center(
                  child: Text(v==0 ? '' : '$v',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: given ? Colors.black : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
