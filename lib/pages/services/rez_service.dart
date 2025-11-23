import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// A single Rez currency transaction.
class RezTransaction {
  final int delta; // positive or negative
  final String label;
  final String source; // e.g. 'home', 'sleep', 'habit', 'game'
  final DateTime createdAt;

  RezTransaction({
    required this.delta,
    required this.label,
    required this.source,
    required this.createdAt,
  });

  factory RezTransaction.fromMap(Map<String, dynamic> map) {
    final rawTs = map['createdAt'];
    DateTime ts;
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is DateTime) {
      ts = rawTs;
    } else if (rawTs is String) {
      ts = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }

    return RezTransaction(
      delta: (map['delta'] as num?)?.toInt() ?? 0,
      label: (map['label'] ?? '') as String,
      source: (map['source'] ?? 'unknown') as String,
      createdAt: ts,
    );
  }

  Map<String, dynamic> toMap() => {
        'delta': delta,
        'label': label,
        'source': source,
        'createdAt': createdAt,
      };
}

/// Singleton service that keeps Rez balance + history in Firestore
/// and exposes streams that all pages can use.
class RezService {
  RezService._();
  static final RezService instance = RezService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>>? _userDocOrNull() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _db.collection('users').doc(user.uid);
  }

  /// Live Rez balance for the current user.
  Stream<int> balanceStream() {
    final docRef = _userDocOrNull();
    if (docRef == null) return const Stream<int>.empty();

    return docRef.snapshots().map((snap) {
      final data = snap.data();
      return (data?['rez_balance'] as num?)?.toInt() ?? 0;
    });
  }

  /// Live recent Rez transactions for the current user.
  Stream<List<RezTransaction>> recentTransactionsStream() {
    final docRef = _userDocOrNull();
    if (docRef == null) return const Stream<List<RezTransaction>>.empty();

    return docRef.snapshots().map((snap) {
      final data = snap.data();
      final raw = data?['rez_history'];

      if (raw is List) {
        final list = raw
            .whereType<Map>()
            .map((e) => RezTransaction.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
      return <RezTransaction>[];
    });
  }

  /// Generic helper to apply a Rez delta and push a transaction into history.
  Future<void> addDelta({
    required int delta,
    required String label,
    required String source,
  }) async {
    final docRef = _userDocOrNull();
    if (docRef == null || delta == 0) return;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? {};

      final currentBalance = (data['rez_balance'] as num?)?.toInt() ?? 0;
      final newBalance = currentBalance + delta;

      List history = (data['rez_history'] as List?) ?? [];
      final txMap = <String, dynamic>{
        'delta': delta,
        'label': label,
        'source': source,
        'createdAt': FieldValue.serverTimestamp(),
      };
      history.insert(0, txMap);
      if (history.length > 40) {
        history = history.sublist(0, 40);
      }

      tx.set(
        docRef,
        {
          'rez_balance': newBalance,
          'rez_history': history,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Home tracking rule:
  /// - +3 Rez the first day you ever log on the Home page.
  /// - Then, at most +3 Rez per calendar day (no matter how many logs).
  /// - For each FULL calendar day you missed in between, -3 Rez.
  ///
  /// Example:
  ///   Day 1 log   -> +3  (balance +3)
  ///   Day 2 log   -> +3  (balance +6)
  ///   Day 3 skip  ->  0  (still +6)
  ///   Day 4 log   -> +3 (today) -3 (missed Day 3) = net 0 (still +6)
  ///
  /// We track the last Home log date in `rez_home_last_day` (yyyy-MM-dd).
  Future<void> homeTrackingCompleted() async {
    final docRef = _userDocOrNull();
    if (docRef == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = DateFormat('yyyy-MM-dd').format(today);

    final snap = await docRef.get();
    final data = snap.data() ?? {};

    final lastStr = data['rez_home_last_day'] as String?;
    DateTime? lastDay;
    if (lastStr != null && lastStr.isNotEmpty) {
      lastDay = DateTime.tryParse(lastStr);
    }

    int delta = 0;
    String label = '';

    if (lastDay == null) {
      // First ever home track: simple +3
      delta = 3;
      label = 'First home tracking day (+3)';
    } else {
      final normalizedLast = DateTime(lastDay.year, lastDay.month, lastDay.day);
      final diff = today.difference(normalizedLast).inDays;

      if (diff <= 0) {
        // Already rewarded today (or weird clock change) – nothing to do.
        return;
      }

      // We logged today -> +3
      final missedDays = diff - 1; // full days with no logging between last and today
      delta = 3 - (missedDays * 3);

      if (delta == 0 && missedDays > 0) {
        // Net 0 change; user effectively "pays" for missed days
        // by not gaining anything today.
        await docRef.set(
          {'rez_home_last_day': todayKey},
          SetOptions(merge: true),
        );
        return;
      }

      if (missedDays <= 0) {
        label = 'Home tracking (+3 for today)';
      } else if (missedDays == 1) {
        label = 'Home tracking: +3 today, -3 for 1 missed day';
      } else {
        label =
            'Home tracking: +3 today, -3 for $missedDays missed days';
      }
    }

    if (delta != 0) {
      await addDelta(
        delta: delta,
        label: label,
        source: 'home',
      );
    }

    // Update last-home-log day regardless of net delta (unless we bailed early).
    await docRef.set(
      {'rez_home_last_day': todayKey},
      SetOptions(merge: true),
    );
  }
}
