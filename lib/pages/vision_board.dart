import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_rezonate/main.dart' as app;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

enum BoardShape { square, rounded, circle }

Map<String, dynamic> _offset(Offset o) => {'dx': o.dx, 'dy': o.dy};
Offset _toOffset(Map<String, dynamic> m) =>
    Offset((m['dx'] as num).toDouble(), (m['dy'] as num).toDouble());

class BoardImage {
  String id;
  String storagePath;
  String? url;
  String? localPath; // runtime-only
  Offset pos;        // center (canvas coords)
  double scaleX;     // free resize (independent axes)
  double scaleY;
  double rotation;
  BoardShape shape;
  double baseW;
  double baseH;

  bool get isLocal => localPath != null && (url == null || url!.isEmpty);

  BoardImage({
    required this.id,
    required this.storagePath,
    required this.url,
    required this.localPath,
    required this.pos,
    required this.baseW,
    required this.baseH,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
    this.shape = BoardShape.rounded,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'storagePath': storagePath,
        'url': url,
        'pos': _offset(pos),
        'scaleX': scaleX,
        'scaleY': scaleY,
        'scale': (scaleX + scaleY) / 2, // legacy compatibility
        'rotation': rotation,
        'shape': shape.name,
        'baseW': baseW,
        'baseH': baseH,
      };

  static BoardImage fromMap(Map<String, dynamic> m) {
    final legacy = (m['scale'] as num?)?.toDouble() ?? 1.0;
    return BoardImage(
      id: m['id'],
      storagePath: (m['storagePath'] ?? '') as String,
      url: (m['url'] as String?),
      localPath: null,
      pos: _toOffset(Map<String, dynamic>.from(m['pos'])),
      scaleX: (m['scaleX'] as num?)?.toDouble() ?? legacy,
      scaleY: (m['scaleY'] as num?)?.toDouble() ?? legacy,
      rotation: (m['rotation'] as num?)?.toDouble() ?? 0,
      shape: BoardShape.values.firstWhere(
        (e) => e.name == (m['shape'] ?? 'rounded'),
        orElse: () => BoardShape.rounded,
      ),
      baseW: (m['baseW'] as num?)?.toDouble() ?? 160,
      baseH: (m['baseH'] as num?)?.toDouble() ?? 160,
    );
  }
}

class BoardText {
  String id;
  String text;
  int color;
  Offset pos;
  double scale;
  double rotation;

  BoardText({
    required this.id,
    required this.text,
    required this.color,
    required this.pos,
    this.scale = 1,
    this.rotation = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'color': color,
        'pos': _offset(pos),
        'scale': scale,
        'rotation': rotation,
      };

  static BoardText fromMap(Map<String, dynamic> m) => BoardText(
        id: m['id'],
        text: m['text'] ?? '',
        color: (m['color'] as num).toInt(),
        pos: _toOffset(Map<String, dynamic>.from(m['pos'])),
        scale: (m['scale'] as num?)?.toDouble() ?? 1,
        rotation: (m['rotation'] as num?)?.toDouble() ?? 0,
      );
}

class DrawStroke {
  int color;
  double width;
  List<Offset> points;

  DrawStroke({required this.color, required this.width, required this.points});

  Map<String, dynamic> toMap() => {
        'color': color,
        'width': width,
        'points': points.map(_offset).toList(),
      };

