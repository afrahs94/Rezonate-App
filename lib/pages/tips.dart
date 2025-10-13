// lib/pages/tips.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:new_rezonate/main.dart' as app;

class TipsPage extends StatefulWidget {
  const TipsPage({super.key});

  @override
  State<TipsPage> createState() => _TipsPageState();
}

class _TipsPageState extends State<TipsPage> with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _showBack = false;
  final _rng = Random();

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

  double _topPadding(BuildContext context) {
    final status = MediaQuery.of(context).padding.top;
    const appBar = kToolbarHeight;
    const extra = 24.0;
    return status + appBar + extra;
  }

  void _next() {
    setState(() {
      _showBack = false;
      _index = (_index + 1) % _tips.length;
    });
  }

  void _prev() {
    setState(() {
      _showBack = false;
      _index = (_index - 1) < 0 ? _tips.length - 1 : _index - 1;
    });
  }

  void _shuffle() {
    setState(() {
      _showBack = false;
      _index = _rng.nextInt(_tips.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _tips[_index];
    const green = Color(0xFF0D7C66);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Tips',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: .2),
        ),
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, _topPadding(context), 16, 24),
            children: [
              // Controls
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black, width: 1),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous',
                      onPressed: _prev,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: _shuffle,
                      style: FilledButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      icon: const Icon(Icons.shuffle_rounded, size: 18),
                      label: const Text('Shuffle'),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Next',
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward_ios_rounded),
                    ),
                    const Spacer(),
                    Text('${_index + 1}/${_tips.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Flashcard
              GestureDetector(
                onTap: () => setState(() => _showBack = !_showBack),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: Tween<double>(begin: .98, end: 1).animate(anim), child: child),
                  child: _showBack
                      ? _BackCard(key: const ValueKey('back'), tip: t)
                      : _FrontCard(key: const ValueKey('front'), tip: t),
                ),
              ),

              const SizedBox(height: 14),

              // Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Text(
                  'These cards are educational only and not medical advice. '
                  'If you’re in crisis, call your local emergency number or a crisis hotline.',
                  style: TextStyle(fontSize: 12.5, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrontCard extends StatelessWidget {
  const _FrontCard({super.key, required this.tip});
  final _Tip tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        children: [
          Text(
            tip.condition,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            tip.short,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          const Icon(Icons.touch_app_rounded, color: Colors.black45),
          const SizedBox(height: 4),
          const Text('Tap to flip', style: TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
    );
  }
}

class _BackCard extends StatelessWidget {
  const _BackCard({super.key, required this.tip});
  final _Tip tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tip.condition, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(tip.details),
          const SizedBox(height: 10),
          const Text('Try:', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...tip.tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(t)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _Tip {
  final String condition;
  final String short;
  final String details;
  final List<String> tips;

  const _Tip({
    required this.condition,
    required this.short,
    required this.details,
    required this.tips,
  });
}

/// ~50 conditions (51 here), concise summaries + practical tips
const List<_Tip> _tips = [
  _Tip(
    condition: 'Major Depressive Disorder',
    short: 'Persistent low mood, loss of interest, changes in sleep/appetite.',
    details:
        'Depression affects mood, energy, and thinking. It’s treatable with therapy, lifestyle changes, and sometimes medication.',
    tips: [
      'Use the 5-minute rule to start a tiny task.',
      'Get sunlight or a light box in the morning.',
      'Text one supportive person today.',
    ],
  ),
  _Tip(
    condition: 'Persistent Depressive Disorder (Dysthymia)',
    short: 'Chronic, lower-grade depression lasting 2+ years.',
    details:
        'Symptoms are milder than MDD but more persistent. Therapy plus routines and activity scheduling can help.',
    tips: [
      'Create a simple daily anchor routine (wake, walk, wash, breakfast).',
      'Track mood vs. sleep and steps to spot patterns.',
    ],
  ),
  _Tip(
    condition: 'Seasonal Affective Disorder (SAD)',
    short: 'Depression pattern tied to seasons (often winter).',
    details:
        'Linked to light changes. Light therapy and behavioral activation are first-line options.',
    tips: [
      'Use a 10,000-lux light box for ~20–30 min after waking (check guidelines).',
      'Plan weekly outdoor daylight walks.',
    ],
  ),
  _Tip(
    condition: 'Postpartum Depression',
    short: 'Depression after childbirth; not a personal failing.',
    details:
        'Hormonal shifts and stress can contribute. Urgent care is warranted for intrusive or self-harm thoughts.',
    tips: [
      'Ask your care team about screening and supports.',
      'Prioritize sleep blocks with partner/family help when possible.',
    ],
  ),
  _Tip(
    condition: 'Premenstrual Dysphoric Disorder (PMDD)',
    short: 'Severe mood symptoms in the luteal phase.',
    details:
        'Symptoms cycle with menstruation. Track cycles; treatments include SSRIs, lifestyle changes, and medical options.',
    tips: [
      'Track symptoms with your cycle; pre-plan coping days.',
      'Reduce caffeine/alcohol late luteal phase.',
    ],
  ),
  _Tip(
    condition: 'Generalized Anxiety Disorder (GAD)',
    short: 'Excessive worry most days for 6+ months.',
    details:
        'Leads to restlessness, muscle tension, and sleep issues. CBT and relaxation skills are effective.',
    tips: [
      'Schedule a daily “worry window” (10–15 min) to contain rumination.',
      'Practice diaphragmatic breathing: 4-sec inhale, 6-sec exhale.',
    ],
  ),
  _Tip(
    condition: 'Panic Disorder',
    short: 'Recurrent unexpected panic attacks, fear of more.',
    details:
        'Interoceptive exposure (safely practicing bodily sensations) helps reduce fear of sensations.',
    tips: [
      'Label it: “This is a panic surge; it will peak and pass.”',
      'Slow, extended exhales; keep shoulders loose.',
    ],
  ),
  _Tip(
    condition: 'Social Anxiety Disorder',
    short: 'Intense fear of social evaluation.',
    details:
        'Avoidance maintains anxiety. Gradual exposure and realistic thinking are key.',
    tips: [
      'Write a 3-step exposure ladder (e.g., say hi → ask a small question → share an opinion).',
      'After events, list evidence that contradicts harsh self-judgments.',
    ],
  ),
  _Tip(
    condition: 'Specific Phobias',
    short: 'Marked fear of a specific object/situation.',
    details:
        'Exposure therapy—gradual, repeated, and safe—works very well.',
    tips: [
      'Create a graded list (1–10) of exposures; practice daily with support.',
      'Pair exposures with slow breathing, not avoidance.',
    ],
  ),
  _Tip(
    condition: 'Obsessive-Compulsive Disorder (OCD)',
    short: 'Intrusive thoughts + compulsions to reduce distress.',
    details:
        'ERP (Exposure and Response Prevention) is gold standard; resist rituals to let anxiety naturally decline.',
    tips: [
      'Name the thought “just a noise” and delay the compulsion by 5 minutes.',
      'Track wins: each resisted ritual weakens the cycle.',
    ],
  ),
  _Tip(
    condition: 'Body Dysmorphic Disorder',
    short: 'Preoccupation with perceived flaws in appearance.',
    details:
        'Often involves mirror checking or camouflaging. ERP and self-compassion are core.',
    tips: [
      'Reduce mirror time and set “no-zoom” phone rules.',
      'Practice neutral descriptions of appearance rather than judgments.',
    ],
  ),
  _Tip(
    condition: 'Post-Traumatic Stress Disorder (PTSD)',
    short: 'Intrusions, avoidance, hyperarousal after trauma.',
    details:
        'Evidence-based therapies: TF-CBT, EMDR, CPT. Grounding skills help in the moment.',
    tips: [
      'Use 5-4-3-2-1 grounding with senses.',
      'Build a safe routine: predictable wake/sleep, meals, movement.',
    ],
  ),
  _Tip(
    condition: 'Acute Stress Disorder',
    short: 'PTSD-like symptoms within first month after trauma.',
    details:
        'Early support, psychoeducation, and coping skills can help recovery.',
    tips: [
      'Normalize reactions; keep routines simple and supportive.',
      'Connect with trusted people; limit trauma media exposure.',
    ],
  ),
  _Tip(
    condition: 'Adjustment Disorder',
    short: 'Disproportionate distress after a life change.',
    details:
        'Time-limited, treatable with brief therapy and problem-solving.',
    tips: [
      'Break problems into tiny actions with deadlines.',
      'Keep sleep/wake consistent to protect mood.',
    ],
  ),
  _Tip(
    condition: 'Bipolar I Disorder',
    short: 'Mania episodes; depression may also occur.',
    details:
        'Mood stabilizers and psychoeducation are key. Track sleep as an early signal.',
    tips: [
      'Protect sleep; avoid all-nighters and stimulants.',
      'Create a relapse plan with supporters and clinician.',
    ],
  ),
  _Tip(
    condition: 'Bipolar II Disorder',
    short: 'Hypomania + depression episodes.',
    details:
        'Treatment focuses on mood stability and routine regularity.',
    tips: [
      'Use consistent daily anchors (wake, meals, activity).',
      'Notice early hypomania signs (reduced need for sleep, impulsive plans).',
    ],
  ),
  _Tip(
    condition: 'Cyclothymic Disorder',
    short: 'Chronic fluctuating mood symptoms below full episodes.',
    details:
        'Regularity in lifestyle and therapy can smooth mood swings.',
    tips: [
      'Track mood daily; share graphs with your provider.',
      'Limit alcohol; prioritize exercise and lights-out times.',
    ],
  ),
  _Tip(
    condition: 'Schizophrenia',
    short: 'Delusions, hallucinations, disorganized thinking/behavior.',
    details:
        'Coordinated specialty care (therapy, medication, supports) improves outcomes.',
    tips: [
      'Keep routines; minimize cannabis and stimulants.',
      'Build a calm sensory space; use noise-reduction or soothing playlists.',
    ],
  ),
  _Tip(
    condition: 'Schizoaffective Disorder',
    short: 'Schizophrenia symptoms + mood episode features.',
    details:
        'Treatment blends mood and psychosis care; stability and follow-up matter.',
    tips: [
      'Use medication organizers and reminders.',
      'Plan early help steps for warning signs.',
    ],
  ),
  _Tip(
    condition: 'ADHD (Attention-Deficit/Hyperactivity Disorder)',
    short: 'Inattention, hyperactivity, impulsivity patterns.',
    details:
        'Behavioral strategies and (for some) medication help significantly.',
    tips: [
      'Externalize tasks—timers, checklists, visible whiteboard.',
      'Body-double: work alongside a person or virtual co-working room.',
    ],
  ),
  _Tip(
    condition: 'Autism Spectrum (ASD)',
    short: 'Differences in social communication and sensory processing.',
    details:
        'Supportive environments and accommodations improve functioning and comfort.',
    tips: [
      'Use clear, concrete plans and visual supports.',
      'Design a low-stim “reset” zone for sensory overwhelm.',
    ],
  ),
  _Tip(
    condition: 'Borderline Personality Disorder',
    short: 'Intense emotions, unstable relationships, fear of abandonment.',
    details:
        'DBT skills (distress tolerance, emotion regulation) are highly effective.',
    tips: [
      'Use STOP skill (Stop, Take a breath, Observe, Proceed).',
      'Make a crisis plan card you can carry.',
    ],
  ),
  _Tip(
    condition: 'Narcissistic Personality Disorder',
    short: 'Grandiosity, need for admiration, low empathy.',
    details:
        'Therapy can target insight, compassion, and stable self-esteem.',
    tips: [
      'Practice perspective-taking before reacting.',
      'Keep routines that are not status-dependent.',
    ],
  ),
  _Tip(
    condition: 'Antisocial Personality Disorder',
    short: 'Pattern of disregard for and violation of others’ rights.',
    details:
        'Treatment focuses on behavior change, accountability, and skills.',
    tips: [
      'Set structured goals with clear contingencies.',
      'Practice impulse delay (count to 20 + one alternative).',
    ],
  ),
  _Tip(
    condition: 'Avoidant Personality Disorder',
    short: 'Social inhibition, feelings of inadequacy, hypersensitivity to criticism.',
    details:
        'CBT with graded exposures is helpful; self-compassion work supports change.',
    tips: [
      'Write small social exposures and reward completion.',
      'Track kind things people actually say vs. feared judgments.',
    ],
  ),
  _Tip(
    condition: 'Dependent Personality Disorder',
    short: 'Excessive need to be taken care of; difficulty making decisions alone.',
    details:
        'Therapy builds autonomy and assertiveness step by step.',
    tips: [
      'Decide one low-stakes choice alone daily.',
      'Use “DEAR MAN” assertiveness framework.',
    ],
  ),
  _Tip(
    condition: 'Obsessive-Compulsive Personality Disorder (OCPD)',
    short: 'Preoccupation with orderliness, perfectionism, control.',
    details:
        'Flexibility training and values-based goals reduce rigidity.',
    tips: [
      'Set “good-enough” time boxes and stop when the timer ends.',
      'Delegate one task weekly even if not done your way.',
    ],
  ),
  _Tip(
    condition: 'Anorexia Nervosa',
    short: 'Restriction leading to significantly low body weight; distorted body image.',
    details:
        'Requires medical monitoring; specialized therapy and nutrition support.',
    tips: [
      'Follow a supervised meal plan; avoid compensatory behaviors.',
      'Replace body-checking with values-based activities.',
    ],
  ),
  _Tip(
    condition: 'Bulimia Nervosa',
    short: 'Binge eating with compensatory behaviors (e.g., purging).',
    details:
        'CBT-E and regular eating plans reduce binges and purging cycles.',
    tips: [
      'Aim for 3 meals + 2–3 snacks at regular times.',
      'Delay urges 15 minutes and use coping cards.',
    ],
  ),
  _Tip(
    condition: 'Binge-Eating Disorder',
    short: 'Recurrent binge episodes without regular compensatory behaviors.',
    details:
        'Structured meals, coping skills, and therapy help regain control.',
    tips: [
      'Keep tempting binge foods out of immediate reach.',
      'Use HALT check (Hungry/Angry/Lonely/Tired) before eating.',
    ],
  ),
  _Tip(
    condition: 'Insomnia Disorder',
    short: 'Persistent difficulty falling or staying asleep, or early waking.',
    details:
        'CBT-I is first-line: sleep schedule, stimulus control, and sleep hygiene.',
    tips: [
      'Fixed wake time daily; bed only for sleep/intimacy.',
      'If awake >20 min, get up briefly and do something calm under dim light.',
    ],
  ),
  _Tip(
    condition: 'Circadian Rhythm Sleep-Wake Disorders',
    short: 'Misalignment between biological clock and desired schedule.',
    details:
        'Light timing, melatonin, and gradual schedule shifts can help.',
    tips: [
      'Morning bright light; evening low light and screens off.',
      'Shift schedule by 15–30 minutes every few days.',
    ],
  ),
  _Tip(
    condition: 'Substance Use Disorder (Alcohol)',
    short: 'Loss of control, cravings, continued use despite harm.',
    details:
        'Evidence-based supports: medications, therapy, mutual-help groups.',
    tips: [
      'Identify triggers and make a “if-then” coping list.',
      'Keep none at home; ask a friend to be a support contact.',
    ],
  ),
  _Tip(
    condition: 'Substance Use Disorder (Stimulants/Opioids/Cannabis)',
    short: 'Use causing impairment, withdrawal, or risky behavior.',
    details:
        'Medication-assisted treatment and CBT/contingency management help.',
    tips: [
      'Plan urge surfing: urges peak and pass like waves.',
      'Replace with healthy dopamine: exercise, social connection, sunlight.',
    ],
  ),
  _Tip(
    condition: 'Gambling Disorder',
    short: 'Persistent, problematic gambling behavior.',
    details:
        'Blocking tools, financial safeguards, and therapy are helpful.',
    tips: [
      'Install blocking software; self-exclude where possible.',
      'Hand finances to a trusted person during recovery.',
    ],
  ),
  _Tip(
    condition: 'Internet Gaming Disorder (proposed)',
    short: 'Gaming dominates life and causes impairment.',
    details:
        'Limit cues, schedule alternatives, and use gradual reduction plans.',
    tips: [
      'Set play windows and hard stops; remove auto-login.',
      'Fill the freed time with rewarding offline activities.',
    ],
  ),
  _Tip(
    condition: 'Somatic Symptom Disorder',
    short: 'Distressing focus on physical symptoms with high anxiety.',
    details:
        'Treatment targets catastrophic interpretations and reduces checking.',
    tips: [
      'Schedule health checking to 1–2 short windows daily.',
      'Practice balanced explanations for symptoms.',
    ],
  ),
  _Tip(
    condition: 'Illness Anxiety Disorder (Health Anxiety)',
    short: 'Preoccupation with having/acquiring a serious illness.',
    details:
        'CBT helps reduce reassurance-seeking and internet checking.',
    tips: [
      'Set “no Dr. Google” rules outside a brief check window.',
      'Track evidence for/against feared conclusions.',
    ],
  ),
  _Tip(
    condition: 'Conversion Disorder (Functional Neurological Symptom Disorder)',
    short: 'Neurological-like symptoms not explained by disease.',
    details:
        'Multidisciplinary treatment focusing on function and stress.',
    tips: [
      'Rehabilitation exercises as prescribed; reduce symptom monitoring.',
      'Use stress-management and pacing strategies.',
    ],
  ),
  _Tip(
    condition: 'Dissociative Identity Disorder',
    short: 'Disruption of identity with distinct states; memory gaps.',
    details:
        'Treatment emphasizes safety, stabilization, and trauma therapy.',
    tips: [
      'Use grounding kits (textures, scents, cold water).',
      'Develop internal communication with parts via journaling.',
    ],
  ),
  _Tip(
    condition: 'Depersonalization/Derealization Disorder',
    short: 'Feeling detached from self or surroundings.',
    details:
        'Often triggered by stress/anxiety; grounding and CBT help.',
    tips: [
      'Name it: “This feels unreal but I am safe.”',
      'Engage senses: hold ice, count objects by color.',
    ],
  ),
  _Tip(
    condition: 'Hoarding Disorder',
    short: 'Persistent difficulty discarding items, leading to clutter.',
    details:
        'CBT with sorting practice and exposure to discarding is core.',
    tips: [
      'Start with low-emotional items; set a 15-minute daily discard.',
      'Use photos to keep memories instead of objects.',
    ],
  ),
  _Tip(
    condition: 'Trichotillomania (Hair-Pulling)',
    short: 'Recurrent hair pulling with attempts to stop.',
    details:
        'Habit Reversal Training (HRT) and competing responses help.',
    tips: [
      'Identify triggers; keep hands busy (stress ball, fidget).',
      'Wear barrier styles or finger covers during high-risk times.',
    ],
  ),
  _Tip(
    condition: 'Excoriation (Skin-Picking) Disorder',
    short: 'Recurrent skin picking causing lesions.',
    details:
        'HRT, stimulus control, and self-compassion reduce cycles.',
    tips: [
      'Cover mirrors or use soft lighting for brief grooming only.',
      'Use competing responses (hand lotion, putty) for urges.',
    ],
  ),
  _Tip(
    condition: 'Tic Disorders / Tourette Syndrome',
    short: 'Motor and/or vocal tics; severity varies.',
    details:
        'CBIT (behavioral therapy) teaches awareness and competing responses.',
    tips: [
      'Track antecedents; practice “competing response” behaviors.',
      'Reduce stimulants and manage stress where possible.',
    ],
  ),
  _Tip(
    condition: 'Grief (Bereavement)',
    short: 'Natural response to loss; can be intense and nonlinear.',
    details:
        'Most grief softens with time; support and rituals help.',
    tips: [
      'Allow waves; schedule daily “grief time” to journal or remember.',
      'Prioritize sleep, nutrition, and connection with others.',
    ],
  ),
  _Tip(
    condition: 'Prolonged Grief Disorder',
    short: 'Persistent, impairing grief beyond expected cultural norms.',
    details:
        'Therapies focus on restoration and re-engagement with life meaning.',
    tips: [
      'Rebuild routines gradually; set small, meaningful goals.',
      'Join a grief group or counseling for structured support.',
    ],
  ),
  _Tip(
    condition: 'Anger Dysregulation',
    short: 'Frequent intense anger with impulsive reactions.',
    details:
        'Skills training and cognitive strategies improve control.',
    tips: [
      'Use “STOP” + cold water on wrists + 10 slow breaths.',
      'Write a repair script before conversations.',
    ],
  ),
  _Tip(
    condition: 'OCD—Harm/Responsibility Theme',
    short: 'Fear of causing harm, excessive checking or reassurance.',
    details:
        'ERP targets tolerating uncertainty and resisting rituals.',
    tips: [
      'Delay reassurance texts; practice “maybe, maybe not.”',
      'Write a brief “accept uncertainty” statement on your phone.',
    ],
  ),
  _Tip(
    condition: 'OCD—Contamination Theme',
    short: 'Fear of germs/illness, excessive washing/cleaning.',
    details:
        'Gradual contact with feared items without washing breaks the cycle.',
    tips: [
      'Touch a “medium-scary” doorknob and delay washing 15 minutes.',
      'Track anxiety drop over time to build confidence.',
    ],
  ),
  _Tip(
    condition: 'PTSD—Nightmares',
    short: 'Trauma-related dreams disrupting sleep.',
    details:
        'Image Rehearsal Therapy can change recurring nightmares.',
    tips: [
      'Rewrite the nightmare with a safe ending; rehearse daily while awake.',
      'Wind-down routine and low light before bed.',
    ],
  ),
  _Tip(
    condition: 'Perfectionism',
    short: 'Overly high standards with self-criticism.',
    details:
        'Flexible goals and “good-enough” practice improve performance and wellbeing.',
    tips: [
      'Set “B-minus” targets for low-stakes tasks.',
      'Celebrate attempts, not just outcomes.',
    ],
  ),
  _Tip(
    condition: 'Stress Burnout',
    short: 'Exhaustion, cynicism, reduced efficacy from chronic stressors.',
    details:
        'Recovery needs rest, boundaries, and meaning-aligned activities.',
    tips: [
      'Schedule recovery blocks (sleep, play, connection, movement).',
      'Say “no” to one thing this week to create space.',
    ],
  ),
  _Tip(
    condition: 'Self-Harm Urges',
    short: 'Thoughts/urges to hurt oneself to cope with distress.',
    details:
        'Seek professional help; create safety plans and use alternatives.',
    tips: [
      'Use ice, snap rubber band, draw on skin instead; call a support.',
      'Remove tools; go to a public/safe place until urge passes.',
    ],
  ),
  _Tip(
    condition: 'Suicidal Thoughts',
    short: 'Thoughts of death or ending life; always take seriously.',
    details:
        'Immediate help is essential—contact crisis services or emergency care.',
    tips: [
      'Use a written safety plan with warning signs and contacts.',
      'Call/text your local crisis line or 988 (US) right away.',
    ],
  ),
];

