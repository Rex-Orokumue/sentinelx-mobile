import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../core/providers.dart';
import '../core/routing/web_links.dart';
import '../features/account/account_screen.dart';
import '../features/auth/check_email_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/debug/debug_sign_in_screen.dart';
import '../features/home/home_screen.dart';
import '../features/rankings/rankings_screen.dart';
import '../features/seasons/seasons_list_screen.dart';
import '../features/seasons/season_detail_screen.dart';
import '../features/hall_of_fame/hall_of_fame_screen.dart';
import '../features/onboarding/onboarding_username_screen.dart';
import '../features/tournaments/bracket_screen.dart';
import '../features/tournaments/tournament_detail_screen.dart';
import '../features/tournaments/tournament_list_screen.dart';
import '../shared/widgets/coming_soon_screen.dart';
import 'auth_redirect.dart';

GoRouter buildAppRouter({
  bool debugTools = false,
  String initialLocation = '/',
  AuthGateSnapshot Function()? authGate,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    // App Links (and later, push/bell taps) hand go_router the raw web URL, which is not itself
    // a valid route path. resolveWebLink() is the single place that maps it to one.
    redirect: (context, state) {
      final incoming = state.uri.toString();
      final resolved = resolveWebLink(incoming);
      if (resolved != null && resolved != incoming) return resolved;
      final gate = authGate?.call();
      if (gate != null) {
        final authRedirect = evaluateAuthRedirect(gate, state.matchedLocation);
        if (authRedirect != null) return authRedirect;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            HomeScreen(onGoTo: (path) => context.go(path)),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onLoggedIn: () => context.go('/'),
          onForgotPassword: () => context.push('/forgot-password'),
          onCreateAccount: () => context.push('/signup'),
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignupScreen(
          onSignedUp: (email) =>
              context.push('/signup/check-email', extra: email),
          onLogIn: () => context.push('/login'),
          onGoogleSignedIn: () => context.go('/'),
          initialRef: state.uri.queryParameters['ref'],
        ),
      ),
      GoRoute(
        path: '/signup/check-email',
        builder: (context, state) => CheckEmailScreen(
          email: state.extra as String? ?? '',
          onGoToLogin: () => context.go('/login'),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordScreen(onDone: () => context.go('/')),
      ),
      GoRoute(
        path: '/onboarding/username',
        builder: (context, state) =>
            OnboardingUsernameScreen(onClaimed: () => context.go('/')),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(
          body: shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: shell.goBranch,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                label: 'Compete',
              ),
              NavigationDestination(
                icon: Icon(Icons.live_tv_outlined),
                label: 'Watch',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                label: 'Community',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                label: 'Trade',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: 'Account',
              ),
            ],
          ),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tournaments',
                builder: (context, state) => TournamentListScreen(
                  onTournamentTap: (tournament) =>
                      context.push('/tournaments/${tournament.id}'),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return TournamentDetailScreen(
                        tournamentId: id,
                        onViewBracket: () =>
                            context.push('/tournaments/$id/bracket'),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'bracket',
                        builder: (context, state) => BracketScreen(
                          tournamentId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/rankings',
                builder: (context, state) =>
                    RankingsScreen(onGoTo: (path) => context.push(path)),
              ),
              GoRoute(
                path: '/seasons',
                builder: (context, state) => SeasonsListScreen(
                  onSeasonTap: (s) => context.push('/seasons/${s.slug}'),
                ),
                routes: [
                  GoRoute(
                    path: ':slug',
                    builder: (context, state) =>
                        SeasonDetailScreen(slug: state.pathParameters['slug']!),
                  ),
                ],
              ),
              GoRoute(
                path: '/hall-of-fame',
                builder: (context, state) => const HallOfFameScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tv',
                builder: (context, state) => ComingSoonScreen(
                  title: 'Watch',
                  onLogoTap: () => context.go('/'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (context, state) => ComingSoonScreen(
                  title: 'Community',
                  onLogoTap: () => context.go('/'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exchange',
                builder: (context, state) => ComingSoonScreen(
                  title: 'Trade',
                  onLogoTap: () => context.go('/'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => AccountScreen(
                  onLogIn: () => context.push('/login'),
                  onSignUp: () => context.push('/signup'),
                  onLogoTap: () => context.go('/'),
                ),
              ),
            ],
          ),
        ],
      ),
      if (debugTools)
        GoRoute(
          path: '/debug',
          builder: (context, state) => const DebugSignInScreen(),
        ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(sessionProvider, (_, _) => refresh.ping());
  ref.listen(meProvider, (_, _) => refresh.ping());
  final router = buildAppRouter(
    debugTools: ref.watch(appConfigProvider).debugTools,
    authGate: () => AuthGateSnapshot(
      isLoading:
          ref.read(sessionProvider).isLoading ||
          (ref.read(sessionProvider).value != null &&
              ref.read(meProvider).isLoading),
      isSignedIn: ref.read(meProvider).asData?.value != null,
      onboardingGate: ref.read(onboardingGateProvider),
    ),
    refreshListenable: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}
