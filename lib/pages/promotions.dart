// lib/pages/promotions_page.dart
//DELETE PAGE
import 'package:flutter/material.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({Key? key}) : super(key: key);

  @override
  _PromotionsPageState createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  bool _receivePromos = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promotions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Receive Promotional Emails'),
            value: _receivePromos,
            onChanged: (v) => setState(() => _receivePromos = v),
          ),
        ],
      ),
    );
  }
}
