import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import 'guide_mascot.dart';

/// Four static pages for signed-out visitors: what it is, the pillars, how tournaments work, sign up.
class VisitorTour extends StatefulWidget {
  const VisitorTour({super.key});

  @override
  State<VisitorTour> createState() => _VisitorTourState();
}

class _VisitorTourState extends State<VisitorTour> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) => _controller.animateToPage(page, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slides = [
      (l10n.tourSlide1Title, l10n.tourSlide1Body),
      (l10n.tourSlide2Title, l10n.tourSlide2Body),
      (l10n.tourSlide3Title, l10n.tourSlide3Body),
      (l10n.tourSlide4Title, l10n.tourSlide4Body),
    ];
    final last = _page == _pages - 1;
    return Column(children: [
      SizedBox(
        height: 280,
        child: PageView.builder(
          controller: _controller,
          itemCount: _pages,
          onPageChanged: (p) => setState(() => _page = p),
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (i == 0) const GuideMascot(size: 72),
              const SizedBox(height: 12),
              Text(slides[i].$1, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(slides[i].$2, textAlign: TextAlign.center, style: const TextStyle(color: SxColors.textSecondary)),
            ]),
          ),
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < _pages; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, color: i == _page ? SxColors.primary : SxColors.border),
          ),
      ]),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          if (_page > 0) TextButton(key: const Key('tour-back'), onPressed: () => _go(_page - 1), child: Text(l10n.tourBack)),
          const Spacer(),
          if (last)
            FilledButton(
              key: const Key('tour-create-account'),
              onPressed: () => GoRouter.of(context).push('/signup'),
              child: Text(l10n.tourCreateAccount),
            )
          else
            FilledButton(key: const Key('tour-next'), onPressed: () => _go(_page + 1), child: Text(l10n.tourNext)),
        ]),
      ),
    ]);
  }
}
