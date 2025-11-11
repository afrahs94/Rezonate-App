// lib/pages/uplingo.dart
//
// Uplingo (Wordle-style)
// - Real-word validation (against _validWords)
// - Submit button (no auto-submit)
// - Smaller on-screen keyboard
// - Fix: NO black band at the bottom. We wrap the Scaffold with a full-screen
//   gradient Container so the background fills the whole window (including the
//   home-indicator area). No bottomNavigationBar is used.

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

/* ───────── Word lists ───────── */

const Set<String> _validWords = {
  // compact common dictionary (lowercase)
  'about','above','actor','acute','adopt','adult','after','again','agent','agree','ahead','alarm',
  'album','alert','alike','allow','alone','along','alter','among','angle','angry','apple','apply',
  'april','argue','arise','array','aside','asset','audio','audit','avoid','awake','aware','badge',
  'basic','beach','begin','being','below','bench','bible','birth','black','blade','blame','blank',
  'blast','blind','block','blood','board','boost','booth','bound','brain','brand','bread','break',
  'breed','brick','brief','bring','broad','broke','brown','brush','build','buyer','cabin','cable',
  'carry','catch','cause','chain','chair','chart','chase','cheap','check','cheek','chess','chief',
  'child','china','choir','chose','civil','claim','class','clean','clear','clerk','click','clock',
  'close','coach','coast','could','count','court','cover','craft','cream','crime','cross','crowd',
  'crown','cycle','daily','dance','dated','dealt','death','debut','delay','depth','dirty','doubt',
  'dozen','draft','drama','drawn','dream','dress','drill','drink','drive','drove','dying','eager',
  'early','earth','eight','elite','empty','enemy','enjoy','enter','entry','equal','error','event',
  'every','exact','exist','extra','faith','false','fault','favor','fewer','fiber','field','fifth',
  'fifty','fight','final','finds','first','fixed','flash','fleet','floor','fluid','focus','force',
  'forth','forty','forum','found','frame','fresh','front','fruit','fully','funny','giant','given',
  'glass','globe','going','grace','grade','grain','grand','grant','grass','great','green','greet',
  'group','growl','grown','guard','guess','guest','guide','habit','happy','harsh','heart','heavy',
  'hence','hobby','honor','horse','hotel','house','human','humor','ideal','image','imply','index',
  'inner','input','issue','jeans','joint','judge','juice','kneel','knife','known','label','labor',
  'large','laser','later','laugh','layer','learn','least','leave','legal','lemon','level','light',
  'limit','local','logic','loose','lucky','lunch','magic','major','maker','march','match','maybe',
  'mayor','meant','media','metal','minor','mixed','model','money','month','moral','motor','mount',
  'mouse','mouth','movie','music','naive','nasty','nerve','never','newer','night','ninth','noble',
  'noise','north','novel','nurse','occur','ocean','offer','often','older','olive','onion','order',
  'other','ought','paint','panel','paper','party','pause','peace','pearl','phase','phone','photo',
  'piece','pilot','pitch','place','plain','plane','plant','plate','plead','point','polar','porch',
  'pound','power','press','price','pride','prime','print','prior','prize','proof','proud','prove',
  'queen','quick','quiet','quite','quota','quote','radio','raise','range','rapid','ratio','reach',
  'react','ready','realm','refer','right','rigid','rival','river','robot','rough','round','route',
  'royal','rural','sadly','safer','salad','scale','scene','scope','score','scout','screw','seize',
  'sense','serve','seven','sever','shade','shake','shall','shame','shape','share','sharp','sheep',
  'sheer','sheet','shelf','shell','shift','shine','shirt','shock','shoot','shore','short','shown',
  'sight','since','skill','skirt','sleep','slide','slope','small','smart','smile','smoke','solid',
  'solve','sorry','sound','south','space','spare','speak','speed','spend','spent','spice','spite',
  'split','spoke','sport','staff','stage','stain','stair','stake','stand','stare','start','state',
  'steam','steel','steep','stick','still','stock','stone','stood','store','storm','story','stove',
  'strap','straw','strip','stuck','study','stuff','style','sugar','suite','sunny','super','sweet',
  'table','taken','taste','taxes','teach','teeth','terry','thank','their','theme','there','these',
  'thick','thing','think','third','those','three','threw','throw','tight','tired','title','today',
  'tooth','topic','total','touch','tough','tower','trace','track','trade','trail','train','treat',
  'trend','trial','tribe','trick','truck','truly','trust','truth','twice','uncle','under','union',
  'unity','until','upper','upset','urban','usage','usual','vague','valid','value','video','virus',
  'visit','vital','vivid','voice','voter','waste','watch','water','weary','weigh','weird','whale',
  'wheat','wheel','where','which','while','white','whole','whose','widow','width','woman','women',
  'worst','worth','wound','write','wrong','young','youth',
};

const List<String> _answers = [
  'apple','share','train','night','prize','teeth','water','music','green',
  'movie','about','quiet','laugh','radio','solid','sweet','value','vital',
];

List<String> get _answersSafe {
  final filtered =
      _answers.where((w) => w.length == 5 && _validWords.contains(w)).toList();
  return filtered.isEmpty ? const ['apple'] : filtered;
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
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    _answer = _pickAnswer();
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
      }
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
    if (guess == _answer) {
      _snack('Correct! 🎉');
      setState(() => _row = kMaxRows);
      return;
    }
    setState(() {
      _row += 1;
      if (_row == kMaxRows) {
        _snack('The word was "${_answer.toUpperCase()}".');
      }
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _tileColor(int r, int c) {
    final guess = _guesses[r];
    if (r >= _row) return Colors.white; // current/future rows
    if (c >= guess.length) return Colors.white;
    final ch = guess[c];
    if (_answer[c] == ch) return const Color(0xFF0D7C66); // correct
    if (_answer.contains(ch)) return const Color(0xFFE9C46A); // present
    return const Color(0xFFCBD5E1); // absent
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
    return SizedBox(
      width: w,
      height: h,
      child: ElevatedButton(
        onPressed: () => _typeLetter(label),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          elevation: 0,
          side: const BorderSide(color: _ink),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w700,
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
        children.add(_kbdKey(k, keyW, keyH));
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
        backgroundColor: Colors
            .transparent, // keep transparent so the outer gradient is visible
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
        // No bottomNavigationBar (that can reintroduce a black strip)
        body: SafeArea(
          // allow content above the home-indicator while gradient remains behind it
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
