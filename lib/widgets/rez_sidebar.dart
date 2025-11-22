// lib/widgets/rez_sidebar_host.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_rezonate/main.dart' as app;

/// Colors + theme helpers (same palette you already use)
const _rezTeal = Color(0xFF0D7C66);

bool _isDark(BuildContext context) =>
    app.ThemeControllerScope.of(context).isDark;

/// Wrap any page with this to get the drag-out Rez sidebar + tab.
///
/// Example:
///   return RezSidebarHost(
///     userName: widget.userName,
///     child: YourExistingPageBody(...),
///   );
class RezSidebarHost extends StatefulWidget {
  final Widget child;
  final String userName;

  const RezSidebarHost({
    Key? key,
    required this.child,
    required this.userName,
  }) : super(key: key);

  @override
  State<RezSidebarHost> createState() => _RezSidebarHostState();
}

class _RezSidebarHostState extends State<RezSidebarHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const double _panelWidth = 320;
  static const double _dragWidth = 40; // area you can grab/drag from
  bool _isDragging = false;
  double _dragStartX = 0;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: 0, // 0 = closed, 1 = open
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isOpen => _controller.value > 0.5;

  void _open() {
    _controller.fling(velocity: 1.0);
  }

  void _close() {
    _controller.fling(velocity: -1.0);
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragStartX = details.globalPosition.dx;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final delta = details.globalPosition.dx - _dragStartX;
    _dragStartX = details.globalPosition.dx;

    final width = _panelWidth;
    final valueDelta = delta / width;
    final newValue = (_controller.value + valueDelta).clamp(0.0, 1.0);
    _controller.value = newValue;
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    final minFlingVelocity = 400.0;
    if (details.primaryVelocity != null &&
        details.primaryVelocity!.abs() > minFlingVelocity) {
      if (details.primaryVelocity! > 0) {
        _open();
      } else {
        _close();
      }
    } else {
      // snap to closest
      if (_controller.value > 0.5) {
        _open();
      } else {
        _close();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);

    return Stack(
      children: [
        // Your actual page content
        Positioned.fill(child: widget.child),

        // Tap-to-close overlay when sidebar is open
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final opacity = 0.4 * _controller.value;
            return IgnorePointer(
              ignoring: !_isOpen,
              child: Opacity(
                opacity: opacity,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: Container(
                    color: Colors.black,
                  ),
                ),
              ),
            );
          },
        ),

        // Sidebar + drag handle
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final slide = -_panelWidth + _panelWidth * _controller.value;

            return Positioned(
              left: slide,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _handleDragStart,
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                // The drag area is slightly wider than the panel so users
                // can grab from the edge even when closed.
                child: SizedBox(
                  width: _panelWidth + _dragWidth,
                  height: MediaQuery.of(context).size.height,
                  child: Stack(
                    children: [
                      // Sidebar panel (white, semi-transparent)
                      Positioned(
                        left: _dragWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: _panelWidth,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                                dark ? 0.10 : 0.94), // semi-transparent white
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(26),
                              bottomRight: Radius.circular(26),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 16,
                                offset: Offset(4, 0),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                              child: _SidebarContent(
                                user: _user,
                                userName: widget.userName,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Small semi-transparent vertical tab (the line)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggle,
                          child: Container(
                            width: 5,
                            height: 70,
                            margin: const EdgeInsets.only(left: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Inner content of the sidebar: profile + Rez balance + recent activity.
/// This assumes:
///   users/{uid} doc has:
///     - 'username'
///     - 'photoUrl'
///     - 'rez_balance' : int
/// and an optional subcollection:
///   users/{uid}/rez_activity with docs:
///     - 'label' : String
///     - 'delta' : int  (positive or negative Rez change)
///     - 'createdAt' : Timestamp
class _SidebarContent extends StatelessWidget {
  final User? user;
  final String userName;

  const _SidebarContent({
    Key? key,
    required this.user,
    required this.userName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Center(
        child: Text(
          'Sign in to view your Rez.',
          style: TextStyle(
            color: _isDark(context) ? Colors.white : Colors.black87,
          ),
        ),
      );
    }

    final uid = user!.uid;
    final usersCol = FirebaseFirestore.instance.collection('users');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: usersCol.doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final name = (data['username'] as String?)?.trim();
        final photoUrl = (data['photoUrl'] as String?)?.trim();
        final rezBalance = (data['rez_balance'] as num?)?.toInt() ?? 0;

        final displayName =
            name != null && name.isNotEmpty ? name : userName;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: close icon (optional) & settings gear slot if you want later
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                // You can plug a close button here later if desired
              ],
            ),

            // Profile row
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFD7CFFC),
                  backgroundImage:
                      (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? const Icon(Icons.person, color: Colors.black54)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: _isDark(context)
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Premium or regular plan - ADD LATER',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Rez balance
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.diamond_outlined,
                    size: 24, color: _rezTeal),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$rezBalance Rez',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _isDark(context)
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    Text(
                      'Current balance',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 22),

            Text(
              'Recent activity',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: _isDark(context) ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _RezActivityList(uid: uid),
            ),
          ],
        );
      },
    );
  }
}

class _RezActivityList extends StatelessWidget {
  final String uid;

  const _RezActivityList({Key? key, required this.uid}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('rez_activity')
        .orderBy('createdAt', descending: true)
        .limit(10);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: col.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 1.5));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'No Rez activity yet.',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      _isDark(context) ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(top: 4),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final m = docs[index].data();
            final label = (m['label'] as String?) ?? 'Activity';
            final delta = (m['delta'] as num?)?.toInt() ?? 0;
            final ts =
                (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

            final isPositive = delta >= 0;
            final deltaText =
                '${isPositive ? '+' : ''}$delta'; // e.g. +3, -2
            final deltaColor = isPositive ? _rezTeal : Colors.redAccent;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  size: 18,
                  color: _isDark(context)
                      ? Colors.white70
                      : Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _isDark(context)
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d • h:mm a').format(ts),
                        style: TextStyle(
                          fontSize: 11,
                          color: _isDark(context)
                              ? Colors.white60
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.diamond_outlined,
                      size: 16,
                      color: _rezTeal,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      deltaText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: deltaColor,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
