// lib/pages/onboarding.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keep stages in this order. We persist by enum index, so if you insert new
/// stages in the future, add a migration in [getStage].
enum OnboardingStage {
  notStarted,        // 0
  homeIntro,         // 1: show “add habit”, chart, tabs
  needFirstHabit,    // 2: block until a habit is created
  needFirstCommunity,// 3: block until first community post
  needFirstJournal,  // 4: block until a private journal entry is added
  journalIntro,
  settingsSearch,    // 5: spotlight the Settings search field
  done,              // 6
  replayingTutorial, // 7: explicit replay path
}

class Onboarding {
  static const _kStage = 'onboarding_stage';

  /// Reads current stage with migration from older builds (without `settingsSearch`).
  ///
  /// Old order (no `settingsSearch`):
  ///  0 notStarted, 1 homeIntro, 2 needFirstHabit, 3 needFirstCommunity,
  ///  4 needFirstJournal, 5 done, 6 replayingTutorial
  ///
  /// New order inserts `settingsSearch` at index 5 and shifts the rest:
  ///  done -> 6, replayingTutorial -> 7.
  static Future<OnboardingStage> getStage() async {
    final p = await SharedPreferences.getInstance();
    int i = p.getInt(_kStage) ?? 0;

    // --- migration for users saved before `settingsSearch` existed ---
    if (i == 5) i = 6; // old 'done' -> new 'done'
    if (i == 6) i = 7; // old 'replayingTutorial' -> new 'replayingTutorial'

    // Clamp to a valid value just in case.
    if (i < 0 || i >= OnboardingStage.values.length) i = 0;
    return OnboardingStage.values[i];
  }

  static Future<void> setStage(OnboardingStage s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kStage, s.index);
  }

  /// Force the tutorial replay sequence (Home → Journal → Settings search).
  static Future<void> replayTutorial() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kStage, OnboardingStage.replayingTutorial.index);
  }

  // ---- Milestone helpers you call from app logic ----

  /// After a habit is created on Home.
  static Future<void> markHabitCreated() =>
      setStage(OnboardingStage.needFirstCommunity);

  /// After first public community post is made.
  static Future<void> markCommunityPosted() =>
      setStage(OnboardingStage.needFirstJournal);

  /// After a private journal entry is added -> go spotlight Settings search next.
  static Future<void> markJournalAdded() =>
      setStage(OnboardingStage.settingsSearch);

  /// Call when the Settings search spotlight is completed/dismissed.
  static Future<void> markSettingsSearchShown() =>
      setStage(OnboardingStage.done);

  /// (Optional) convenient dev reset.
  static Future<void> reset() => setStage(OnboardingStage.notStarted);
}
