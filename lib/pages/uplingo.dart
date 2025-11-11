// lib/pages/uplingo.dart
//
// Uplingo (Wordle-style)
// - Keyboard keys reflect board colors (green/yellow/gray).
// - Real-word validation against a large dictionary.
//   -> Loads an external 5-letter word list if present at:
//        assets/words/words_5.txt
//      (one word per line, lowercase)
//      Falls back to a built-in mini list if the asset is missing.
//
// - Submit button (no auto-submit)
// - No black band at the bottom: the Scaffold sits on a full-screen gradient.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:characters/characters.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ← added
import 'package:new_rezonate/main.dart' as app;

/* ───────── Theme helpers ───────── */

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
const _green = Color(0xFF0D7C66);  // correct
const _yellow = Color(0xFFE9C46A); // present
const _grey = Color(0xFFCBD5E1);   // absent

/* ───────── Minimal score store (integer) ───────── */

class _UplingoScores {
  _UplingoScores._();
  static final _UplingoScores instance = _UplingoScores._();

  static const String _histKey = 'sbp_uplingo';   // history list
  static const String _bestKey1 = 'uplingo_best'; // checked by Scoreboard helper
  static const String _bestKey2 = 'sb_best_uplingo'; // extra alias

  Future<int> best() async {
    final p = await SharedPreferences.getInstance();
    final a = p.getInt(_bestKey1) ?? 0;
    final b = p.getInt(_bestKey2) ?? 0;
    return a > b ? a : b;
  }

  /// Save an integer score; returns true if it's a new high score.
  Future<bool> record(int score) async {
    final p = await SharedPreferences.getInstance();
    // history "score|epoch"
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final list = p.getStringList(_histKey) ?? <String>[];
    list.add('$score|$now');
    await p.setStringList(_histKey, list);

    // update best under both keys so Stress Busters can find it
    final prev = await best();
    if (score > prev) {
      await p.setInt(_bestKey1, score);
      await p.setInt(_bestKey2, score);
      return true;
    }
    return false;
  }

  Future<List<_ScoreRow>> history() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_histKey) ?? <String>[];
    return list.reversed.map((row) {
      final parts = row.split('|');
      final s = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
      final ts = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return _ScoreRow(score: s, at: DateTime.fromMillisecondsSinceEpoch(ts * 1000));
    }).toList();
  }
}

class _ScoreRow {
  final int score;
  final DateTime at;
  _ScoreRow({required this.score, required this.at});
}

/* ───────── Dictionary ───────── */

