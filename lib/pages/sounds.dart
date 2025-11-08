// lib/pages/sounds.dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:new_rezonate/main.dart' as app;

class SoundsPage extends StatefulWidget {
  const SoundsPage({super.key});

  @override
  State<SoundsPage> createState() => _SoundsPageState();
}

class _SoundsPageState extends State<SoundsPage> {
  final _player = AudioPlayer();
  final _scrollController = ScrollController();

  String _query = '';
  String _category = 'All';
  bool _looping = true;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  String? _currentId;
  bool _playing = false;

  Timer? _sleepTimer;
  Duration _sleepDuration = Duration.zero;

  static const _prefsRecentKey = 'recent_sounds_v1';
  List<String> _recentIds = const [];

  final List<_SoundTrack> _tracks = const [
    _SoundTrack(
      id: 'focus_deep',
      title: 'Deep Focus',
      category: 'Focus',
      imageUrl:
          'https://images.unsplash.com/photo-1486312338219-ce68d2c6f44d?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    ),
    _SoundTrack(
      id: 'focus_alpha',
      title: 'Alpha Waves',
      category: 'Focus',
      imageUrl:
          'https://images.unsplash.com/photo-1496307042754-b4aa456c4a2d?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    ),
    _SoundTrack(
      id: 'focus_binaural',
      title: 'Binaural Beats',
      category: 'Focus',
      imageUrl:
          'https://images.unsplash.com/photo-1527443224154-c4f2a9b1d67a?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    ),
    _SoundTrack(
      id: 'sleep_rain',
      title: 'Soft Rain',
      category: 'Sleep',
      imageUrl:
          'https://images.unsplash.com/photo-1503435824048-a799a3a84bf7?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    ),
    _SoundTrack(
      id: 'sleep_ocean',
      title: 'Ocean Waves',
      category: 'Sleep',
      imageUrl:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
    ),
    _SoundTrack(
      id: 'sleep_white',
      title: 'White Noise',
      category: 'Sleep',
      imageUrl:
          'https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
    ),
    _SoundTrack(
      id: 'study_lofi',
      title: 'Lo-Fi Study',
      category: 'Study',
      imageUrl:
          'https://images.unsplash.com/photo-1526378722484-bd91ca387e72?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
    ),
    _SoundTrack(
      id: 'study_piano',
      title: 'Soft Piano',
      category: 'Study',
      imageUrl:
          'https://images.unsplash.com/photo-1520523839897-bd0b52f945a0?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
    ),
    _SoundTrack(
      id: 'study_strings',
      title: 'Calm Strings',
      category: 'Study',
      imageUrl:
          'https://images.unsplash.com/photo-1511379938547-c1f69419868d?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
    ),
    _SoundTrack(
      id: 'nature_forest',
      title: 'Forest Birds',
      category: 'Nature',
      imageUrl:
          'https://images.unsplash.com/photo-1469474968028-56623f02e42e?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
    ),
    _SoundTrack(
      id: 'nature_stream',
      title: 'Mountain Stream',
      category: 'Nature',
      imageUrl:
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3',
    ),
    _SoundTrack(
      id: 'nature_fire',
      title: 'Campfire',
      category: 'Nature',
      imageUrl:
          'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',
    ),
    _SoundTrack(
      id: 'meditation_om',
      title: 'Meditation Om',
      category: 'Meditation',
      imageUrl:
          'https://images.unsplash.com/photo-1518481612222-68bbe828ecd1?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3',
    ),
    _SoundTrack(
      id: 'nature_thunder',
      title: 'Distant Thunder',
      category: 'Nature',
      imageUrl:
          'https://images.unsplash.com/photo-1500674425229-f692875b0ab7?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3',
    ),
    _SoundTrack(
      id: 'sci_fi_drone',
      title: 'Sci-Fi Drone',
      category: 'Focus',
      imageUrl:
          'https://images.unsplash.com/photo-1462332420958-a05d1e002413?q=80&w=1200&auto=format&fit=crop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _wireAudio();
    _loadRecents();
  }

  void _wireAudio() {
    _player.onPlayerStateChanged.listen((state) {
      setState(() => _playing = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) => setState(() => _dur = d));
    _player.onPositionChanged.listen((p) => setState(() => _pos = p));
    _player.onPlayerComplete.listen((_) async {
      if (_looping) {
        await _player.seek(Duration.zero);
        await _player.resume();
      } else {
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
      }
    });
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _recentIds = prefs.getStringList(_prefsRecentKey) ?? const []);
  }

  Future<void> _remember(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = [..._recentIds]..remove(id)..insert(0, id);
    if (list.length > 8) list.removeRange(8, list.length);
    setState(() => _recentIds = list);
    await prefs.setStringList(_prefsRecentKey, list);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _player.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<_SoundTrack> get _filtered {
    final lower = _query.trim().toLowerCase();
    return _tracks.where((t) {
      final byCat = _category == 'All' || t.category == _category;
      final byText = lower.isEmpty ||
          t.title.toLowerCase().contains(lower) ||
          t.category.toLowerCase().contains(lower);
      return byCat && byText;
    }).toList();
  }

  Future<void> _play(_SoundTrack t) async {
    try {
      if (_currentId == t.id && _playing) {
        await _player.pause();
        return;
      }
      if (_currentId != t.id) {
        await _player.stop();
        setState(() {
          _currentId = t.id;
          _pos = Duration.zero;
          _dur = Duration.zero;
        });
      }
      await _player.setReleaseMode(_looping ? ReleaseMode.loop : ReleaseMode.stop);
      await _player.play(UrlSource(t.url));
      _remember(t.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not play "${t.title}".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _togglePlayPause() async {
    if (_currentId == null) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _seek(double seconds) async {
    await _player.seek(Duration(seconds: seconds.round()));
  }

  Future<void> _setLoop(bool v) async {
    setState(() => _looping = v);
    await _player.setReleaseMode(v ? ReleaseMode.loop : ReleaseMode.stop);
  }

  void _openSleepTimer() async {
    final picked = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Duration temp =
            _sleepDuration == Duration.zero ? const Duration(minutes: 30) : _sleepDuration;
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: BorderRadius.circular(18),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Sleep Timer',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 150,
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: temp,
                    minuteInterval: 1,
                    onTimerDurationChanged: (d) => temp = d,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D7C66),
                          side: const BorderSide(color: Color(0xFF0D7C66)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(Duration.zero),
                        child: const Text('Off'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D7C66),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(temp),
                        child: const Text('Set'),
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

    if (picked == null) return;
    _sleepTimer?.cancel();
    setState(() => _sleepDuration = picked);

    if (picked == Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sleep timer off'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _sleepTimer = Timer(picked, () async {
      await _player.stop();
      setState(() {
        _playing = false;
        _pos = Duration.zero;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sleep timer: stopped after ${_formatDuration(picked)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sleep timer set for ${_formatDuration(picked)}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours >= 1 && d.inMinutes % 60 == 0) return '${d.inHours}h';
    if (d.inHours >= 1) return '${d.inHours}h ${(d.inMinutes % 60)}m';
    return '${d.inMinutes}m';
  }

  BoxDecoration _bg(BuildContext context) {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final miniActive = _currentId != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Text(
                        'Sounds',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: _looping ? 'Loop on' : 'Loop off',
                              icon: Icon(
                                _looping ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                                color: const Color(0xFF0D7C66),
                              ),
                              onPressed: () => _setLoop(!_looping),
                            ),
                            IconButton(
                              tooltip: 'Sleep timer',
                              icon: const Icon(Icons.timer_rounded, color: Color(0xFF0D7C66)),
                              onPressed: _openSleepTimer,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: _SearchBar(onChanged: (v) => setState(() => _query = v)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _CategoryBar(
                  active: _category,
                  onChanged: (c) => setState(() => _category = c),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final t = _filtered[i];
                      final isCurrent = _currentId == t.id;
                      return _SoundTile(
                        track: t,
                        isCurrent: isCurrent,
                        isPlaying: isCurrent && _playing,
                        onTap: () => _play(t),
                      );
                    },
                  ),
                ),
              ),
              if (miniActive)
                _MiniPlayer(
                  title: _tracks.firstWhere((e) => e.id == _currentId!).title,
                  playing: _playing,
                  pos: _pos,
                  dur: _dur,
                  onToggle: _togglePlayPause,
                  onSeek: _seek,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ─────────────────── Reusable UI ─────────────────── */
class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    final fill = (dark ? Colors.black : Colors.white).withOpacity(0.25);
    final border = (dark ? Colors.white : Colors.black).withOpacity(0.22);

    return AnimatedScale(
      scale: _focused ? 1.01 : 1.0,
      duration: const Duration(milliseconds: 160),
      child: SizedBox(
        height: 44,
        child: Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: TextField(
            controller: _ctrl,
            onChanged: (v) {
              widget.onChanged(v);
              setState(() {});
            },
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search sounds…',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _ctrl.clear();
                        widget.onChanged('');
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              filled: true,
              fillColor: fill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: border, width: 0.9),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: border, width: 1.2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.active, required this.onChanged});
  final String active;
  final ValueChanged<String> onChanged;

  static const _cats = ['All', 'Focus', 'Sleep', 'Study', 'Nature', 'Meditation'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = _cats[i];
          return _ChipButton(
            label: c,
            selected: c == active,
            onTap: () => onChanged(c),
          );
        },
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF0D7C66);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? selectedColor.withOpacity(0.9) : Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundTile extends StatefulWidget {
  const _SoundTile({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  final _SoundTrack track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  State<_SoundTile> createState() => _SoundTileState();
}

class _SoundTileState extends State<_SoundTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final border = Colors.black.withOpacity(0.12);

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 110),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(child: _NetImage(url: widget.track.imageUrl)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.15),
                        Colors.black.withOpacity(0.36),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: widget.isPlaying ? 1 : 0.7,
                        child: const Icon(Icons.equalizer_rounded,
                            size: 18, color: Color(0xFFBDE5DB)),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.track.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.15,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black38)],
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.track.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black26)],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _RoundButton(
                      icon: widget.isCurrent && widget.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      onTap: widget.onTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetImage extends StatelessWidget {
  const _NetImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
      errorBuilder: (ctx, _, __) => const Center(
        child: Icon(Icons.music_note_rounded, size: 44, color: Colors.white70),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.title,
    required this.playing,
    required this.pos,
    required this.dur,
    required this.onToggle,
    required this.onSeek,
  });

  final String title;
  final bool playing;
  final Duration pos;
  final Duration dur;
  final VoidCallback onToggle;
  final ValueChanged<double> onSeek;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = dur.inSeconds == 0 ? 1.0 : dur.inSeconds.toDouble();
    final value = (pos.inSeconds.clamp(0, dur.inSeconds)).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.30),
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.16))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note_rounded, size: 18, color: Color(0xFF0D7C66)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _RoundButton(
                icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onTap: onToggle,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(_fmt(pos), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Expanded(
                child: Slider(
                  value: value,
                  max: total,
                  onChanged: onSeek,
                ),
              ),
              Text(_fmt(dur), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0D7C66),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 36,
          width: 36,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _SoundTrack {
  final String id;
  final String title;
  final String category;
  final String imageUrl;
  final String url;
  const _SoundTrack({
    required this.id,
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.url,
  });
}
