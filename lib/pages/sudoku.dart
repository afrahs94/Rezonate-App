// lib/pages/sudoku.dart
import 'dart:async';
import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;
import 'package:sudoku_solver_generator/sudoku_solver_generator.dart';

/// ───────────────────────── Palette ─────────────────────────
const _lilacDark = Color(0xFF5B4A85);     // main ink
const _lilacMid = Color(0xFFD7C3F1);      // matches bg
const _lilacLight = Color(0xFFF2ECFA);    // tiles
const _boardGiven = Color(0xFFE4F4EA);    // for given cells
const _errorBg = Color(0xFFFFD6D6);

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

class _GameScaffold extends StatelessWidget {
  final String title, rule;
  final Widget child;
  const _GameScaffold({
    required this.title,
    required this.rule,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _lilacDark),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, color: _lilacDark),
        ),
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.97),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _lilacDark.withOpacity(.25)),
                  ),
                  child: Text(
                    rule,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _lilacDark),
                  ),
                ),
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

/// ───────────────────────── Score store ─────────────────────────
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
    if (score > prev) {
      await p.setDouble(bestKey, score);
      return true;
    }
    return false;
  }
}

class _Move {
  final int r, c;
  final int previous;
  final int current;
  _Move(this.r, this.c, this.previous, this.current);
}

/// ───────────────────────── Sudoku Page ─────────────────────────
class SudokuPage extends StatefulWidget {
  const SudokuPage({super.key});

  @override
  State<SudokuPage> createState() => _SudokuPageState();
}

class _SudokuPageState extends State<SudokuPage> {
  late List<List<int>> givens;
  late List<List<int>> board;
  late List<List<int>> solution;

  int difficulty = 0; // 0=easy,1=medium,2=hard
  int? selR, selC;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _paused = false;

  final List<_Move> _history = [];

  // error flash
  Point<int>? _errorCell;
  Timer? _errorTimer;