  static DrawStroke fromMap(Map<String, dynamic> m) => DrawStroke(
        color: (m['color'] as num).toInt(),
        width: (m['width'] as num).toDouble(),
        points: (m['points'] as List)
            .map((e) => _toOffset(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class VisionBoardPage extends StatefulWidget {
  const VisionBoardPage({super.key});
  @override
  State<VisionBoardPage> createState() => _VisionBoardPageState();
}

enum EditMode { move, draw, text }

class _VisionBoardPageState extends State<VisionBoardPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _picker = ImagePicker();
  final _rnd = Random();

  final List<BoardImage> _images = [];
  final List<BoardText> _texts = [];
  final List<DrawStroke> _strokes = [];
  DrawStroke? _activeStroke;

  EditMode _mode = EditMode.move;
  int? _selectedImage;
  int? _selectedText;

  Color _penColor = Colors.black;
  double _penWidth = 5;

  Offset _startPos = Offset.zero;
  Offset _startFocal = Offset.zero;
  double _startScale = 1.0; // text only
  double _startRotation = 0;

  double _startScaleX = 1.0; // image
  double _startScaleY = 1.0;

  bool _loading = true;
  bool _saving = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  DateTime _lastLocalSave = DateTime.fromMillisecondsSinceEpoch(0);

  String get _uid => _auth.currentUser?.uid ?? 'guest';
  DocumentReference<Map<String, dynamic>> get _doc => _db
      .collection('users')
      .doc(_uid)
      .collection('vision_board')
      .doc('default');

  @override
  void initState() {
    super.initState();
    _attachLiveBoard();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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

  Future<bool> _prefetchUrl(String url) async {
    final completer = Completer<bool>();
    final img = NetworkImage(url);
    final stream = img.resolve(const ImageConfiguration());
    late ImageStreamListener l;
    l = ImageStreamListener(
      (image, sync) {
        completer.complete(true);
        stream.removeListener(l);
      },
      onError: (dynamic _, __) {
        completer.complete(false);
        stream.removeListener(l);
      },
    );
    stream.addListener(l);
    try {
      return await completer.future.timeout(const Duration(seconds: 5), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  void _attachLiveBoard() {
    _sub = _doc.snapshots().listen((snap) async {
      if (DateTime.now().difference(_lastLocalSave) <
          const Duration(milliseconds: 350)) {
        setState(() => _loading = false);
        return;
      }
      if (!snap.exists) {
        setState(() => _loading = false);
        return;
      }

      final m = snap.data()!;
      final imgs = (m['images'] as List? ?? [])
          .map((e) => BoardImage.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      final txts = (m['texts'] as List? ?? [])
          .map((e) => BoardText.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      final dr = (m['strokes'] as List? ?? [])
          .map((e) => DrawStroke.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      bool changed = false;
      for (int i = 0; i < imgs.length; i++) {
        final it = imgs[i];
        Future<void> _refreshFromStorage() async {
          if (it.storagePath.isEmpty) return;
          try {
            final url = await _storage.ref(it.storagePath).getDownloadURL();
            imgs[i] = BoardImage(
              id: it.id,
              storagePath: it.storagePath,
              url: url,
              localPath: null,
              pos: it.pos,
              baseW: it.baseW,
              baseH: it.baseH,
              scaleX: it.scaleX,
              scaleY: it.scaleY,
              rotation: it.rotation,
              shape: it.shape,
            );
            changed = true;
          } catch (_) {}
        }

        if (it.url == null || it.url!.isEmpty) {
          await _refreshFromStorage();
        } else {
          final ok = await _prefetchUrl(it.url!);
          if (!ok) await _refreshFromStorage();
        }
      }

      setState(() {
        final uploading = _images.where((e) => e.isLocal).toList();
        _images
          ..clear()
          ..addAll(imgs);
        for (final ph in uploading) {
          if (_images.indexWhere((e) => e.id == ph.id) == -1) {
            _images.add(ph);
          }
        }
        _texts
          ..clear()
          ..addAll(txts);
        _strokes
          ..clear()
          ..addAll(dr);
        _loading = false;
      });

      if (changed) await _saveBoard();
    }, onError: (_) => setState(() => _loading = false));
  }

  Future<void> _saveBoard() async {
    if (_saving) return;
    _saving = true;
    _lastLocalSave = DateTime.now();
    try {
      await _doc.set({
        'images': _images.map((e) => e.toMap()).toList(),
        'texts': _texts.map((e) => e.toMap()).toList(),
        'strokes': _strokes.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } finally {
      _saving = false;
    }
  }

  // ---------- keep content clear of header/footer ----------
  double _topBarrierPx(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.padding.top + kToolbarHeight + 8;
  }

  double _bottomBarrierPx(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.padding.bottom + 76;
  }

  Offset _clampPosForBox({
    required Offset pos,
    required Size baseSize,
    required double scaleX,
    required double scaleY,
  }) {
    final size = MediaQuery.sizeOf(context);
    final canvas = Size(size.width, size.height);
    final center = _visibleCenter(canvas, context);

    final halfW = (baseSize.width * scaleX) / 2;
    final halfH = (baseSize.height * scaleY) / 2;

    final leftMin = -center.dx + halfW + 8;
    final rightMax = size.width - center.dx - halfW - 8;

    final topMinDy = _topBarrierPx(context) - center.dy + halfH;
    final bottomMaxDy =
        (size.height - _bottomBarrierPx(context)) - center.dy - halfH;

    final clampedX = pos.dx.clamp(leftMin, rightMax);
    final clampedY = pos.dy.clamp(topMinDy, bottomMaxDy);
    return Offset(clampedX, clampedY);
  }

  void _clampCurrentSelection() {
    if (_selectedImage != null) {
      final it = _images[_selectedImage!];
      it.pos = _clampPosForBox(
        pos: it.pos,
        baseSize: Size(it.baseW, it.baseH),
        scaleX: it.scaleX,
        scaleY: it.scaleY,
      );
    } else if (_selectedText != null) {
      final t = _texts[_selectedText!];
      const base = Size(160, 48);
      t.pos = _clampPosForBox(
        pos: t.pos,
        baseSize: base,
        scaleX: t.scale,
        scaleY: t.scale,
      );
    }
  }
  // -------------------------------------------------------------------------------

  Future<Size> _naturalLogicalSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final dpr = ui.window.devicePixelRatio;
    final logicalW = image.width / dpr;
    final logicalH = image.height / dpr;
    const maxSide = 220.0;
    final longer = max(logicalW, logicalH);
    final scale = longer > maxSide ? (maxSide / longer) : 1.0;
    return Size(logicalW * scale, logicalH * scale);
  }

  Future<void> _addPhotos() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 90);
      if (files.isEmpty) return;

      final placeholders = <BoardImage>[];
      for (final f in files) {
        final id =
            'img_${DateTime.now().microsecondsSinceEpoch}_${_rnd.nextInt(9999)}';
        final path = 'vision_board/$_uid/$id.jpg';
        final sz = await _naturalLogicalSize(f.path);
        final initial = _clampPosForBox(
          pos: const Offset(0, 0),
          baseSize: sz,
          scaleX: 1,
          scaleY: 1,
        );
        placeholders.add(
          BoardImage(
            id: id,
            storagePath: path,
            url: null,
            localPath: f.path,
            pos: initial,
            baseW: sz.width,
            baseH: sz.height,
            scaleX: 1,
            scaleY: 1,
            rotation: 0,
            shape: BoardShape.rounded,
          ),
        );
      }

      setState(() => _images.addAll(placeholders));
      await _saveBoard();

      for (final ph in placeholders) {
        try {
          final ref = _storage.ref(ph.storagePath);
          await ref.putFile(File(ph.localPath!));
          final url = await ref.getDownloadURL();

          final idx = _images.indexWhere((e) => e.id == ph.id);
          if (idx != -1) {
            final cur = _images[idx];
            _images[idx] = BoardImage(
              id: cur.id,
              storagePath: cur.storagePath,
              url: url,
              localPath: null,
              pos: cur.pos,
              baseW: cur.baseW,
              baseH: cur.baseH,
              scaleX: cur.scaleX,
              scaleY: cur.scaleY,
              rotation: cur.rotation,
              shape: cur.shape,
            );
            _images[idx].pos = _clampPosForBox(
              pos: _images[idx].pos,
              baseSize: Size(_images[idx].baseW, _images[idx].baseH),
              scaleX: _images[idx].scaleX,
              scaleY: _images[idx].scaleY,
            );
          }
          await _saveBoard();
          if (mounted) setState(() {});
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _startTransform(Offset focal, {required bool isImage}) {
    if (isImage && _selectedImage != null) {
      final it = _images[_selectedImage!];
      _startPos = it.pos;
      _startScaleX = it.scaleX;
      _startScaleY = it.scaleY;
      _startRotation = it.rotation;
    } else if (!isImage && _selectedText != null) {
      final it = _texts[_selectedText!];
      _startPos = it.pos;
      _startScale = it.scale;
      _startRotation = it.rotation;
    }
    _startFocal = focal;
  }

  void _updateTransform(ScaleUpdateDetails d, {required bool isImage}) {
    setState(() {
      if (isImage && _selectedImage != null) {
        final it = _images[_selectedImage!];
        it.pos = _startPos + (d.focalPoint - _startFocal);
        it.scaleX = (_startScaleX * d.scale).clamp(.15, 8.0);
        it.scaleY = (_startScaleY * d.scale).clamp(.15, 8.0);
        it.rotation = _startRotation + d.rotation;
        it.pos = _clampPosForBox(
          pos: it.pos,
          baseSize: Size(it.baseW, it.baseH),
          scaleX: it.scaleX,
          scaleY: it.scaleY,
        );
      } else if (!isImage && _selectedText != null) {
        final it = _texts[_selectedText!];
        it.pos = _startPos + (d.focalPoint - _startFocal);
        it.scale = (_startScale * d.scale).clamp(.3, 6.0);
        it.rotation = _startRotation + d.rotation;
        it.pos = _clampPosForBox(
          pos: it.pos,
          baseSize: const Size(160, 48),
          scaleX: it.scale,
          scaleY: it.scale,
        );
      }
    });
  }

  void _finishTransform() {
    _clampCurrentSelection();
    _saveBoard();
  }

  // drawing on background (unchanged)
  void _onPanStart(DragStartDetails d, Size canvas) {
    if (_mode != EditMode.draw) return;
    final localY = d.localPosition.dy;
    if (localY <= _topBarrierPx(context) ||
        localY >= (canvas.height - _bottomBarrierPx(context))) return;

    final center = _visibleCenter(canvas, context);
    _activeStroke = DrawStroke(
      color: _penColor.value,
      width: _penWidth,
      points: [d.localPosition - center],
    );
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d, Size canvas) {
    if (_mode != EditMode.draw || _activeStroke == null) return;
    final localY = d.localPosition.dy;
    if (localY <= _topBarrierPx(context) ||
        localY >= (canvas.height - _bottomBarrierPx(context))) return;

    final center = _visibleCenter(canvas, context);
    _activeStroke!.points.add(d.localPosition - center);
    setState(() {});
  }

  void _onPanEnd(Size canvas) {
    if (_mode != EditMode.draw || _activeStroke == null) return;
    _strokes.add(_activeStroke!);
    _activeStroke = null;
    _saveBoard();
  }

  Future<void> _promptAddText() async {
    final ctl = TextEditingController();
    Color chosen = _penColor;
    final picked = await _pickColor(context, initial: chosen);
    if (picked != null) chosen = picked;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add text'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Your text'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final txt = ctl.text.trim();
              if (txt.isNotEmpty) {
                final safePos = _clampPosForBox(
                  pos: const Offset(0, 0),
                  baseSize: const Size(160, 48),
                  scaleX: 1.2,
                  scaleY: 1.2,
                );
                _texts.add(BoardText(
                  id: 'txt_${DateTime.now().microsecondsSinceEpoch}',
                  text: txt,
                  color: chosen.value,
                  pos: safePos,
                  scale: 1.2,
                  rotation: 0,
                ));
                setState(() {});
                _saveBoard();
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D7C66),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeShape() async {
    if (_selectedImage == null) return;
    final current = _images[_selectedImage!].shape;
    final next = {
      BoardShape.square: BoardShape.rounded,
      BoardShape.rounded: BoardShape.circle,
      BoardShape.circle: BoardShape.square,
    }[current]!;
    setState(() => _images[_selectedImage!].shape = next);
    _saveBoard();
  }

  Future<void> _deleteSelected() async {
    if (_selectedImage != null) {
      setState(() {
        _images.removeAt(_selectedImage!);
        _selectedImage = null;
      });
      _saveBoard();
    } else if (_selectedText != null) {
      setState(() {
        _texts.removeAt(_selectedText!);
        _selectedText = null;
      });
      _saveBoard();
    }
  }

  Future<void> _pickPenWidth() async {
    double temp = _penWidth;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stroke width'),
        content: StatefulBuilder(
          builder: (context, setSB) => Slider(
            value: temp,
            min: 1,
            max: 20,
            onChanged: (v) => setSB(() => temp = v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { setState(() => _penWidth = temp); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D7C66),
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply'),
          )
        ],
      ),
    );
  }

  Future<void> _confirmStartOver() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start over?'),
        content: const Text(
          'This will clear all photos, text, and drawings from your board. '
          'Your images in storage will remain. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D7C66),
              foregroundColor: Colors.white),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _images.clear();
        _texts.clear();
        _strokes.clear();
        _selectedImage = null;
        _selectedText = null;
      });
      await _saveBoard();
    }
  }

  void _clearSelection() => setState(() {
        _selectedImage = null;
        _selectedText = null;
      });

  Offset _visibleCenter(Size canvas, BuildContext context) {
    final mq = MediaQuery.of(context);
    final topInset = mq.padding.top + kToolbarHeight;
    final usableH = max(0.0, canvas.height - topInset);
    return Offset(canvas.width / 2, topInset + usableH / 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Vision Board',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: .2),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: 'Start over',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _confirmStartOver,
          ),
          IconButton(
            tooltip: 'Add Photos',
            icon: const Icon(Icons.add_rounded),
            onPressed: _addPhotos,
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, cons) {
            final canvas = Size(cons.maxWidth, cons.maxHeight);
            final center = _visibleCenter(canvas, context);

            if (_loading) return const Center(child: CircularProgressIndicator());

            return Stack(
              children: [
                // background hit detector
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _clearSelection,
                    onPanStart: (d) => _onPanStart(d, canvas),
                    onPanUpdate: (d) => _onPanUpdate(d, canvas),
                    onPanEnd: (_) => _onPanEnd(canvas),
                    child: const SizedBox.shrink(),
                  ),
                ),

                // IMAGES
                ...List.generate(_images.length, (i) {
                  final it = _images[i];
                  final clampedPos = _clampPosForBox(
                    pos: it.pos,
                    baseSize: Size(it.baseW, it.baseH),
                    scaleX: it.scaleX,
                    scaleY: it.scaleY,
                  );
                  if (clampedPos != it.pos) it.pos = clampedPos;

                  return _Transformable(
                    key: ValueKey('img_$i'),
                    canvasCenter: center,
                    pos: it.pos,
                    scaleX: it.scaleX,
                    scaleY: it.scaleY,
                    rotation: it.rotation,
                    baseSize: Size(it.baseW, it.baseH),
                    selected: _selectedImage == i,
                    onTap: () {
                      setState(() {
                        _selectedImage = i;
                        _selectedText = null;
                      });
                    },
                    onStart: (focal) {
                      _selectedImage = i;
                      _selectedText = null;
                      _startTransform(focal, isImage: true);
                    },
                    onUpdate: (d) => _updateTransform(d, isImage: true),
                    onEnd: _finishTransform,
                    onCornerStart: () {
                      _startScaleX = it.scaleX;
                      _startScaleY = it.scaleY;
                    },
                    onCornerDragLocal: (sign, deltaLocal) {
                      // current size in *screen* pixels
                      final w = it.baseW * it.scaleX;
                      final h = it.baseH * it.scaleY;

                      // Since handles are inverse-transformed, deltaLocal is in the unrotated,
                      // unscaled box space -> operate directly on w/h.
                      final dw = sign.dx * deltaLocal.dx;
                      final dh = sign.dy * deltaLocal.dy;

                      const minW = 40.0, minH = 40.0;
                      final newW = max(minW, w + dw);
                      final newH = max(minH, h + dh);

                      // keep opposite corner fixed -> move center by half the delta
                      final shiftLocal = Offset(
                        sign.dx * (newW - w) / 2,
                        sign.dy * (newH - h) / 2,
                      );

                      // convert that local shift to screen using rotation only
                      final a = it.rotation;
                      final shiftScreen = Offset(
                        shiftLocal.dx * cos(a) - shiftLocal.dy * sin(a),
                        shiftLocal.dx * sin(a) + shiftLocal.dy * cos(a),
                      );

                      it.scaleX = (newW / it.baseW).clamp(.15, 8.0);
                      it.scaleY = (newH / it.baseH).clamp(.15, 8.0);

                      it.pos = _clampPosForBox(
                        pos: it.pos + shiftScreen,
                        baseSize: Size(it.baseW, it.baseH),
                        scaleX: it.scaleX,
                        scaleY: it.scaleY,
                      );
                      setState(() {});
                    },
                    onCornerEnd: _saveBoard,
                    child: _ImageShape(it: it),
                  );
                }),

                // TEXTS
                ...List.generate(_texts.length, (i) {
                  final t = _texts[i];
                  const base = Size(160, 48);
                  final clampedPos = _clampPosForBox(
                    pos: t.pos,
                    baseSize: base,
                    scaleX: t.scale,
                    scaleY: t.scale,
                  );
                  if (clampedPos != t.pos) t.pos = clampedPos;

                  return _TransformableText(
                    key: ValueKey('txt_$i'),
                    canvasCenter: center,
                    pos: t.pos,
                    scale: t.scale,
                    rotation: t.rotation,
                    baseSize: base,
                    selected: _selectedText == i,
                    onTap: () {
                      setState(() {
                        _selectedText = i;
                        _selectedImage = null;
                      });
                    },
                    onStart: (focal) {
                      _selectedText = i;
                      _selectedImage = null;
                      _startTransform(focal, isImage: false);
                    },
                    onUpdate: (d) => _updateTransform(d, isImage: false),
                    onEnd: _finishTransform,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.85),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        border: Border.all(
                          color: (_selectedText == i)
                              ? const Color(0xFF0D7C66)
                              : Colors.transparent,
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        t.text,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(t.color),
                        ),
                      ),
                    ),
                  );
                }),

                if (_images.isEmpty && !_loading)
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton.icon(
                      onPressed: _addPhotos,
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Add Photos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7C66),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        elevation: 3,
                      ),
                    ),
                  ),

                // Bottom toolbar
                SafeArea(
                  top: false,
                  bottom: true,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            _ModeIcon(
                              tooltip: 'Move',
                              selected: _mode == EditMode.move,
                              icon: Icons.open_with_rounded,
                              onTap: () => setState(() => _mode = EditMode.move),
                            ),
                            const SizedBox(width: 8),
                            _ModeIcon(
                              tooltip: 'Draw',
                              selected: _mode == EditMode.draw,
                              icon: Icons.brush_rounded,
                              onTap: () => setState(() => _mode = EditMode.draw),
                            ),
                            const SizedBox(width: 8),
                            _ModeIcon(
                              tooltip: 'Text',
                              selected: _mode == EditMode.text,
                              icon: Icons.text_fields_rounded,
                              onTap: _promptAddText,
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: 'Change shape',
                              onPressed: _selectedImage != null ? _changeShape : null,
                              icon: const Icon(Icons.change_circle_rounded),
                            ),
                            IconButton(
                              tooltip: 'Delete selected',
                              onPressed: (_selectedImage != null || _selectedText != null)
                                  ? _deleteSelected
                                  : null,
                              icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                            ),
                            IconButton(
                              tooltip: 'Pick color',
                              onPressed: () async {
                                final c = await _pickColor(context, initial: _penColor);
                                if (c != null) setState(() => _penColor = c);
                              },
                              icon: CircleAvatar(radius: 14, backgroundColor: _penColor),
                            ),
                            IconButton(
                              tooltip: 'Stroke width',
                              onPressed: _pickPenWidth,
                              icon: const Icon(Icons.line_weight_rounded),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// ======== TRANSFORMABLE WITH IN-IMAGE CORNER HANDLES ========
class _Transformable extends StatelessWidget {
  final Offset canvasCenter;

  final Offset pos;          // center (canvas coords)
  final double scaleX;
  final double scaleY;
  final double rotation;
  final Size baseSize;
  final Widget child;

  final bool selected;
  final VoidCallback? onTap;
  final void Function(Offset focal) onStart;
  final void Function(ScaleUpdateDetails d) onUpdate;
  final VoidCallback onEnd;

  final VoidCallback? onCornerStart;
  final void Function(Offset sign, Offset deltaLocal)? onCornerDragLocal;
  final VoidCallback? onCornerEnd;

  const _Transformable({
    super.key,
    required this.canvasCenter,
    required this.pos,
    required this.scaleX,
    required this.scaleY,
    required this.rotation,
    required this.baseSize,
    required this.child,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    this.selected = false,
    this.onTap,
    this.onCornerStart,
    this.onCornerDragLocal,
    this.onCornerEnd,
  });

  @override
  Widget build(BuildContext context) {
    final w = baseSize.width;
    final h = baseSize.height;
    final worldCenter = canvasCenter + pos;

    return Positioned.fill(
      child: Transform(
        transform: Matrix4.identity()
          ..translate(worldCenter.dx, worldCenter.dy)
          ..rotateZ(rotation)
          ..scale(scaleX, scaleY),
        origin: Offset.zero,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // content & move/rotate/scale gesture
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                onScaleStart: (d) => onStart(d.focalPoint),
                onScaleUpdate: onUpdate,
                onScaleEnd: (_) => onEnd(),
                child: Stack(
                  children: [
                    SizedBox(width: w, height: h, child: child),
                    if (selected)
                      IgnorePointer(
                        ignoring: true,
                        child: CustomPaint(
                          size: Size(w, h),
                          painter: _SelectionOverlayPainter(
                            borderColor: const Color(0xFF7E57C2),
                            gridColor: const Color(0xFF7E57C2).withOpacity(.35),
                            scaleX: scaleX,
                            scaleY: scaleY,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // CORNER HANDLES (inside image, inverse-transformed)
              if (selected) ..._cornerHandles(w, h),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _cornerHandles(double w, double h) {
    const double s = 16;

    Widget corner({
      required Alignment alignment,
      required Offset sign,
    }) {
      return Align(
        alignment: alignment,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(-rotation) // cancel rotation
            ..scale(1 / max(scaleX, 1e-6), 1 / max(scaleY, 1e-6)), // cancel scale
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => onCornerStart?.call(),
            onPanUpdate: (d) => onCornerDragLocal?.call(sign, d.delta),
            onPanEnd: (_) => onCornerEnd?.call(),
            child: Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFF7E57C2), width: 2),
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
              ),
            ),
          ),
        ),
      );
    }

    return [
      corner(alignment: Alignment.topLeft,     sign: const Offset(-1, -1)),
      corner(alignment: Alignment.topRight,    sign: const Offset( 1, -1)),
      corner(alignment: Alignment.bottomRight, sign: const Offset( 1,  1)),
      corner(alignment: Alignment.bottomLeft,  sign: const Offset(-1,  1)),
    ];
  }
}

/// Text transformable (no resize handles)
class _TransformableText extends StatelessWidget {
  final Offset canvasCenter;

  final Offset pos;
  final double scale;
  final double rotation;
  final Size baseSize;
  final Widget child;

  final bool selected;
  final VoidCallback? onTap;
  final void Function(Offset focal) onStart;
  final void Function(ScaleUpdateDetails d) onUpdate;
  final VoidCallback onEnd;

  const _TransformableText({
    super.key,
    required this.canvasCenter,
    required this.pos,
    required this.scale,
    required this.rotation,
    required this.baseSize,
    required this.child,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = baseSize.width;
    final h = baseSize.height;
    final worldCenter = canvasCenter + pos;

    return Positioned.fill(
      child: Transform(
        transform: Matrix4.identity()
          ..translate(worldCenter.dx, worldCenter.dy)
          ..rotateZ(rotation)
          ..scale(scale),
        origin: Offset.zero,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onScaleStart: (d) => onStart(d.focalPoint),
            onScaleUpdate: onUpdate,
            onScaleEnd: (_) => onEnd(),
            child: SizedBox(width: w, height: h, child: child),
          ),
        ),
      ),
    );
  }
}

class _SelectionOverlayPainter extends CustomPainter {
  final Color borderColor;
  final Color gridColor;
  final double scaleX;
  final double scaleY;

  const _SelectionOverlayPainter({
    required this.borderColor,
    required this.gridColor,
    required this.scaleX,
    required this.scaleY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final k = (scaleX + scaleY) / 2;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / max(k, 0.0001)
      ..color = borderColor;

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / max(k, 0.0001)
      ..color = gridColor;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, border);

    final dx = size.width / 3;
    final dy = size.height / 3;
    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(Offset(dx * i, 0), Offset(dx * i, size.height), grid);
      canvas.drawLine(Offset(0, dy * i), Offset(size.width, dy * i), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionOverlayPainter old) =>
      old.borderColor != borderColor ||
      old.gridColor != gridColor ||
      old.scaleX != scaleX ||
      old.scaleY != scaleY;
}

class _ImageShape extends StatelessWidget {
  final BoardImage it;
  const _ImageShape({required this.it});

  @override
  Widget build(BuildContext context) {
    final radius = it.shape == BoardShape.rounded ? 18.0 : 0.0;

    Widget content;
    if (it.isLocal && it.localPath != null) {
      content = Image.file(File(it.localPath!), fit: BoxFit.cover);
    } else if (it.url != null && it.url!.isNotEmpty) {
      content = Image.network(
        it.url!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (context, error, stack) {
          return const Center(child: Icon(Icons.broken_image_outlined));
        },
      );
    } else {
      content = const Center(child: Icon(Icons.image_outlined));
    }

    if (it.shape == BoardShape.circle) {
      content = ClipOval(child: content);
      return Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.85),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }
  }
}

class _ModeIcon extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ModeIcon({
    required this.selected,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF0D7C66) : Colors.black87;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

Future<Color?> _pickColor(BuildContext context, {required Color initial}) async {
  final swatches = <Color>[
    Colors.black, Colors.white,
    const Color(0xFF0D7C66), const Color(0xFF41B3A2), const Color(0xFF3E8F84),
    const Color(0xFFD7C3F1), const Color(0xFFBDA9DB), const Color(0xFF99BBFF),
    Colors.red, Colors.pink, Colors.deepOrange, Colors.orange, Colors.amber,
    Colors.yellow, Colors.lime, Colors.lightGreen, Colors.green, Colors.teal,
    Colors.cyan, Colors.lightBlue, Colors.blue, Colors.indigo, Colors.purple,
    Colors.deepPurple, Colors.brown, Colors.grey, Colors.blueGrey,
  ];

  Color selected = initial;

  return showDialog<Color>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Pick a color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 36,
            decoration: BoxDecoration(
              color: selected,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black26),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 320,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in swatches)
                  _ColorDot(
                    color: c,
                    initiallySelected: selected.value == c.value,
                    onChoose: () => selected = c,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, selected),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D7C66),
            foregroundColor: Colors.white,
          ),
          child: const Text('Use color'),
        ),
      ],
    ),
  );
}

class _ColorDot extends StatefulWidget {
  final Color color;
  final bool initiallySelected;
  final VoidCallback onChoose;
  const _ColorDot({
    required this.color,
    required this.initiallySelected,
    required this.onChoose,
  });
  @override
  State<_ColorDot> createState() => _ColorDotState();
}

class _ColorDotState extends State<_ColorDot> {
  late bool _sel = widget.initiallySelected;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        widget.onChoose();
        setState(() => _sel = true);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          border: Border.all(color: _sel ? Colors.black : Colors.black26),
        ),
      ),
    );
  }
}
