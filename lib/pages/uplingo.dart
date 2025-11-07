// lib/pages/uplingo.dart
// Uplingo – calm, Wordle-like guessing game for Stress Busters.

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

  final List<String> _wordBank = [
    'PEACE', 'CALM', 'BREATHE', 'MINDFUL', 'SMILE', 'LIGHT', 'FOCUS',
    'UNITY', 'TRUST', 'GRACE', 'HEART', 'DREAM', 'BLISS', 'HOPE'
  ];

  late String _target;
  List<String> _guesses = [];
  String _current = '';
  bool _won = false;
  bool _lost = false;

  @override
  void initState() {
    super.initState();
    _target = _wordBank[Random().nextInt(_wordBank.length)]
        .toUpperCase()
        .padRight(wordLength)
        .substring(0, wordLength);
  }

  void _onKey(String ch) {
    if (_won || _lost) return;
    setState(() {
      if (ch == '⌫') {
        if (_current.isNotEmpty) {
          _current = _current.substring(0, _current.length - 1);
        }
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

  Color _tileColor(String guess, int index) {
    final letter = guess[index];
    if (_target[index] == letter) {
      return const Color(0xFF6FD6C1); // correct place
    } else if (_target.contains(letter)) {
      return const Color(0xFFBDA9DB); // wrong place
    } else {
      return Colors.grey.shade300; // not in word
    }
  }

  Widget _buildBoard() {
    final rows = <Widget>[];
    for (int i = 0; i < maxAttempts; i++) {
      String word = i < _guesses.length
          ? _guesses[i]
          : (i == _guesses.length ? _current : '');
      final letters = word.padRight(wordLength).split('');
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int j = 0; j < wordLength; j++)
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.all(4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i < _guesses.length
                    ? _tileColor(word, j)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black54),
              ),
              child: Text(
                letters[j],
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ),
        ],
      ));
    }
    return Column(children: rows);
  }

  Widget _buildKeyboard() {
    const keys = [
      ['Q','W','E','R','T','Y','U','I','O','P'],
      ['A','S','D','F','G','H','J','K','L'],
      ['Z','X','C','V','B','N','M']
    ];
    return Column(
      children: [
        for (final row in keys)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final k in row)
                _key(k),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _key('⌫', flex: 2),
            _key('↵', flex: 2),
          ],
        ),
      ],
    );
  }

  Widget _key(String label, {int flex = 1}) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 32.0 * flex,
        height: 44,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFBEE8DF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => _onKey(label),
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _reset() {
    setState(() {
      _target = _wordBank[Random().nextInt(_wordBank.length)]
          .toUpperCase()
          .padRight(wordLength)
          .substring(0, wordLength);
      _guesses.clear();
      _current = '';
      _won = false;
      _lost = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Uplingo',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _reset,
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? const [Color(0xFF2A2336), Color(0xFF1B4F4A)]
                : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF6FD6C1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildBoard(),
              const SizedBox(height: 12),
              if (_won || _lost)
                Column(
                  children: [
                    Text(
                      _won
                          ? '✨ You found it! The word was $_target.'
                          : '💭 Try again! The word was $_target.',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    ElevatedButton(
                      onPressed: _reset,
                      child: const Text('Play Again'),
                    )
                  ],
                ),
              const Spacer(),
              _buildKeyboard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
