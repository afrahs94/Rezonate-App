// lib/pages/resources.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:new_rezonate/main.dart' as app;

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  String _filter = 'All';

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

  Future<void> _openTel(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  Future<void> _openSms(String phone, {String body = ''}) async {
    final uri = Uri.parse('sms:$phone${body.isNotEmpty ? '?body=${Uri.encodeComponent(body)}' : ''}');
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  Future<void> _openWeb(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);
    final items = _resources.where((r) => _filter == 'All' || r.tags.contains(_filter)).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: false,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerScrolled) => [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                floating: true,
                snap: true,
                pinned: false,
                title: const Text(
                  'Resources',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: .2),
                ),
              ),
            ],
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Safety banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black),
                  ),
                  child: const Text(
                    'If you are in immediate danger or thinking about harming yourself, '
                    'call your local emergency number right now (e.g., 911/999/112).',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),

                // Filters
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.78),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _allTags)
                        ChoiceChip(
                          label: Text(tag),
                          selected: _filter == tag,
                          onSelected: (_) => setState(() => _filter = tag),
                          selectedColor: Colors.white,
                          side: BorderSide(color: Colors.black.withOpacity(.15)),
                          backgroundColor: Colors.white.withOpacity(.65),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _filter == tag ? Colors.black : Colors.black87,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Cards
                ...items.map((r) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.86),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 1),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF7F5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: green.withOpacity(.25)),
                                ),
                                child: Text(r.regionLabel, style: const TextStyle(fontSize: 12, color: green)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(r.description),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (r.phone != null)
                                FilledButton.icon(
                                  onPressed: () => _openTel(r.phone!),
                                  icon: const Icon(Icons.call_rounded, size: 18),
                                  label: Text('Call ${r.phone}'),
                                  style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white),
                                ),
                              if (r.text != null)
                                OutlinedButton.icon(
                                  onPressed: () => _openSms(r.text!, body: r.textBody ?? ''),
                                  icon: const Icon(Icons.sms_rounded),
                                  label: Text('Text ${r.text}'),
                                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white.withOpacity(.7)),
                                ),
                              if (r.url != null)
                                OutlinedButton.icon(
                                  onPressed: () => _openWeb(r.url!),
                                  icon: const Icon(Icons.public_rounded),
                                  label: const Text('Website / Chat'),
                                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white.withOpacity(.7)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Resource {
  final String name;
  final String regionLabel; // badge text (e.g., "US", "Global")
  final List<String> tags;  // for filtering
  final String description;
  final String? phone;
  final String? text;
  final String? textBody;
  final String? url;

  const _Resource({
    required this.name,
    required this.regionLabel,
    required this.tags,
    required this.description,
    this.phone,
    this.text,
    this.textBody,
    this.url,
  });
}

const List<String> _allTags = [
  'All',
  'US',
  'Canada',
  'Global',
  'LGBTQ+',
  'Veterans',
  'Youth',
  'Substance',
  'DV/Safety',
  'Eating',
];

const List<_Resource> _resources = [
  // --- Global / General ---
  _Resource(
    name: 'Emergency Services',
    regionLabel: 'Global',
    tags: ['Global'],
    description: 'If you or someone else is in immediate danger, call your emergency number (e.g., 911/999/112).',
  ),
  _Resource(
    name: 'Crisis Text Line (US/CA)',
    regionLabel: 'Global',
    tags: ['Global', 'Youth', 'US', 'Canada'],
    description: 'Free, 24/7 text support for people in crisis.',
    text: '741741', // US/CA
    textBody: 'HOME',
    url: 'https://www.crisistextline.org/',
  ),

  // --- United States ---
  _Resource(
    name: '988 Suicide & Crisis Lifeline',
    regionLabel: 'US',
    tags: ['US', 'Youth'],
    description: '24/7 free support. Call, text, or chat with trained counselors.',
    phone: '988',
    text: '988',
    url: 'https://988lifeline.org/',
  ),
  _Resource(
    name: 'Veterans Crisis Line',
    regionLabel: 'US',
    tags: ['US', 'Veterans'],
    description: '24/7 confidential support for Veterans, service members, and their families. Call 988, then press 1.',
    phone: '988', // press 1 after connecting
    text: '838255',
    url: 'https://www.veteranscrisisline.net/',
  ),
  _Resource(
    name: 'The Trevor Project (LGBTQ+ Youth)',
    regionLabel: 'US',
    tags: ['US', 'LGBTQ+', 'Youth'],
    description: 'Crisis intervention and suicide prevention for LGBTQ+ young people.',
    phone: '1-866-488-7386',
    text: '678678', // text START
    textBody: 'START',
    url: 'https://www.thetrevorproject.org/get-help/',
  ),
  _Resource(
    name: 'SAMHSA National Helpline',
    regionLabel: 'US',
    tags: ['US', 'Substance'],
    description: '24/7 treatment referral and information for mental health & substance use.',
    phone: '1-800-662-4357',
    url: 'https://www.samhsa.gov/find-help/national-helpline',
  ),
  _Resource(
    name: 'National Domestic Violence Hotline',
    regionLabel: 'US',
    tags: ['US', 'DV/Safety'],
    description: '24/7 confidential support for people affected by relationship abuse.',
    phone: '1-800-799-7233',
    text: '88788', // text START
    textBody: 'START',
    url: 'https://www.thehotline.org/',
  ),
  _Resource(
    name: 'NEDA – Eating Disorders',
    regionLabel: 'US',
    tags: ['US', 'Eating'],
    description: 'Education and support options for eating disorders.',
    url: 'https://www.nationaleatingdisorders.org/help-support/',
  ),

  // --- Canada ---
  _Resource(
    name: 'Talk Suicide Canada',
    regionLabel: 'Canada',
    tags: ['Canada', 'Youth'],
    description: '24/7 crisis and suicide support across Canada.',
    phone: '988',
    text: '988',
    url: 'https://talksuicide.ca/',
  ),
];
