import '../../../core/l10n/gen/app_localizations.dart';

class CoachStep {
  const CoachStep(this.targetId, this.title, this.body);
  final String targetId;
  final String Function(AppLocalizations) title, body;
}

class CoachTour {
  const CoachTour(this.id, this.steps);
  final String id;
  final List<CoachStep> steps;
}

final homeTour = CoachTour('home', [
  CoachStep('home.fixtures', (l) => l.coachFixturesTitle, (l) => l.coachFixturesBody),
  CoachStep('home.quest', (l) => l.coachQuestTitle, (l) => l.coachQuestBody),
  CoachStep('home.guide', (l) => l.coachGuideTitle, (l) => l.coachGuideBody),
  CoachStep('home.account', (l) => l.coachAccountTitle, (l) => l.coachAccountBody),
]);

final shellTour = CoachTour('shell', [
  CoachStep('shell.tabs', (l) => l.coachTabsTitle, (l) => l.coachTabsBody),
  CoachStep('appbar.bell', (l) => l.coachBellTitle, (l) => l.coachBellBody),
  CoachStep('appbar.messages', (l) => l.coachMessagesTitle, (l) => l.coachMessagesBody),
  CoachStep('appbar.guide', (l) => l.coachGuideTitle, (l) => l.coachGuideBody),
]);
