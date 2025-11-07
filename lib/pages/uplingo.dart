// lib/pages/uplingo.dart
// Uplingo – Wordle-style game with refined compact keyboard layout and balanced board spacing.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:new_rezonate/main.dart' as app;

class UplingoPage extends StatefulWidget {
  const UplingoPage({super.key});

  @override
  State<UplingoPage> createState() => _UplingoPageState();
}

class _UplingoPageState extends State<UplingoPage> {
  static const int wordLength = 5;
  static const int maxAttempts = 6;
  static const int maxHints = 3;

  final List<String> _wordBank = [
    'PEACE', 'CALM', 'BREATHE', 'SMILE', 'LIGHT', 'FOCUS', 'UNITY', 'TRUST', 'GRACE', 'DREAM',
    'HOPE', 'BLISS', 'ANGEL', 'HEART', 'NOBLE', 'HONOR', 'KIND', 'CLEAR', 'CLOUD', 'LUCKY',
    'FAITH', 'EAGER', 'SHINE', 'WORTH', 'ALIGN', 'ZENON', 'SOLAR', 'MIRTH', 'OASIS', 'CHARM',
    'BRAVE', 'FRESH', 'RIVER', 'MUSIC', 'PURE', 'HAPPY', 'QUIET', 'BLOOM', 'GREEN', 'RADIANT',
    'SWEET', 'EQUAL', 'YOUTH', 'GLOW', 'SEREN', 'MINTY', 'CALMS', 'ALIGN'
  ];

  late String _target;
  List<String> _guesses = [];
  String _current = '';
  bool _won = false;
  bool _lost = false;
  int _hintsUsed = 0;
  Set<int> _hintPositions = {};

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    final rand = Random();
    setState(() {
      _target = _wordBank[rand.nextInt(_wordBank.length)]
          .toUpperCase()
          .padRight(wordLength)
          .substring(0, wordLength);
      _guesses.clear();
      _current = '';
      _won = false;
      _lost = false;
      _hintsUsed = 0;
      _hintPositions.clear();
    });
  }

  void _onKey(String ch) {
    if (_won || _lost) return;
    setState(() {
      if (ch == '⌫') {
        if (_current.isNotEmpty) _current = _current.substring(0, _current.length - 1);
      } else if (ch == '↵') {
        if (_current.length == wordLength) {
          _guesses.add(_current);
          if (_current == _target) {
            _won = true;
          } else if (_guesses.length >= maxAttempts) {
            _lost = true;
          }
          _current = '';
        }
      } else if (_current.length < wordLength) {
        _current += ch;
      }
    });
  }

  void _useHint() {
    if (_hintsUsed >= maxHints || _won || _lost) return;
    setState(() {
      int idx;
      final rand = Random();
      do {
        idx = rand.nextInt(wordLength);
      } while (_hintPositions.contains(idx));
      _hintPositions.add(idx);
      _hintsUsed++;
    });
  }

  Color _tileColor(String guess, int index) {
    final letter = guess[index];
    if (_target[index] == letter) return const Color(0xFF6FD6C1);
    if (_target.contains(letter)) return const Color(0xFFBDA9DB);
    return Colors.grey.shade300;
  }

  Widget _buildBoard() {
    final rows = <Widget>[];
    for (int i = 0; i < maxAttempts; i++) {
      String word = i < _guesses.length ? _guesses[i] : (i == _guesses.length ? _current : '');
      final letters = word.padRight(wordLength).split('');
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int j = 0; j < wordLength; j++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 54,
                  height: 54,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < _guesses.length
                        ? _tileColor(word, j)
                        : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _hintPositions.contains(j)
                          ? Colors.orange
                          : Colors.black26,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    letters[j],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: _hintPositions.contains(j)
                          ? Colors.orange.shade700
                          : Colors.black,
                    ),
                  ),
                ),
            ],
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
      ['⌫','↵']
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
    final bool wide = label == '⌫' || label == '↵';
    return SizedBox(
      width: wide ? 60 : 36,
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFBEE8DF),
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
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
            onPressed: _useHint,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFE5BA),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.lightbulb_rounded, color: Colors.black87, size: 18),
            label: Text(
              'Hint (${maxHints - _hintsUsed})',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
            ),
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
      body: Container(
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
              if (_won || _lost)
                Column(
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                      child: const Text('Play Again',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              const SizedBox(height: 8),
              _buildKeyboard(),
            ],
          ),
        ),
      ),
    );
  }
}
