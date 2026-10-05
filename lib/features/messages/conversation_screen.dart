import 'package:flutter/material.dart';

/// `/messages/:threadId`. Placeholder until Task 8 builds the conversation UI; the route exists now so the
/// inbox, bell and push taps have a destination.
class ConversationScreen extends StatelessWidget {
  const ConversationScreen({super.key, required this.threadId});

  final String threadId;

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(), body: Center(child: Text(threadId)));
}