  // mistakes
  int _mistakes = 0;
  static const int _maxMistakes = 10;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _errorTimer?.cancel();
    super.dispose();
  }

  /// Avoid UnlikelyUniqueSolutionException by retrying
  Map<String, List<List<int>>> _generateSafePuzzle(int blanks) {
    int attemptBlanks = blanks;
    for (int i = 0; i < 5; i++) {
      try {
        final gen = SudokuGenerator(emptySquares: attemptBlanks);
        return {
          'puzzle': gen.newSudoku,
          'solution': gen.newSudokuSolved,
        };
      } catch (_) {
        attemptBlanks = (attemptBlanks - 2).clamp(20, 60);
      }
    }
    final gen = SudokuGenerator(emptySquares: 30);
    return {
      'puzzle': gen.newSudoku,
      'solution': gen.newSudokuSolved,
    };
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused) {
        setState(() {
          _elapsed += const Duration(seconds: 1);
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _newGame() {
    int blanks;
    if (difficulty == 0) {
      blanks = 36; // easy
    } else if (difficulty == 1) {
      blanks = 42; // medium
    } else {
      blanks = 48; // hard
    }

    final data = _generateSafePuzzle(blanks);
    final puzzle = data['puzzle']!;
    final solved = data['solution']!;

    givens = List.generate(9, (r) => List<int>.from(puzzle[r]));
    board = List.generate(9, (r) => List<int>.from(puzzle[r]));
    solution = List.generate(9, (r) => List<int>.from(solved[r]));

    _elapsed = Duration.zero;
    _paused = false;
    _mistakes = 0;
    _history.clear();
    _errorCell = null;
    selR = null;
    selC = null;

    _startTimer();
    setState(() {});
  }

  void _resetBoard() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (givens[r][c] == 0) {
          board[r][c] = 0;
        }
      }
    }
    _elapsed = Duration.zero;
    _paused = false;
    _mistakes = 0;
    _errorCell = null;
    _history.clear();
    _startTimer();
    setState(() {});
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
    });
  }

  bool _isValidPlacement(int row, int col, int value) {
    for (int c = 0; c < 9; c++) {
      if (c != col && board[row][c] == value) return false;
    }
    for (int r = 0; r < 9; r++) {
      if (r != row && board[r][col] == value) return false;
    }
    final br = (row ~/ 3) * 3;
    final bc = (col ~/ 3) * 3;
    for (int r = br; r < br + 3; r++) {
      for (int c = bc; c < bc + 3; c++) {
        if (!(r == row && c == col) && board[r][c] == value) return false;
      }
    }
    return true;
  }

  // pretty win dialog (with emoji)
  Future<void> _showWinDialog({required bool isHighScore}) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: _lilacDark.withOpacity(.15),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _lilacMid.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🌱', style: TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isHighScore ? '🌱 New High Score!' : 'Sudoku Complete',
                  style: const TextStyle(
                    color: _lilacDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Time: ${_formatDuration(_elapsed)}',
                  style: const TextStyle(
                    color: _lilacDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: _lilacDark,
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _newGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _lilacDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                        ),
                        child: const Text(
                          'New Game',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // same style as win, but no emoji
  Future<void> _showGameOverDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: _lilacDark.withOpacity(.15),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                const Text(
                  'Game Over',
                  style: TextStyle(
                    color: _lilacDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You’ve reached 10 mistakes. Try a new puzzle!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _lilacDark,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: _lilacDark,
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _newGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _lilacDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                        ),
                        child: const Text(
                          'New Game',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _place(int v) async {
    if (selR == null || selC == null) return;
    final r = selR!, c = selC!;
    if (givens[r][c] != 0) return;

    final breaksRule = !_isValidPlacement(r, c, v);
    final notSolution = v != solution[r][c];
    if (breaksRule || notSolution) {
      _mistakes++;
      _flashError(r, c);
      if (_mistakes >= _maxMistakes) {
        _timer?.cancel();
        await _showGameOverDialog();
      } else {
        setState(() {});
      }
      return;
    }

    final prev = board[r][c];
    board[r][c] = v;
    _history.add(_Move(r, c, prev, v));

    if (_isComplete()) {
      _timer?.cancel();
      final secs = _elapsed.inSeconds.clamp(1, 99999);
      final score = 1.0 / secs;
      await ScoreStore.instance.add('sudoku', score);
      final high = await ScoreStore.instance.reportBest('sudoku', score);
      if (!mounted) return;
      await _showWinDialog(isHighScore: high);
      _newGame();
    } else {
      setState(() {});
    }
  }

  void _flashError(int r, int c) {
    _errorTimer?.cancel();
    setState(() {
      _errorCell = Point(r, c);
    });
    _errorTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _errorCell = null;
        });
      }
    });
  }

  bool _isComplete() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == 0) return false;
        if (board[r][c] != solution[r][c]) return false;
      }
    }
    return true;
  }

  void _hint() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == 0) {
          final prev = board[r][c];
          setState(() {
            board[r][c] = solution[r][c];
            selR = r;
            selC = c;
            _history.add(_Move(r, c, prev, board[r][c]));
          });
          return;
        }
      }
    }
  }

  void _erase() {
    if (selR == null || selC == null) return;
    final r = selR!, c = selC!;
    if (givens[r][c] != 0) return;
    final prev = board[r][c];
    if (prev == 0) return;
    setState(() {
      board[r][c] = 0;
      _history.add(_Move(r, c, prev, 0));
    });
  }

  @override
  Widget build(BuildContext context) {
    return _GameScaffold(
      title: 'Sudoku',
      rule: 'Fill 1–9 so each row, column, and 3×3 box has all digits exactly once.',
      child: Column(
        children: [
          // top controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Difficulty:',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _lilacDark),
                  ),
                  const SizedBox(width: 6),
                  DropdownButton<int>(
                    value: difficulty,
                    dropdownColor: Colors.white,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Easy')),
                      DropdownMenuItem(value: 1, child: Text('Medium')),
                      DropdownMenuItem(value: 2, child: Text('Hard')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => difficulty = v);
                      _newGame();
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    _formatDuration(_elapsed),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _lilacDark),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: _togglePause,
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                    color: _lilacDark,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: _lilacDark, size: 18),
              const SizedBox(width: 4),
              Text(
                'Mistakes: $_mistakes / $_maxMistakes',
                style: const TextStyle(color: _lilacDark, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // board
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _lilacDark.withOpacity(.35), width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 9,
                    ),
                    itemCount: 81,
                    itemBuilder: (_, i) {
                      final r = i ~/ 9;
                      final c = i % 9;
                      final given = givens[r][c] != 0;
                      final selected = selR == r && selC == c;
                      final sameRow = selR != null && selR == r;
                      final sameCol = selC != null && selC == c;

                      Color bg = Colors.white;
                      if (_errorCell != null && _errorCell!.x == r && _errorCell!.y == c) {
                        bg = _errorBg;
                      } else if (given) {
                        bg = _boardGiven;
                      } else if (selected) {
                        bg = _lilacLight;
                      } else if (sameRow || sameCol) {
                        bg = _lilacLight.withOpacity(.45);
                      }

                      final v = board[r][c];
                      final thickRight = (c % 3 == 2) ? 2.0 : 0.3;
                      final thickBottom = (r % 3 == 2) ? 2.0 : 0.3;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selR = r;
                            selC = c;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: bg,
                            border: Border(
                              right: BorderSide(color: _lilacDark.withOpacity(.35), width: thickRight),
                              bottom: BorderSide(color: _lilacDark.withOpacity(.35), width: thickBottom),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              v == 0 ? '' : '$v',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 20,
                                color: given ? _lilacDark.withOpacity(.9) : _lilacDark,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // bottom controls (no New Game here)
          Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _roundBtn(icon: Icons.backspace_outlined, onTap: _erase),
                    const SizedBox(width: 8),
                    _roundBtn(icon: Icons.lightbulb_outline, onTap: _hint),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _lilacDark),
                          foregroundColor: _lilacDark,
                          backgroundColor: Colors.white.withOpacity(.4),
                        ),
                        onPressed: _resetBoard,
                        child: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(9, (i) {
                    final v = i + 1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: _lilacLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _place(v),
                          child: Text(
                            '$v',
                            style: const TextStyle(
                              fontSize: 20,
                              color: _lilacDark,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _lilacDark.withOpacity(.12)),
          boxShadow: [
            BoxShadow(
              color: _lilacDark.withOpacity(.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: _lilacDark),
      ),
    );
  }
}