// Small built-in fallback (so the game still runs without the asset).
final Set<String> _builtinWords = {
  'about','above','actor','acute','adopt','adult','after','again','agent','agree','ahead','alarm',
  'album','alert','alike','allow','alone','along','alter','among','angle','angry','apple','apply',
  'april','argue','arise','array','aside','asset','audio','audit','avoid','awake','aware','badge',
  'basic','beach','begin','being','below','bench','birth','black','blade','blame','blank','blast',
  'blind','block','blood','board','boost','booth','bound','brain','brand','bread','break','breed',
  'brick','brief','bring','broad','broke','brown','brush','build','buyer','cabin','cable','carry',
  'catch','cause','chain','chair','chart','chase','cheap','check','cheek','chess','chief','child',
  'choir','chose','civil','claim','class','clean','clear','clerk','click','clock','close','coach',
  'coast','could','count','court','cover','craft','cream','crime','cross','crowd','crown','cycle',
  'daily','dance','dated','dealt','death','debut','delay','depth','dirty','doubt','dozen','draft',
  'drama','drawn','dream','dress','drill','drink','drive','drove','dying','eager','early','earth',
  'eight','elite','empty','enemy','enjoy','enter','entry','equal','error','event','every','exact',
  'exist','extra','faith','false','fault','favor','fewer','fiber','field','fifth','fifty','fight',
  'final','finds','first','fixed','flash','fleet','floor','fluid','focus','force','forth','forty',
  'forum','found','frame','fresh','front','fruit','fully','funny','giant','given','glass','globe',
  'going','grace','grade','grain','grand','grant','grass','great','green','greet','group','grown',
  'guard','guess','guest','guide','habit','happy','harsh','heart','heavy','hence','hobby','honor',
  'horse','hotel','house','human','humor','ideal','image','imply','index','inner','input','issue',
  'jeans','joint','judge','juice','kneel','knife','known','label','labor','large','laser','later',
  'laugh','layer','learn','least','leave','legal','lemon','level','light','limit','local','logic',
  'loose','lucky','lunch','magic','major','maker','march','match','maybe','mayor','meant','media',
  'metal','minor','mixed','model','money','month','moral','motor','mount','mouse','mouth','movie',
  'music','naive','nasty','nerve','never','newer','night','ninth','noble','noise','north','novel',
  'nurse','occur','ocean','offer','often','older','olive','onion','order','other','ought','paint',
  'panel','paper','party','pause','peace','pearl','phase','phone','photo','piece','pilot','pitch',
  'place','plain','plane','plant','plate','plead','point','polar','porch','pound','power','press',
  'price','pride','prime','print','prior','prize','proof','proud','prove','queen','quick','quiet',
  'quite','quota','quote','radio','raise','range','rapid','ratio','reach','react','ready','realm',
  'refer','right','rigid','rival','river','robot','rough','round','route','royal','rural','sadly',
  'safer','salad','scale','scene','scope','score','scout','seize','sense','serve','seven','shade',
  'shake','shall','shame','shape','share','sharp','sheep','sheet','shelf','shell','shift','shine',
  'shirt','shock','shoot','shore','short','shown','sight','since','skill','skirt','sleep','slide',
  'slope','small','smart','smile','smoke','solid','solve','sorry','sound','south','space','spare',
  'speak','speed','spend','spent','spice','spite','split','spoke','sport','staff','stage','stain',
  'stair','stake','stand','stare','start','state','steam','steel','steep','stick','still','stock',
  'stone','stood','store','storm','story','stove','strap','straw','strip','stuck','study','stuff',
  'style','sugar','suite','sunny','super','sweet','table','taken','taste','taxes','teach','teeth',
  'thank','their','theme','there','these','thick','thing','think','third','those','three','threw',
  'throw','tight','tired','title','today','tooth','topic','total','touch','tough','tower','trace',
  'track','trade','trail','train','treat','trend','trial','tribe','trick','truck','truly','trust',
  'truth','twice','uncle','under','union','unity','until','upper','upset','urban','usage','usual',
  'vague','valid','value','video','virus','visit','vital','vivid','voice','voter','waste','watch',
  'water','weary','weigh','weird','whale','wheat','wheel','where','which','while','white','whole',
  'whose','widow','width','woman','women','worst','worth','wound','write','wrong','young','youth',
};

// Runtime dictionary (starts with fallback; expanded with asset if available).
Set<String> _validWords = {..._builtinWords};

const List<String> _answers = [
  'apple','share','train','night','prize','teeth','water','music','green',
  'movie','about','quiet','laugh','radio','solid','sweet','value','vital',
];

List<String> get _answersSafe {
  final filtered =
      _answers.where((w) => w.length == 5 && _validWords.contains(w)).toList();
  return filtered.isEmpty ? const ['apple'] : filtered;
}

/* ───────── Scoring ───────── */

enum _Mark { unknown, absent, present, correct }

int _rank(_Mark m) {
  switch (m) {
    case _Mark.unknown:
      return 0;
    case _Mark.absent:
      return 1;
    case _Mark.present:
      return 2;
    case _Mark.correct:
      return 3;
  }
}

/// Wordle-style two-pass scoring to handle duplicates.
List<_Mark> _scoreGuess(String guess, String answer) {
  final res = List<_Mark>.filled(guess.length, _Mark.absent);
  final used = List<bool>.filled(answer.length, false);

  // pass 1: greens
  for (var i = 0; i < guess.length; i++) {
    if (guess[i] == answer[i]) {
      res[i] = _Mark.correct;
      used[i] = true;
    }
  }

  // pass 2: yellows
  for (var i = 0; i < guess.length; i++) {
    if (res[i] == _Mark.correct) continue;
    final ch = guess[i];
    for (var j = 0; j < answer.length; j++) {
      if (!used[j] && answer[j] == ch) {
        res[i] = _Mark.present;
        used[j] = true;
        break;
      }
    }
  }
  return res;
}

/* ───────── Page ───────── */

class UplingoPage extends StatefulWidget {
  const UplingoPage({super.key});
  @override
  State<UplingoPage> createState() => _UplingoPageState();
}

