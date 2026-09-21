import 'package:flutter/material.dart';

import 'sx_tab_app_bar.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.onLogoTap});

  final String title;
  final VoidCallback onLogoTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SxTabAppBar(title: title, onLogoTap: onLogoTap),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
