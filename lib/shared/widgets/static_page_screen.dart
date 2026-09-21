import 'package:flutter/material.dart';

class StaticSection {
  const StaticSection({required this.heading, this.paragraphs = const [], this.bulletItems});
  final String heading;
  final List<String> paragraphs;
  final List<String>? bulletItems;
}

class StaticPageScreen extends StatelessWidget {
  const StaticPageScreen({super.key, required this.title, required this.summary, required this.sections});

  final String title;
  final String summary;
  final List<StaticSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(summary, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            for (final section in sections) ...[
              Text(section.heading, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final p in section.paragraphs) ...[
                Text(p),
                const SizedBox(height: 8),
              ],
              if (section.bulletItems != null)
                for (final item in section.bulletItems!)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('•  '),
                      Expanded(child: Text(item)),
                    ]),
                  ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