class _UplingoPageState extends State<UplingoPage> {
  static const int kWordLen = 5;
  static const int kMaxRows = 6;

  late String _answer;
  int _row = 0;
  final List<String> _guesses =
      List<String>.filled(kMaxRows, '', growable: false);
  final List<List<_Mark>?> _rowMarks =
      List<List<_Mark>?>.filled(kMaxRows, null, growable: false);

  // Tracks the best-known status per keyboard letter (A–Z).
  final Map<String, _Mark> _keyStatus = {};

  final Random _rnd = Random();

  // ---- Best score (integer) & history button ----
  int _best = 0; // ← shown under the rules

  @override
  void initState() {
    super.initState();
    _answer = _pickAnswer();
    _loadDictionary(); // try loading full dictionary from asset
    _loadBest();       // ← added
  }

  Future<void> _loadBest() async {
    _best = await _UplingoScores.instance.best();
    if (mounted) setState(() {});
  }

  Future<void> _openScores() async {
    final hist = await _UplingoScores.instance.history();
    final best = await _UplingoScores.instance.best();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Uplingo — Score History',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _ink),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Color(0xFF0D7C66), size: 18),
                      const SizedBox(width: 6),
                      Text('Best Score: $best',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: hist.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text('No games played yet.',
                            style: TextStyle(color: Colors.black54)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: hist.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = hist[i];
                          final when =
                              '${e.at.year.toString().padLeft(4, '0')}-${e.at.month.toString().padLeft(2, '0')}-${e.at.day.toString().padLeft(2, '0')} '
                              '${e.at.hour.toString().padLeft(2, '0')}:${e.at.minute.toString().padLeft(2, '0')}';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            leading: const Icon(Icons.emoji_events_rounded,
                                color: Color(0xFF0D7C66)),
                            title: Text('Score ${e.score}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(when),
                            dense: true,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    _best = best;
    if (mounted) setState(() {});
  }

  Future<void> _loadDictionary() async {
    try {
      // Put your full list at assets/words/words_5.txt (lowercase, one per line)
      final txt = await rootBundle.loadString('assets/words/words_5.txt');
      final lines = txt
          .split(RegExp(r'\r?\n'))
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.length == 5 && RegExp(r'^[a-z]+$').hasMatch(s));
      setState(() {
        _validWords = {..._validWords, ...lines};
        // ensure all answer words are allowed even if not in file
        _validWords.addAll(_answers);
      });
    } catch (_) {
      // asset missing -> fallback list already loaded
      _validWords.addAll(_answers);
    }
  }

  String _pickAnswer() {
    final list = _answersSafe;
    return list[_rnd.nextInt(list.length)];
  }

  void _restart() {
    setState(() {
      _answer = _pickAnswer();
      _row = 0;
      for (var i = 0; i < kMaxRows; i++) {
        _guesses[i] = '';
        _rowMarks[i] = null;
      }
      _keyStatus.clear();
    });
  }

  void _typeLetter(String ch) {
    if (_row >= kMaxRows) return;
    final cur = _guesses[_row];
    if (cur.length >= kWordLen) return;
    setState(() => _guesses[_row] = cur + ch.toLowerCase());
  }

  void _backspace() {
    if (_row >= kMaxRows) return;
    final cur = _guesses[_row];
    if (cur.isEmpty) return;
    setState(() => _guesses[_row] = cur.substring(0, cur.length - 1));
  }

  // Integer score: first-try win = 60, last-try win = 10, loss = 0.
  int _scoreForWin(int attemptsUsed) {
    final remaining = (kMaxRows - (attemptsUsed - 1)).clamp(1, kMaxRows);
    return remaining * 10;
  }

  void _submit() async {
    if (_row >= kMaxRows) return;
    final guess = _guesses[_row];
    if (guess.length != kWordLen) {
      _snack('Need $kWordLen letters.');
      return;
    }
    if (!_validWords.contains(guess)) {
      _snack('Not in word list.');
      return;
    }

    final marks = _scoreGuess(guess, _answer);
    _rowMarks[_row] = marks;
    _updateKeyStatus(guess, marks);

    if (guess == _answer) {
      final attemptsUsed = _row + 1; // 1..6
      final score = _scoreForWin(attemptsUsed);
      final isBest = await _UplingoScores.instance.record(score);
      if (isBest) {
        _best = score;
        if (mounted) setState(() {});
      }
      setState(() => _row = kMaxRows);
      _snack('Correct! 🎉');
      return;
    }

    // Not correct -> advance row; if this was the last attempt, record a 0
    final nextRow = _row + 1;
    if (nextRow == kMaxRows) {
      await _UplingoScores.instance.record(0);
      _best = await _UplingoScores.instance.best();
    }
    setState(() {
      _row = nextRow;
      if (_row == kMaxRows) {
        _snack('The word was "${_answer.toUpperCase()}".');
      }
    });
  }

  void _updateKeyStatus(String guess, List<_Mark> marks) {
    for (var i = 0; i < guess.length; i++) {
      final key = guess[i].toUpperCase();
      final next = marks[i];
      final prev = _keyStatus[key] ?? _Mark.unknown;
      if (_rank(next) > _rank(prev)) {
        _keyStatus[key] = next;
      }
    }
    setState(() {});
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _colorForMark(_Mark m) {
    switch (m) {
      case _Mark.correct:
        return _green;
      case _Mark.present:
        return _yellow;
      case _Mark.absent:
        return _grey;
      case _Mark.unknown:
        return Colors.white;
    }
  }

  Color _tileColor(int r, int c) {
    final marks = _rowMarks[r];
    if (marks == null) return Colors.white;
    return _colorForMark(marks[c]);
  }

  Color _tileBorder(int r) => r < _row ? Colors.transparent : _ink;

  Widget _buildBoard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(kMaxRows, (r) {
        final word = _guesses[r];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(kWordLen, (c) {
              final ch = (c < word.length) ? word[c].toUpperCase() : '';
              return Container(
                width: 46,
                height: 52,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tileColor(r, c),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _tileBorder(r)),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Text(
                  ch,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Colors.black,
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _kbdKey(String label, double w, double h) {
    final status = _keyStatus[label] ?? _Mark.unknown;
    return SizedBox(
      width: w,
      height: h,
      child: ElevatedButton(
        onPressed: () => _typeLetter(label),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: _colorForMark(status),
          elevation: 0,
          side: const BorderSide(color: _ink),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: status == _Mark.unknown ? _ink : Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _kbdSpecial({
    required IconData icon,
    required VoidCallback onTap,
    required double w,
    required double h,
  }) {
    return SizedBox(
      width: w,
      height: h,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          elevation: 0,
          side: const BorderSide(color: _ink),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Icon(icon, color: _ink, size: 18),
      ),
    );
  }

  Widget _buildKeyboard() {
    // Smaller keyboard
    const rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
    const double keyW = 34, keyH = 42, gap = 6;

    Widget buildRow(String keys, {bool bottom = false}) {
      final children = <Widget>[];
      if (bottom) {
        children.add(_kbdSpecial(
          icon: Icons.backspace_rounded,
          onTap: _backspace,
          w: keyW * 1.6,
          h: keyH,
        ));
        children.add(const SizedBox(width: gap));
      }
      for (final k in keys.characters) {
        final key = k.toUpperCase();
        children.add(_kbdKey(key, keyW, keyH));
        children.add(const SizedBox(width: gap));
      }
      if (children.isNotEmpty) children.removeLast();
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: children);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildRow(rows[0]),
        const SizedBox(height: 8),
        buildRow(rows[1]),
        const SizedBox(height: 8),
        buildRow(rows[2], bottom: true),
        const SizedBox(height: 12),
        SizedBox(
          width: 220,
          child: FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Submit'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;

    // The gradient wraps the entire Scaffold, guaranteeing full-bleed background.
    return Container(
      decoration: _bg(context),
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle:
              dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          title:
              const Text('Uplingo', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'Scores',                            // ← added
              onPressed: _openScores,                       // ← added
              icon: const Icon(Icons.equalizer_rounded),   // ← added
            ),
            IconButton(
              tooltip: 'New game',
              onPressed: _restart,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _ink),
                      ),
                      child: const Text(
                        'Guess the 5-letter word. Real words only. Press Submit.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Best score chip (matches Matching style)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _ink),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded,
                                color: Color(0xFF0D7C66), size: 18),
                            const SizedBox(width: 6),
                            Text('Best Score: $_best',
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBoard(),
                    const SizedBox(height: 18),
                    _buildKeyboard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
