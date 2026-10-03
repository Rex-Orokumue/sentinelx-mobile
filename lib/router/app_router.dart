import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../core/providers.dart';
import '../core/api/players_models.dart';
import '../core/l10n/gen/app_localizations.dart';
import '../core/routing/web_links.dart';
import '../features/account/account_screen.dart';
import '../features/account/edit_profile_screen.dart';
import '../core/api/community_models.dart';
import '../features/community/community_feed_screen.dart';
import '../features/community/compose_screen.dart';
import '../features/community/post_detail_screen.dart';
import '../features/community/status_compose_screen.dart';
import '../features/community/status_viewer_screen.dart';
import '../features/community/status_viewers_screen.dart';
import '../features/compete/compete_detail_screen.dart';
import '../features/compete/compete_list_screen.dart';
import '../features/compete/games_screen.dart';
import '../features/compete/invitations_screen.dart';
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
import '../features/players/follow_list_screen.dart';
import '../features/players/player_profile_screen.dart';
import '../features/players/players_directory_screen.dart';
import '../features/players/players_providers.dart';
import '../features/progress/history_list_screen.dart';
import '../features/progress/my_progress_screen.dart';
import '../features/progress/progress_providers.dart';
import '../core/api/match_models.dart';
import '../features/bracket/bracket_screen.dart';
import '../features/bracket/stage_standings_screen.dart';
import '../features/match/lobby_result_screen.dart';
import '../features/match/match_centre_screen.dart';
import '../features/match/match_providers.dart';
import '../features/match/match_reads_repository.dart';
import '../features/match/rating_sheet.dart';
import '../features/match/result_submission_screen.dart';
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
        builder: (context, state) => HomeScreen(
          onGoTo: (path) => context.go(path),
          onOpenLobby: (id, lobby) => context.push('/lobbies/$id/result', extra: lobby),
        ),
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
      GoRoute(path: '/invitations', builder: (context, state) => const InvitationsScreen()),
      GoRoute(path: '/games', builder: (context, state) => const GamesScreen()),
      GoRoute(
        path: '/lobbies/:id/result',
        builder: (context, state) =>
            LobbyResultScreen(lobbyId: state.pathParameters['id']!, lobby: state.extra as NextLobby?),
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
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tournaments',
              builder: (context, state) => CompeteListScreen(
                onTournamentTap: (tournament) => context.push('/tournaments/${tournament.id}'),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return CompeteDetailScreen(
                      tournamentId: id,
                      onViewBracket: (tournamentId) => context.push('/tournaments/$tournamentId/bracket'),
                      onLogin: () => context.push('/login'),
                      onNeedsUsername: () => context.push('/onboarding/username'),
                      onViewInvitations: () => context.push('/invitations'),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'bracket',
                      builder: (context, state) {
                        final id = state.pathParameters['id']!;
                        return BracketScreen(
                          tournamentId: id,
                          onMatchTap: (matchId) => context.push('/matches/$matchId'),
                          onStageTap: (stage) => context.push('/tournaments/$id/stages/${stage.id}', extra: stage),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'stages/:stageId',
                      builder: (context, state) {
                        final id = state.pathParameters['id']!;
                        final stageId = state.pathParameters['stageId']!;
                        final stage = state.extra as StageInfo? ??
                            StageInfo(id: stageId, seq: 0, name: AppLocalizations.of(context).mtcStages, status: '');
                        return StageStandingsScreen(tournamentId: id, stage: stage);
                      },
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/matches/:id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return MatchCentreScreen(
                  matchId: id,
                  onLogin: () => context.push('/login'),
                  onSubmitResult: (m) => context.push('/matches/${m.id}/result', extra: m),
                  onRate: (m) => showRatingSheet(context, match: m),
                );
              },
              routes: [
                GoRoute(
                  path: 'result',
                  builder: (context, state) {
                    final extra = state.extra as MatchInfo?;
                    if (extra != null) return ResultSubmissionScreen(match: extra);
                    return _ResultRouteGate(matchId: state.pathParameters['id']!);
                  },
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
            GoRoute(
              path: '/players',
              builder: (context, state) => PlayersDirectoryScreen(onPlayerTap: (u) => context.push('/players/${Uri.encodeComponent(u)}')),
              routes: [
                GoRoute(
                  path: ':username',
                  builder: (context, state) => PlayerProfileScreen(
                    username: state.pathParameters['username']!,
                    onLogIn: () => context.push('/login'),
                    onOpenFollowers: (u) => context.push('/players/${Uri.encodeComponent(u)}/followers'),
                    onOpenFollowing: (u) => context.push('/players/${Uri.encodeComponent(u)}/following'),
                  ),
                  routes: [
                    GoRoute(
                      path: 'followers',
                      builder: (context, state) => FollowListScreen(
                        username: state.pathParameters['username']!,
                        kind: FollowListKind.followers,
                        onPlayerTap: (u) => context.push('/players/${Uri.encodeComponent(u)}'),
                      ),
                    ),
                    GoRoute(
                      path: 'following',
                      builder: (context, state) => FollowListScreen(
                        username: state.pathParameters['username']!,
                        kind: FollowListKind.following,
                        onPlayerTap: (u) => context.push('/players/${Uri.encodeComponent(u)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/tv', builder: (context, state) => ComingSoonScreen(title: 'Watch', onLogoTap: () => context.go('/'))),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/community',
              builder: (context, state) => CommunityFeedScreen(
                onCompose: () => context.push('/community/compose'),
                onPostTap: (post) => context.push('/community/${Uri.encodeComponent(post.id)}'),
                onLogin: () => context.push('/login'),
                onStatusTap: (ring) => context.push('/community/statuses/${Uri.encodeComponent(ring.playerId)}', extra: ring),
                onAddStatus: () => context.push('/community/statuses/compose'),
                onEventTap: (event) {
                  final path = resolveWebLink(event.ctaHref);
                  if (path != null) context.push(path);
                },
              ),
              routes: [
                GoRoute(path: 'compose', builder: (context, state) => const ComposeScreen()),
                GoRoute(path: 'statuses/compose', builder: (context, state) => const StatusComposeScreen()),
                GoRoute(
                  path: 'statuses/:playerId',
                  builder: (context, state) {
                    final ring = state.extra as StatusRing?;
                    if (ring == null) return const _StatusRouteGate();
                    return StatusViewerScreen(
                      ring: ring,
                      onOpenViewers: (id) => context.push('/community/statuses/${Uri.encodeComponent(id)}/viewers'),
                    );
                  },
                ),
                GoRoute(
                  path: 'statuses/:statusId/viewers',
                  builder: (context, state) => StatusViewersScreen(statusId: state.pathParameters['statusId']!),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => PostDetailScreen(
                    postId: state.pathParameters['id']!,
                    onLogin: () => context.push('/login'),
                    onDeleted: () => context.pop(),
                  ),
                ),
              ],
            ),
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
                onEditProfile: () => context.push('/account/profile'),
                onOpenProgress: () => context.push('/account/progress'),
              ),
              routes: [
                GoRoute(path: 'profile', builder: (context, state) => const EditProfileScreen()),
                GoRoute(
                  path: 'progress',
                  builder: (context, state) => MyProgressScreen(onGoTo: (p) => context.push(p), onLogIn: () => context.push('/login')),
                  routes: [
                    GoRoute(
                      path: 'xp',
                      builder: (context, state) => HistoryListScreen<XpEvent>(
                        title: AppLocalizations.of(context).progressHistoryXp,
                        provider: xpHistoryProvider,
                        rowBuilder: xpRow,
                      ),
                    ),
                    GoRoute(
                      path: 'score',
                      builder: (context, state) => HistoryListScreen<SxScoreEvent>(
                        title: AppLocalizations.of(context).progressHistoryScore,
                        provider: scoreHistoryProvider,
                        rowBuilder: scoreRow,
                      ),
                    ),
                    GoRoute(
                      path: 'coins',
                      builder: (context, state) => HistoryListScreen<CoinTransaction>(
                        title: AppLocalizations.of(context).progressHistoryCoins,
                        provider: coinHistoryProvider,
                        rowBuilder: coinRow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
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

/// A cold `/community/statuses/:playerId` link carries no ring, and no endpoint hydrates one by id —
/// so there is nothing to load. A ring tapped in the app always arrives with `extra`; only a
/// hand-typed or externally built URL lands here, and it goes back to the feed rather than crashing.
class _StatusRouteGate extends StatelessWidget {
  const _StatusRouteGate();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/community');
    });
    return const Scaffold(body: SizedBox.shrink());
  }
}

/// A cold `/matches/:id/result` deep link carries no `extra` MatchInfo (nothing pushed it), so this loads
/// the match first and renders ResultSubmissionScreen once it resolves.
class _ResultRouteGate extends ConsumerWidget {
  const _ResultRouteGate({required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchInfoProvider(matchId));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(AppLocalizations.of(context).cmpLoadError),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(matchInfoProvider(matchId)),
                child: Text(AppLocalizations.of(context).cmpRetry),
              ),
            ]),
          ),
        ),
      ),
      data: (match) => ResultSubmissionScreen(match: match),
    );
  }
}
