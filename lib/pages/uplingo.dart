// lib/pages/uplingo.dart
// Uplingo – authentic Wordle-style game with auto-submit after fifth letter.
// Adds per-key coloring (green/yellow/gray) and light animations.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:new_rezonate/main.dart' as app;

class UplingoPage extends StatefulWidget {
  const UplingoPage({super.key});

  @override
  State<UplingoPage> createState() => _UplingoPageState();
}

enum _LetterState { unknown, absent, present, correct }

class _UplingoPageState extends State<UplingoPage>
    with SingleTickerProviderStateMixin {
  static const int wordLength = 5;
  static const int maxAttempts = 6;

  // Colors (match app vibe)
  static const Color _cGreen = Color(0xFF6FD6C1);
  static const Color _cYellow = Color(0xFFFDDC77);
  static final Color _cGray = Colors.grey.shade300;

  final List<String> _wordBank = [
    'PEACE', 'LIGHT', 'FOCUS', 'UNITY', 'TRUST', 'GRACE', 'DREAM', 'HOPE',
    'HEART', 'KIND', 'CLEAR', 'LUCKY', 'FAITH', 'WORTH', 'ALIGN', 'SOLAR',
    'OASIS', 'BRAVE', 'MUSIC', 'HAPPY', 'QUIET', 'BLOOM', 'GREEN', 'SMILE',
    'NOBLE', 'HONOR', 'PLANT', 'STYLE', 'HONEY', 'BRAIN'
  ];

  late String _target;
  List<String> _guesses = [];
  List<List<Color>> _colorResults = [];
  String _current = '';
  bool _won = false;
  bool _lost = false;

  // Keyboard state: best-known status for each A–Z key
  final Map<String, _LetterState> _kbState = {
    for (var c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) c: _LetterState.unknown
  };

  // Tiny press-bounce on keys
  String? _pressedKey;
  late final AnimationController _bounceCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 140));

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    final rand = Random();
    setState(() {
      _target = _wordBank[rand.nextInt(_wordBank.length)];
      _guesses.clear();
      _colorResults.clear();
      _current = '';
      _won = false;
      _lost = false;
      _pressedKey = null;
      for (final k in _kbState.keys) {
        _kbState[k] = _LetterState.unknown;
      }
    });
  }

  void _onKey(String ch) {
    if (_won || _lost) return;

    setState(() => _pressedKey = ch);
    _bounceCtrl.forward(from: 0);

    setState(() {
      if (ch == '⌫') {
        if (_current.isNotEmpty) {
          _current = _current.substring(0, _current.length - 1);
        }
      } else if (RegExp(r'^[A-Za-z]$').hasMatch(ch)) {
        if (_current.length < wordLength) {
          _current += ch.toUpperCase();
          if (_current.length == wordLength) {
            _submitGuess(); // auto-submit after 5th letter
          }
        }
      }
    });
  }

  void _promoteKey(String letter, _LetterState newState) {
    final cur = _kbState[letter] ?? _LetterState.unknown;
    // Priority: correct > present > absent > unknown
    bool shouldSet = false;
    switch (newState) {
      case _LetterState.correct:
        shouldSet = cur != _LetterState.correct;
        break;
      case _LetterState.present:
        shouldSet = cur == _LetterState.unknown || cur == _LetterState.absent;
        break;
      case _LetterState.absent:
        shouldSet = cur == _LetterState.unknown;
        break;
      case _LetterState.unknown:
        break;
    }
    if (shouldSet) _kbState[letter] = newState;
  }

  void _submitGuess() {
    if (_current.length != wordLength) return;

    final guess = _current;
    final targetChars = _target.split('');
    final guessChars = guess.split('');
    final resultColors = List<Color>.filled(wordLength, _cGray);
    final used = List<bool>.filled(wordLength, false);

    // First pass: mark greens
    for (int i = 0; i < wordLength; i++) {
      if (guessChars[i] == targetChars[i]) {
        resultColors[i] = _cGreen;
        used[i] = true;
      }
    }

    // Second pass: mark yellows where applicable
    for (int i = 0; i < wordLength; i++) {
      if (resultColors[i] == _cGray) {
        for (int j = 0; j < wordLength; j++) {
          if (!used[j] && guessChars[i] == targetChars[j]) {
            resultColors[i] = _cYellow;
            used[j] = true;
            break;
          }
        }
      }
    }

    // Update per-key states
    for (int i = 0; i < wordLength; i++) {
      final ch = guessChars[i];
      if (resultColors[i] == _cGreen) {
        _promoteKey(ch, _LetterState.correct);
      } else if (resultColors[i] == _cYellow) {
        _promoteKey(ch, _LetterState.present);
      } else {
        _promoteKey(ch, _LetterState.absent);
      }
    }

    _guesses.add(guess);
    _colorResults.add(resultColors);

    if (guess == _target) {
      _won = true;
    } else if (_guesses.length >= maxAttempts) {
      _lost = true;
    }

    _current = '';
  }

  Color _keyColor(String letter) {
    final st = _kbState[letter] ?? _LetterState.unknown;
    switch (st) {
      case _LetterState.correct:
        return _cGreen;
      case _LetterState.present:
        return _cYellow;
      case _LetterState.absent:
        return Colors.grey.shade400;
      case _LetterState.unknown:
      default:
        return const Color(0xFFBEE8DF);
    }
  }

  Widget _buildBoard() {
    final rows = <Widget>[];

    for (int i = 0; i < maxAttempts; i++) {
      List<Color> colors = i < _colorResults.length
          ? _colorResults[i]
          : List<Color>.filled(wordLength, Colors.white.withOpacity(0.9));

      String word = '';
      if (i < _guesses.length) {
        word = _guesses[i];
      } else if (i == _guesses.length) {
        word = _current;
      }

      final letters = word.padRight(wordLength).split('');

      rows.add(
        TweenAnimationBuilder<double>(
          // subtle slide-in for each row based on index
          key: ValueKey('row-$i-${_guesses.length}'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int j = 0; j < wordLength; j++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    width: 54,
                    height: 54,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors[j],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black26, width: 1.2),
                      boxShadow: [
                        if (colors[j] != Colors.white.withOpacity(0.9))
                          const BoxShadow(color: Colors.black12, blurRadius: 6)
                      ],
                    ),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 160),
                      scale: letters[j].trim().isEmpty ? 0.9 : 1.0,
                      child: Text(
                        letters[j],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildKeyboard() {
    const rows = [
      ['Q','W','E','R','T','Y','U','I','O','P'],
      ['A','S','D','F','G','H','J','K','L'],
      ['Z','X','C','V','B','N','M'],
      ['⌫']
    ];

    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8, bottom: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < rows.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 8),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: rows[i].map((letter) => _key(letter)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _key(String label) {
    final bool wide = label == '⌫';
    final isPressed = _pressedKey == label;

    final bg = label == '⌫' ? const Color(0xFFB6E3FF) : _keyColor(label);
    final fg = Colors.black;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: isPressed ? 0.92 : 1),
      duration: const Duration(milliseconds: 140),
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: SizedBox(
        width: wide ? 60 : 36,
        height: 46,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            elevation: 1.5,
            shadowColor: Colors.black26,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => _onKey(label),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: fg,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: _newGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB6E3FF),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh_rounded, color: Colors.black, size: 18),
            label: const Text('New Game',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14)),
          ),
          ElevatedButton.icon(
            onPressed: () => setState(() => _current = ''),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE9FFFE),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.restart_alt_rounded, color: Colors.black, size: 18),
            label: const Text('Reset Row',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    final gradient = LinearGradient(
      colors: dark
          ? const [Color(0xFF2A2336), Color(0xFF1B4F4A)]
          : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF6FD6C1)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Uplingo',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(gradient: gradient),
          child: SafeArea(
            top: true,
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildControlButtons(),
                const SizedBox(height: 8),
                _buildBoard(),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: (!_won && !_lost)
                      ? const SizedBox.shrink()
                      : Column(
                          key: ValueKey(_won ? 'won' : 'lost'),
                          children: [
                            Text(
                              _won
                                  ? '✨ You guessed it! The word was $_target.'
                                  : '💭 The word was $_target — try again!',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            ElevatedButton(
                              onPressed: _newGame,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB6E3FF),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8)),
                              child: const Text('Play Again',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                _buildKeyboard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
