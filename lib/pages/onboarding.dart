import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OnboardingStage {
  notStarted,
  homeIntro,          // show “add habit”, chart, tabs
  needFirstHabit,     // block till created
  needFirstCommunity, // block till post made
  needFirstJournal,   // block till entry saved
  done,
  replayingTutorial, // 


}

class Onboarding {
  static const _kStage = 'onboarding_stage';

  static Future<OnboardingStage> getStage() async {
    final p = await SharedPreferences.getInstance();
    final i = p.getInt(_kStage) ?? 0;
    return OnboardingStage.values[i];
  }

  static Future<void> setStage(OnboardingStage s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kStage, s.index);
  }

  static Future<void> replayTutorial() async {
  final p = await SharedPreferences.getInstance();
  await p.setInt(_kStage, OnboardingStage.replayingTutorial.index);
}


  // helpers you’ll call from app logic after actions complete
  static Future<void> markHabitCreated() => setStage(OnboardingStage.needFirstCommunity);
  static Future<void> markCommunityPosted() => setStage(OnboardingStage.needFirstJournal);
  static Future<void> markJournalAdded() => setStage(OnboardingStage.done);
}
