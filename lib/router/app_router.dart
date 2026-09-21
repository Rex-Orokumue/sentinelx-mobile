import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../features/onboarding/onboarding_username_screen.dart';
import '../features/tournaments/bracket_screen.dart';
import '../features/tournaments/tournament_detail_screen.dart';
import '../features/tournaments/tournament_list_screen.dart';
import '../shared/widgets/coming_soon_screen.dart';

GoRouter buildAppRouter({bool debugTools = false, String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    // App Links (and later, push/bell taps) hand go_router the raw web URL, which is not itself
    // a valid route path. resolveWebLink() is the single place that maps it to one.
    redirect: (context, state) {
      final incoming = state.uri.toString();
      final resolved = resolveWebLink(incoming);
      if (resolved != null && resolved != incoming) return resolved;
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => HomeScreen(onGoTo: (path) => context.go(path))),
      GoRoute(path: '/login', builder: (context, state) => LoginScreen(
            onLoggedIn: () => context.go('/'),
            onForgotPassword: () => context.push('/forgot-password'),
            onCreateAccount: () => context.push('/signup'),
          )),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignupScreen(
          onSignedUp: (email) => context.push('/signup/check-email', extra: email),
          onLogIn: () => context.push('/login'),
          onGoogleSignedIn: () => context.go('/'),
          initialRef: state.uri.queryParameters['ref'],
        ),
      ),
      GoRoute(
        path: '/signup/check-email',
        builder: (context, state) => CheckEmailScreen(email: state.extra as String? ?? '', onGoToLogin: () => context.go('/login')),
      ),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (context, state) => ResetPasswordScreen(onDone: () => context.go('/'))),
      GoRoute(
        path: '/onboarding/username',
        builder: (context, state) => OnboardingUsernameScreen(onClaimed: () => context.go('/')),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(
          body: shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: shell.goBranch,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'Compete'),
              NavigationDestination(icon: Icon(Icons.live_tv_outlined), label: 'Watch'),
              NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Community'),
              NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Trade'),
              NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
            ],
          ),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tournaments',
              builder: (context, state) => TournamentListScreen(
                onTournamentTap: (tournament) => context.push('/tournaments/${tournament.id}'),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return TournamentDetailScreen(tournamentId: id, onViewBracket: () => context.push('/tournaments/$id/bracket'));
                  },
                  routes: [GoRoute(path: 'bracket', builder: (context, state) => BracketScreen(tournamentId: state.pathParameters['id']!))],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/tv', builder: (context, state) => ComingSoonScreen(title: 'Watch', onLogoTap: () => context.go('/'))),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/community', builder: (context, state) => ComingSoonScreen(title: 'Community', onLogoTap: () => context.go('/'))),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/exchange', builder: (context, state) => ComingSoonScreen(title: 'Trade', onLogoTap: () => context.go('/'))),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/account',
              builder: (context, state) => AccountScreen(
                onLogIn: () => context.push('/login'),
                onSignUp: () => context.push('/signup'),
                onLogoTap: () => context.go('/'),
              ),
            ),
          ]),
        ],
      ),
      if (debugTools)
        GoRoute(path: '/debug', builder: (context, state) => const DebugSignInScreen()),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildAppRouter(debugTools: ref.watch(appConfigProvider).debugTools);
  ref.onDispose(router.dispose);
  return router;
});
