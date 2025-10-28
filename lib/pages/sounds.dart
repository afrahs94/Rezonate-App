// lib/pages/sounds.dart
import 'dart:async';
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

  // UI / State
  String _query = '';
  String _category = 'All';
  bool _looping = true;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  String? _currentId;
  bool _playing = false;
  Timer? _sleepTimer;

  static const _prefsRecentKey = 'recent_sounds_v1';
  List<String> _recentIds = const [];

  // Tracks (NETWORK demo URLs; replace with AssetSource for local files)
  final List<_SoundTrack> _tracks = const [
    // Focus
    _SoundTrack(
      id: 'focus_deep',
      title: 'Deep Focus',
      category: 'Focus',
      imageUrl: 'https://picsum.photos/id/1003/1200/800',
      url: 'https://cdn.pixabay.com/download/audio/2023/01/16/audio_0f5f6f62e8.mp3?filename=deep-focus-ambient-133281.mp3',
    ),
    _SoundTrack(
      id: 'focus_alpha',
      title: 'Alpha Waves',
      category: 'Focus',
      imageUrl: 'https://picsum.photos/id/1015/1200/800',
      url: 'https://cdn.pixabay.com/download/audio/2022/10/24/audio_947bdc2a8f.mp3?filename=alpha-waves-ambient-124008.mp3',
    ),
    _SoundTrack(
      id: 'focus_binaural',
      title: 'Binaural Beats',
      category: 'Focus',
      imageUrl: 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?q=80&w=1200&auto=format&fit=crop',
      url: 'https://cdn.pixabay.com/download/audio/2022/03/10/audio_7b8e3d7e9a.mp3?filename=binaural-beats-ambient-18491.mp3',
    ),

    // Sleep
    _SoundTrack(
      id: 'sleep_rain',
      title: 'Soft Rain',
      category: 'Sleep',
      imageUrl: 'https://images.unsplash.com/photo-1469474968028-56623f02e42e?q=80&w=1200&auto=format&fit=crop',
      url: 'https://cdn.pixabay.com/download/audio/2021/10/26/audio_2e1f3a4e7f.mp3?filename=rain-ambient-9816.mp3',
    ),
    _SoundTrack(
      id: 'sleep_ocean',
      title: 'Ocean Waves',
      category: 'Sleep',
      imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=1200&auto=format&fit=crop',
      url: 'https://cdn.pixabay.com/download/audio/2021/10/26/audio_4bff7f8e77.mp3?filename=sea-waves-ambient-10378.mp3',
    ),
    _SoundTrack(
      id: 'sleep_white',
      title: 'White Noise',
      category: 'Sleep',
      imageUrl: 'https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=1200&auto=format&fit=crop',
      url: 'https://cdn.pixabay.com/download/audio/2021/10/26/audio_4d4b6339f6.mp3?filename=white-noise-ambient-9991.mp3',
    ),

    // Study
    _SoundTrack(
      id: 'study_lofi',
      title: 'Lo-Fi Study',
      category: 'Study',
      imageUrl: 'https://images.unsplash.com/photo-1519681393784-d120267933ba?q=80&w=1200&auto=format&fit=crop',
      url: 'https://cdn.pixabay.com/download/audio/2022/03/15/audio_8d2b3f9f30.mp3?filename=lofi-study-ambient-19150.mp3',
    ),
    _SoundTrack(
      id: 'study_piano',
      title: 'Soft Piano',
      category: 'Study',
      imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=1200&auto=format&fit=crop',
      url: 'https://cdn.pixabay.com/download/audio/2022/03/15/audio_48453b8244.mp3?filename=soft-piano-ambient-19144.mp3',
    ),
    _SoundTrack(
      id: 'study_strings',
      title: 'Calm Strings',
      category: 'Study',
      imageUrl: 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?q=80&w=1200&auto=format&fit=crop',
      url: 'https://cdn.pixabay.com/download/audio/2022/03/09/audio_4d8e1e9a51.mp3?filename=calm-strings-ambient-18366.mp3',
    ),

    // Nature
    _SoundTrack(
      id: 'nature_forest',
      title: 'Forest Birds',
      category: 'Nature',
      imageUrl: 'https://images.unsplash.com/photo-1472491235688-bdc81a63246e?q=80&w=1200&auto=format&fit=crop',
      url: 'https://cdn.pixabay.com/download/audio/2021/10/26/audio_9a39e4fa0a.mp3?filename=forest-birds-ambient-10976.mp3',
    ),
    _SoundTrack(
      id: 'nature_stream',
      title: 'Mountain Stream',
      category: 'Nature',
      imageUrl: 'https://picsum.photos/id/1056/1200/800',
      url: 'https://cdn.pixabay.com/download/audio/2021/11/08/audio_7a0c0aa1a3.mp3?filename=stream-ambient-12028.mp3',
    ),
    _SoundTrack(
      id: 'nature_fire',
      title: 'Campfire',
      category: 'Nature',
      imageUrl: 'https://images.unsplash.com/photo-1500043357865-c6b8827edf39?q=80&w=1200&auto=format&fit=crop',
      url: 'https://cdn.pixabay.com/download/audio/2021/10/26/audio_4a22d5b355.mp3?filename=campfire-ambient-9748.mp3',
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

  List<_SoundTrack> get _recents {
    final map = {for (final t in _tracks) t.id: t};
    final items = <_SoundTrack>[];
    for (final id in _recentIds) {
      final t = map[id];
      if (t != null) items.add(t);
    }
    return items;
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
        await _player.setSourceUrl(t.url);
      }
      await _player.setReleaseMode(_looping ? ReleaseMode.loop : ReleaseMode.stop);
      await _player.resume();
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
    final choice = await showModalBottomSheet<_SleepChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SleepTimerSheet(),
    );
    if (choice == null) return;

    _sleepTimer?.cancel();
    if (choice.minutes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sleep timer off'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    _sleepTimer = Timer(Duration(minutes: choice.minutes), () {
      _player.stop();
      setState(() {
        _playing = false;
        _pos = Duration.zero;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sleep timer: stopped after ${choice.label.toLowerCase()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sleep timer set for ${choice.label.toLowerCase()}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  BoxDecoration _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
            : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
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
              // ===== HEADER styled like Sleep Tracker (chevron left, centered title, icons right)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Left back chevron (matches other pages)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      // Center title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.music_note_rounded, size: 18, color: Color(0xFF0D7C66)),
                          SizedBox(width: 6),
                          Text(
                            'Sounds',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                          ),
                        ],
                      ),
                      // Right controls (Loop + Sleep) like the plus on Sleep Tracker
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: _looping ? 'Loop on' : 'Loop off',
                              icon: Icon(
                                _looping ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                                color: const Color(0xFF0D7C66),
                              ),
                              onPressed: () => _setLoop(!_looping),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
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

              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: _SearchBar(onChanged: (v) => setState(() => _query = v)),
              ),

              // Category chips
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _CategoryBar(
                  active: _category,
                  onChanged: (c) => setState(() => _category = c),
                ),
              ),

              // Recents
              if (_recents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Recently played',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              if (_recents.isNotEmpty)
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (_, i) => _RecentCard(
                      track: _recents[i],
                      isCurrent: _recents[i].id == _currentId,
                      onTap: () => _play(_recents[i]),
                    ),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemCount: _recents.length,
                  ),
                ),

              // Grid
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, _recents.isEmpty ? 6 : 8, 12, 8),
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

              // Mini player
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
              hintStyle: const TextStyle(fontSize: 14),
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

  static const _cats = ['All', 'Focus', 'Sleep', 'Study', 'Nature'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
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
    final dark = app.ThemeControllerScope.of(context).isDark;
    final base = (dark ? Colors.white : Colors.white).withOpacity(0.25);
    const selectedColor = Color(0xFF0D7C66);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? selectedColor.withOpacity(0.90) : base,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: (dark ? Colors.white : Colors.black).withOpacity(0.14),
              width: 0.9,
            ),
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
    final dark = app.ThemeControllerScope.of(context).isDark;
    final border = (dark ? Colors.white : Colors.black).withOpacity(0.12);

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
              // Image with graceful error handling (no red X)
              Positioned.fill(child: _NetImage(url: widget.track.imageUrl)),
              // Overlay for readability
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
              // Content
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
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        shadows: const [Shadow(blurRadius: 6, color: Colors.black26)],
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
        return Container(
          color: Colors.black.withOpacity(0.05),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (ctx, _, __) {
        // Graceful fallback – soft gradient + music note
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFBDA9DB), Color(0xFF41B3A2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(Icons.music_note_rounded, size: 44, color: Colors.white70),
          ),
        );
      },
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.track, required this.isCurrent, required this.onTap});
  final _SoundTrack track;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    final border = (dark ? Colors.white : Colors.black).withOpacity(0.12);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: _NetImage(url: track.imageUrl)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.10), Colors.black.withOpacity(0.35)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _RoundButton(icon: Icons.play_arrow_rounded, onTap: onTap),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800)),
                        Text(
                          track.category,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 2),
                      child: Icon(Icons.volume_up_rounded,
                          size: 18, color: Color(0xFFBDE5DB)),
                    ),
                ],
              ),
            ),
          ],
        ),
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
    final dark = app.ThemeControllerScope.of(context).isDark;
    final bg = (dark ? Colors.white : Colors.white).withOpacity(0.30);
    final border = (dark ? Colors.white : Colors.black).withOpacity(0.16);
    final total = dur.inSeconds == 0 ? 1.0 : dur.inSeconds.toDouble();
    final value = (pos.inSeconds.clamp(0, dur.inSeconds)).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 0.9)),
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

/* ─────────────────── Models ─────────────────── */

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

/* ─────────────────── Sleep Timer ─────────────────── */

class _SleepChoice {
  final String label;
  final int minutes; // 0 = off
  const _SleepChoice(this.label, this.minutes);
}

class _SleepTimerSheet extends StatelessWidget {
  _SleepTimerSheet({super.key});

  final _choices = const <_SleepChoice>[
    _SleepChoice('Off', 0),
    _SleepChoice('15 minutes', 15),
    _SleepChoice('30 minutes', 30),
    _SleepChoice('45 minutes', 45),
    _SleepChoice('60 minutes', 60),
    _SleepChoice('90 minutes', 90),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      decoration: BoxDecoration(
        color: (dark ? Colors.white : Colors.white).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetGrabber(),
          const SizedBox(height: 6),
          const Text('Sleep Timer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          ..._choices.map((c) => ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.timer_rounded, color: Color(0xFF0D7C66)),
                title: Text(c.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.of(context).pop(c),
              )),
        ],
      ),
    );
  }
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
