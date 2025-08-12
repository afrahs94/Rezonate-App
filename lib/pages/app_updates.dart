// lib/pages/app_updates_page.dart
//DELETE THIS FILE

import 'package:flutter/material.dart';

class AppUpdatesPage extends StatefulWidget {
  const AppUpdatesPage({Key? key}) : super(key: key);

  @override
  _AppUpdatesPageState createState() => _AppUpdatesPageState();
}

class _AppUpdatesPageState extends State<AppUpdatesPage> {
  bool _autoUpdate = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Updates')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Auto-Download Updates'),
            value: _autoUpdate,
            onChanged: (v) => setState(() => _autoUpdate = v),
          ),
        ],
      ),
    );
  }
}
