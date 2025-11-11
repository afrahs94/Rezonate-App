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

  @override
  void initState() {
    super.initState();
    _answer = _pickAnswer();
    _loadDictionary(); // try loading full dictionary from asset
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

  void _submit() {
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
      setState(() => _row = kMaxRows);
      _snack('Correct! 🎉');
      return;
    }

    setState(() {
      _row += 1;
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
