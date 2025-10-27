import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import 'onboarding_keys.dart';

enum OnboardingStage {
  notStarted,
  homeIntro,
  needFirstHabit,
  needFirstCommunity,
  needFirstJournal,
  settingsSearch,
  done,

  /// Ephemeral (not persisted) – used while replaying the tutorial
  replayingTutorial,
}

class Onboarding {
  static const _kStage = 'onboarding_stage_v3';

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static OnboardingStage? _memStage;
  static bool _replayActive = false;
  static OnboardingStage? _replayPrevStage;

  /// Used to tell if the user just signed up (for special onboarding UI)
  static bool isFreshSignup = false;

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

    final data = snap.data() ?? {};
    final done = data['onboardingDone'] == true;
    final stageStr = (data['onboardingStage'] as String?) ?? '';

    if (done || stageStr == OnboardingStage.done.name) {
      await _cacheStage(OnboardingStage.done);
      return;
    }

    final uid = u.uid;
    final hasTrackers =
        (await userRef.collection('trackers').limit(1).get()).docs.isNotEmpty;
    final hasPrivate =
        (await userRef.collection('private_posts').limit(1).get()).docs.isNotEmpty;
    final hasPublic = (await _db
            .collection('public_posts')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get())
        .docs
        .isNotEmpty;

    if (hasTrackers || hasPrivate || hasPublic) {
      await userRef.set({
        'onboardingStage': OnboardingStage.done.name,
        'onboardingDone': true,
      }, SetOptions(merge: true));
      await _cacheStage(OnboardingStage.done);
      return;
    }

    final stage = _fromName(stageStr) ?? OnboardingStage.homeIntro;
    if (stage == OnboardingStage.notStarted) {
      await userRef.set({
        'onboardingStage': OnboardingStage.homeIntro.name,
      }, SetOptions(merge: true));
      await _cacheStage(OnboardingStage.homeIntro);
    } else {
      await _cacheStage(stage);
    }
  }

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

  static Future<void> setStage(OnboardingStage s) async {
    if (_replayActive) return;

    if (_memStage == s) {
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

  static Future<void> startReplay() async {
    if (_replayActive) return;
    _replayPrevStage = await getStage();
    if (_replayPrevStage == OnboardingStage.replayingTutorial) {
      _replayPrevStage = _memStage;
    }
    _replayActive = true;
  }

  static Future<void> completeReplay() async {
    _replayActive = false;
    _replayPrevStage = null;
    await markDone();
  }

  static Future<void> cancelReplayAndRestore() async {
    final prev = _replayPrevStage;
    _replayActive = false;
    _replayPrevStage = null;
    if (prev != null && prev != OnboardingStage.replayingTutorial) {
      await setStage(prev);
    }
  }

  static bool get isReplayActive => _replayActive;

  static Future<void> markHabitCreated() async {
    if (_replayActive) return;
    await setStage(OnboardingStage.needFirstCommunity);
  }

  static Future<void> markCommunityPosted() async {
    if (_replayActive) return;
    await setStage(OnboardingStage.needFirstJournal);
  }

  static Future<void> markJournalAdded() async {
    if (_replayActive) return;
    await setStage(OnboardingStage.settingsSearch);
  }

  static Future<void> _cacheStage(OnboardingStage s) async {
    _memStage = s;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kStage, s.index);
  }

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

class OBShowcase {
  static Future<void> startWhenReady(
    BuildContext ctx, {
    required List<GlobalKey> keys,
    Duration maxWait = const Duration(seconds: 2),
  }) async {
    await Future<void>.delayed(Duration.zero);
    final show = ShowCaseWidget.of(ctx);

    final deadline = DateTime.now().add(maxWait);
    while (DateTime.now().isBefore(deadline)) {
      final ready = keys.every((k) => k.currentContext != null);
      if (ready) break;
      await Future.delayed(const Duration(milliseconds: 60));
    }

    try {
      if (show.mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            show.startShowCase(keys);
          } catch (_) {}
        });
      }
    } catch (_) {}
  }
}

extension OnboardingGuards on OnboardingStage {
  bool get runsOnHome =>
      this == OnboardingStage.homeIntro ||
      this == OnboardingStage.needFirstHabit ||
      this == OnboardingStage.replayingTutorial;

  bool get runsOnJournalCommunity =>
      this == OnboardingStage.needFirstCommunity ||
      this == OnboardingStage.replayingTutorial;

  bool get runsOnJournalPrivate =>
      this == OnboardingStage.needFirstJournal ||
      this == OnboardingStage.replayingTutorial;

  bool get runsOnSettings =>
      this == OnboardingStage.settingsSearch ||
      this == OnboardingStage.replayingTutorial;
}
