// onboarding.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The single source of truth for the tour step (persisted).
/// Replay is handled via an in-memory flag (ephemeral).
enum OnboardingStage {
  notStarted,
  homeIntro,
  needFirstHabit,
  needFirstCommunity,
  needFirstJournal,
  settingsSearch,
  done,

  /// NOTE: We do NOT persist this to Firestore. We expose it to pages
  /// via getStage() when replay is active (ephemeral).
  replayingTutorial,
}

class Onboarding {
  // ---- Keys (bumped) ---------------------------------------------------------
  static const _kStage = 'onboarding_stage_v3'; // bump to avoid old cache bleed

  // ---- Services --------------------------------------------------------------
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  // ---- In-memory cache (fast & safe) ----------------------------------------
  static OnboardingStage? _memStage;
  static bool _replayActive = false;
  static OnboardingStage? _replayPrevStage; // to restore if replay aborted

  // ---- Public API ------------------------------------------------------------

  /// Call once right after a successful sign-in.
  /// Creates user doc if needed and initializes the stage.
  static Future<void> ensureStageForCurrentUser() async {
    final u = _auth.currentUser;
    if (u == null) {
      _memStage = OnboardingStage.notStarted;
      return;
    }

    final userRef = _db.collection('users').doc(u.uid);
    final snap = await userRef.get();

    if (!snap.exists) {
      await userRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'onboardingStage': OnboardingStage.homeIntro.name,
        'onboardingDone': false,
      }, SetOptions(merge: true));
      await _cacheStage(OnboardingStage.homeIntro);
      return;
    }

    // Respect explicit done.
    final data = snap.data() ?? {};
    final done = data['onboardingDone'] == true;
    final stageStr = (data['onboardingStage'] as String?) ?? '';
    if (done || stageStr == OnboardingStage.done.name) {
      await _cacheStage(OnboardingStage.done);
      return;
    }

    // Auto-detect existing users (already have content) → mark done.
    final uid = u.uid;
    final hasTrackers = (await userRef.collection('trackers').limit(1).get()).docs.isNotEmpty;
    final hasPrivate = (await userRef.collection('private_posts').limit(1).get()).docs.isNotEmpty;
    final hasPublic = (await _db.collection('public_posts').where('uid', isEqualTo: uid).limit(1).get()).docs.isNotEmpty;

    if (hasTrackers || hasPrivate || hasPublic) {
      await userRef.set({
        'onboardingStage': OnboardingStage.done.name,
        'onboardingDone': true,
      }, SetOptions(merge: true));
      await _cacheStage(OnboardingStage.done);
      return;
    }

    // New user → initialize to homeIntro (or keep current stage if valid).
    final stage = _fromName(stageStr) ?? OnboardingStage.homeIntro;
    if (stage == OnboardingStage.notStarted) {
      await userRef.set({'onboardingStage': OnboardingStage.homeIntro.name}, SetOptions(merge: true));
      await _cacheStage(OnboardingStage.homeIntro);
    } else {
      await _cacheStage(stage);
    }
  }

  /// Returns the effective stage:
  /// - If replay is active, returns `replayingTutorial` (ephemeral).
  /// - Otherwise, returns persisted stage (server → cache → default).
  static Future<OnboardingStage> getStage() async {
    if (_replayActive) return OnboardingStage.replayingTutorial;

    final u = _auth.currentUser;
    if (u == null) return _memStage ?? OnboardingStage.notStarted;

    final ref = _db.collection('users').doc(u.uid);
    try {
      final snap = await ref.get();
      final name = (snap.data()?['onboardingStage'] as String?) ?? '';
      final s = _fromName(name) ?? _memStage ?? OnboardingStage.notStarted;
      await _cacheStage(s);
      return s;
    } catch (_) {
      return _memStage ?? OnboardingStage.notStarted;
    }
  }

  /// Sets and persists the stage (idempotent).
  /// No-ops while replay is active (we never mutate server state during replay).
  static Future<void> setStage(OnboardingStage s) async {
    if (_replayActive) return; // gated flow suspended during replay

    // Avoid extra writes if nothing changed.
    if (_memStage == s) {
      // still mirror to prefs in case previous boot missed it
      await _cacheStage(s);
      return;
    }

    final u = _auth.currentUser;
    if (u != null) {
      await _db.collection('users').doc(u.uid).set(
        {'onboardingStage': s.name},
        SetOptions(merge: true),
      );
    }
    await _cacheStage(s);
  }

  /// Marks onboarding complete (persists) and clears any replay state.
  static Future<void> markDone() async {
    _replayActive = false;
    _replayPrevStage = null;

    final u = _auth.currentUser;
    if (u != null) {
      await _db.collection('users').doc(u.uid).set(
        {
          'onboardingStage': OnboardingStage.done.name,
          'onboardingDone': true,
        },
        SetOptions(merge: true),
      );
    }
    await _cacheStage(OnboardingStage.done);
  }

  // ---- Replay mode (ephemeral, in-memory) -----------------------------------

  /// Start the fast, hands-off replay. This does NOT touch Firestore.
  /// We stash the current persisted stage so we can restore if needed.
  static Future<void> startReplay() async {
    if (_replayActive) return;
    _replayPrevStage = await getStage(); // reads effective; may be replay if already active
    if (_replayPrevStage == OnboardingStage.replayingTutorial) {
      // If somehow already in replay, keep previous cached stage as-is.
      _replayPrevStage = _memStage;
    }
    _replayActive = true;
  }

  /// Finish replay successfully (the replay flow ends in Settings).
  /// By design we mark onboarding as done.
  static Future<void> completeReplay() async {
    _replayActive = false;
    _replayPrevStage = null;
    await markDone();
  }

  /// Abort replay (e.g., user backs out). Restores prior persisted stage.
  static Future<void> cancelReplayAndRestore() async {
    final prev = _replayPrevStage;
    _replayActive = false;
    _replayPrevStage = null;
    if (prev != null && prev != OnboardingStage.replayingTutorial) {
      await setStage(prev);
    }
  }

  /// Utility for pages to branch quickly.
  static bool get isReplayActive => _replayActive;

  // ---- Convenience gates used by pages (no-ops during replay) ----------------

  /// Home: 0 → 1 trackers
  static Future<void> markHabitCreated() async {
    if (_replayActive) return;
    await setStage(OnboardingStage.needFirstCommunity);
  }

  /// Journal (community): first intro post
  static Future<void> markCommunityPosted() async {
    if (_replayActive) return;
    await setStage(OnboardingStage.needFirstJournal);
  }

  /// Journal (private): first private entry saved
  static Future<void> markJournalAdded() async {
    if (_replayActive) return;
    await setStage(OnboardingStage.settingsSearch);
  }

  // ---- Internals: caching helpers -------------------------------------------
  static Future<void> _cacheStage(OnboardingStage s) async {
    _memStage = s;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kStage, s.index);
  }

  /// Optional: load from prefs on cold start if server is unreachable.
  static Future<void> loadCacheIfEmpty() async {
    if (_memStage != null) return;
    final p = await SharedPreferences.getInstance();
    final idx = p.getInt(_kStage);
    if (idx != null && idx >= 0 && idx < OnboardingStage.values.length) {
      _memStage = OnboardingStage.values[idx];
    }
  }

  static OnboardingStage? _fromName(String? name) {
    if (name == null) return null;
    for (final s in OnboardingStage.values) {
      if (s.name == name) return s;
    }
    return null;
  }
}
