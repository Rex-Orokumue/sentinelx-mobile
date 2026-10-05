import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/remote_config.dart';
import 'chat_models.dart';
import 'community_models.dart';
import 'compete_models.dart';
import 'guide_models.dart';
import 'match_models.dart';
import 'messages_models.dart';
import 'models.dart';
import 'notifications_models.dart';
import 'players_models.dart';
import 'profile_onboarding_models.dart';
import 'progress_models.dart';
import 'registration_fields_models.dart';

class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.fields = const {},
  });

  final int status;
  final String code;
  final String message;
  final Map<String, String> fields;

  bool get isUpdateRequired => status == 426;
  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'ApiException($status $code: $message)';
}

typedef AccessTokenSupplier = Future<String?> Function();

class ApiClient {
  ApiClient({required Dio dio}) : _dio = dio;

  /// Operations this client calls, keyed by OpenAPI operationId — checked against api/openapi.json
  /// by test/core/api_contract_test.dart so web/mobile drift fails CI instead of a user's phone.
  static const Map<String, String> usedOperations = {
    'getConfig': 'get /api/mobile/v1/config',
    'getMe': 'get /api/mobile/v1/me',
    'postClientError': 'post /api/mobile/v1/errors',
    'postDevice': 'post /api/mobile/v1/devices',
    'deleteDevice': 'delete /api/mobile/v1/devices',
    'postAuthSignup': 'post /api/mobile/v1/auth/signup',
    'postAuthResendConfirmation':
        'post /api/mobile/v1/auth/resend-confirmation',
    'postAuthRequestReset': 'post /api/mobile/v1/auth/request-reset',
    'postSessionStart': 'post /api/mobile/v1/session/start',
    'postOnboardingUsername': 'post /api/mobile/v1/onboarding/username',
    'postOnboardingProfile': 'post /api/mobile/v1/onboarding/profile',
    'getHome': 'get /api/mobile/v1/home',
    'getTournamentRegistrationState': 'get /api/mobile/v1/tournaments/{id}/registration-state',
    'postTournamentRegister': 'post /api/mobile/v1/tournaments/{id}/register',
    'postTournamentWaitlist': 'post /api/mobile/v1/tournaments/{id}/waitlist',
    'postInvitationAccept': 'post /api/mobile/v1/invitations/{id}/accept',
    'postInvitationDecline': 'post /api/mobile/v1/invitations/{id}/decline',
    'getPaymentStatus': 'get /api/mobile/v1/payments/{reference}',
    'patchMeProfile': 'patch /api/mobile/v1/me/profile',
    'getRankings': 'get /api/mobile/v1/rankings',
    'getRankingsMe': 'get /api/mobile/v1/rankings/me',
    'getSeasons': 'get /api/mobile/v1/seasons',
    'getSeasonDetail': 'get /api/mobile/v1/seasons/{slug}',
    'getHallOfFame': 'get /api/mobile/v1/hall-of-fame',
    'searchPlayers': 'get /api/mobile/v1/players',
    'getPlayerProfile': 'get /api/mobile/v1/players/{username}',
    'getPlayerFollowers': 'get /api/mobile/v1/players/{username}/followers',
    'getPlayerFollowing': 'get /api/mobile/v1/players/{username}/following',
    'getMyFollows': 'get /api/mobile/v1/me/follows',
    'followPlayer': 'put /api/mobile/v1/players/{username}/follow',
    'unfollowPlayer': 'delete /api/mobile/v1/players/{username}/follow',
    'getMyProgress': 'get /api/mobile/v1/me/progress',
    'getMyXpEvents': 'get /api/mobile/v1/me/xp-events',
    'getMySxScoreEvents': 'get /api/mobile/v1/me/sx-score-events',
    'getMyCoinTransactions': 'get /api/mobile/v1/me/coin-transactions',
    'getTournamentBracket': 'get /api/mobile/v1/tournaments/{id}/bracket',
    'getTournamentStandings': 'get /api/mobile/v1/tournaments/{id}/standings',
    'getTournamentResults': 'get /api/mobile/v1/tournaments/{id}/results',
    'getMatchCentre': 'get /api/mobile/v1/matches/{id}/centre',
    'postMatchCheckIn': 'post /api/mobile/v1/matches/{id}/check-in',
    'postMatchResult': 'post /api/mobile/v1/matches/{id}/result',
    'postMatchRating': 'post /api/mobile/v1/matches/{id}/rating',
    'postMatchWager': 'post /api/mobile/v1/matches/{id}/wager',
    'postLobbyResult': 'post /api/mobile/v1/lobbies/{id}/result',
    'postSquads': 'post /api/mobile/v1/squads',
    'getSquadLookup': 'get /api/mobile/v1/squads/lookup',
    'getMeSummary': 'get /api/mobile/v1/me/summary',
    'getTournamentRegistrationFields': 'get /api/mobile/v1/tournaments/{id}/registration-fields',
    'getCommunityFeed': 'get /api/mobile/v1/community/feed',
    'getCommunityPost': 'get /api/mobile/v1/community/posts/{id}',
    'getCommunityPostComments': 'get /api/mobile/v1/community/posts/{id}/comments',
    'getCommunityChallenges': 'get /api/mobile/v1/community/challenges',
    'getCommunityBestPlay': 'get /api/mobile/v1/community/best-play',
    'getCommunityStatuses': 'get /api/mobile/v1/community/statuses',
    'getCommunityStatusViewers': 'get /api/mobile/v1/community/statuses/{id}/viewers',
    'getCommunityTopMembers': 'get /api/mobile/v1/community/top-members',
    'getCommunityUpcomingEvents': 'get /api/mobile/v1/community/upcoming-events',
    'getCommunityGallery': 'get /api/mobile/v1/community/gallery',
    'getCommunityStats': 'get /api/mobile/v1/community/stats',
    'postCommunityPost': 'post /api/mobile/v1/community/posts',
    'deleteCommunityPost': 'delete /api/mobile/v1/community/posts/{id}',
    'postCommunityPostBoost': 'post /api/mobile/v1/community/posts/{id}/boost',
    'putCommunityPostReaction': 'put /api/mobile/v1/community/posts/{id}/reaction',
    'deleteCommunityPostReaction': 'delete /api/mobile/v1/community/posts/{id}/reaction',
    'postCommunityComment': 'post /api/mobile/v1/community/posts/{id}/comments',
    'deleteCommunityComment': 'delete /api/mobile/v1/community/comments/{id}',
    'postCommunityStatus': 'post /api/mobile/v1/community/statuses',
    'deleteCommunityStatus': 'delete /api/mobile/v1/community/statuses/{id}',
    'postCommunityStatusView': 'post /api/mobile/v1/community/statuses/{id}/view',
    'postCommunityBestPlayVote': 'post /api/mobile/v1/community/best-play/{nominationId}/vote',
    'postCommunityPostReport': 'post /api/mobile/v1/community/posts/{id}/report',
    'postCommunityCommentReport': 'post /api/mobile/v1/community/comments/{id}/report',
    'getNotificationPrefs': 'get /api/mobile/v1/notifications/prefs',
    'patchNotificationPrefs': 'patch /api/mobile/v1/notifications/prefs',
    'getNotificationMutes': 'get /api/mobile/v1/notifications/mutes',
    'postNotificationMute': 'post /api/mobile/v1/notifications/mutes',
    'deleteNotificationMute': 'delete /api/mobile/v1/notifications/mutes',
    'postNotificationRead': 'post /api/mobile/v1/notifications/{id}/read',
    'postNotificationsReadAll': 'post /api/mobile/v1/notifications/read-all',
    'postTestPush': 'post /api/mobile/v1/notifications/test-push',
    'getMessageThreads': 'get /api/mobile/v1/messages/threads',
    'getMessageThread': 'get /api/mobile/v1/messages/threads/{id}',
    'getThreadMessages': 'get /api/mobile/v1/messages/threads/{id}/messages',
    'startMessageThread': 'post /api/mobile/v1/messages/threads',
    'sendMessage': 'post /api/mobile/v1/messages/threads/{id}/messages',
    'editMessage': 'patch /api/mobile/v1/messages/{id}',
    'unsendMessage': 'delete /api/mobile/v1/messages/{id}',
    'forwardMessage': 'post /api/mobile/v1/messages/{id}/forward',
    'markThreadRead': 'post /api/mobile/v1/messages/threads/{id}/read',
    'markAllDelivered': 'post /api/mobile/v1/messages/delivered',
    'blockPlayer': 'put /api/mobile/v1/messages/blocks/{playerId}',
    'unblockPlayer': 'delete /api/mobile/v1/messages/blocks/{playerId}',
    'reportThread': 'post /api/mobile/v1/messages/threads/{id}/report',
    'acceptMessageRequest': 'post /api/mobile/v1/messages/threads/{id}/accept',
    'declineMessageRequest': 'post /api/mobile/v1/messages/threads/{id}/decline',
  };

  /// Phase 5c operations written against the spec before the web Stage B contract exists. NOT checked by
  /// `api_contract_test.dart`; when `api/openapi.json` is re-copied from the web repo, fold these into
  /// [usedOperations] so the drift check covers them.
  static const pendingContractOperations = <String, String>{
    'getGuideQuests': 'get /api/mobile/v1/guide/quests',
    'claimGuideBadge': 'post /api/mobile/v1/guide/badge',
    'postChatMessage': 'post /api/mobile/v1/chat/messages',
    'getChatHistory': 'get /api/mobile/v1/chat/history',
    'deleteChatHistory': 'delete /api/mobile/v1/chat/history',
  };

  static const _base = '/api/mobile/v1';
  final Dio _dio;

  factory ApiClient.create({
    required String baseUrl,
    required String appVersion,
    required String platform,
    required AccessTokenSupplier accessToken,
    HttpClientAdapter? adapter,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (_) => true, // every status is decoded by _send
        headers: {'X-App-Version': appVersion, 'X-Platform': platform},
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = options.extra['public'] == true ? null : await accessToken();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
    return ApiClient(dio: dio);
  }

  Future<T> _send<T>(
    String method,
    String path,
    T Function(Object? data) parse, {
    Object? body,
    Map<String, String>? headers,
    bool publicRequest = false,
  }) async {
    final Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        '$_base$path',
        data: body,
        options: Options(
          method: method,
          responseType: ResponseType.json,
          headers: headers,
          extra: {'public': publicRequest},
        ),
      );
    } on DioException catch (e) {
      throw ApiException(
        status: 0,
        code: 'network',
        message: e.message ?? 'Network error',
      );
    }

    final status = res.statusCode ?? 0;
    final json = res.data;
    if (status >= 200 &&
        status < 300 &&
        json is Map<String, dynamic> &&
        json.containsKey('data')) {
      try {
        return parse(json['data']);
      } catch (_) {
        throw ApiException(
          status: status,
          code: 'bad_response',
          message: 'Could not read the server response.',
        );
      }
    }
    if (json is Map<String, dynamic> && json['error'] is Map<String, dynamic>) {
      final err = json['error'] as Map<String, dynamic>;
      final fields =
          (err['fields'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          const <String, String>{};
      throw ApiException(
        status: status,
        code: err['code'] as String? ?? 'unknown',
        message: err['message'] as String? ?? 'Request failed',
        fields: fields,
      );
    }
    throw ApiException(
      status: status,
      code: 'bad_response',
      message: 'Unexpected response ($status).',
    );
  }

  Future<RemoteConfig> getConfig() => _send(
    'GET',
    '/config',
    (d) => RemoteConfig.fromJson(d! as Map<String, dynamic>),
  );

  Future<MeResponse> getMe() => _send(
    'GET',
    '/me',
    (d) => MeResponse.fromJson(d! as Map<String, dynamic>),
  );

  Future<ProfileOnboardingResult> postOnboardingProfile(ProfileOnboardingInput input) => _send(
        'POST',
        '/onboarding/profile',
        (d) => ProfileOnboardingResult.fromJson(d! as Map<String, dynamic>),
        body: input.toJson(),
      );

  Future<void> postClientError({
    required String message,
    String? stack,
    String? route,
    required String platform,
    required String appVersion,
    String? locale,
  }) => _send(
    'POST',
    '/errors',
    (_) {},
    body: {
      'message': message,
      'stack': ?stack,
      'route': ?route,
      'platform': platform,
      'appVersion': appVersion,
      'locale': ?locale,
    },
  );

  Future<void> registerDevice({
    required String token,
    required String platform,
    required String appVersion,
  }) => _send(
    'POST',
    '/devices',
    (_) {},
    body: {'token': token, 'platform': platform, 'appVersion': appVersion},
  );

  Future<void> unregisterDevice(String token) =>
      _send('DELETE', '/devices', (_) {}, body: {'token': token});

  Future<void> postAuthSignup({
    required String username,
    required String email,
    required String password,
    String? ref,
    String? locale,
  }) => _send(
    'POST',
    '/auth/signup',
    (_) {},
    body: {
      'username': username,
      'email': email,
      'password': password,
      'ref': ?ref,
      'locale': ?locale,
    },
  );

  Future<void> postAuthResendConfirmation(String email) => _send(
    'POST',
    '/auth/resend-confirmation',
    (_) {},
    body: {'email': email},
  );

  Future<void> postAuthRequestReset(String email) =>
      _send('POST', '/auth/request-reset', (_) {}, body: {'email': email});

  Future<SessionStartResponse> postSessionStart() => _send(
    'POST',
    '/session/start',
    (d) => SessionStartResponse.fromJson(d! as Map<String, dynamic>),
  );

  Future<String> postOnboardingUsername(String username) => _send(
    'POST',
    '/onboarding/username',
    (d) => (d! as Map<String, dynamic>)['username'] as String,
    body: {'username': username},
  );

  Future<HomeSummary> getHome() => _send('GET', '/home', (d) => HomeSummary.fromJson(d! as Map<String, dynamic>));

  Future<RegistrationState> getTournamentRegistrationState(String tournamentId) => _send(
        'GET',
        '/tournaments/${Uri.encodeComponent(tournamentId)}/registration-state',
        (d) => RegistrationState.fromJson(d! as Map<String, dynamic>),
      );

  Future<List<RegistrationField>> getTournamentRegistrationFields(String tournamentId) => _send(
        'GET',
        '/tournaments/${Uri.encodeComponent(tournamentId)}/registration-fields',
        (d) => ((d! as Map<String, dynamic>)['fields'] as List<dynamic>)
            .map((e) => RegistrationField.fromJson(e as Map<String, dynamic>))
            .toList(),
        publicRequest: true,
      );

  Future<RegisterOutcome> postTournamentRegister(
    String tournamentId, {
    required RegistrationDetails details,
    required int coinsUsed,
    required String idempotencyKey,
  }) =>
      _send(
        'POST',
        '/tournaments/${Uri.encodeComponent(tournamentId)}/register',
        parseRegisterOutcome,
        body: {...details.toJson(), 'coinsUsed': coinsUsed},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> postTournamentWaitlist(String tournamentId, {required RegistrationDetails details}) => _send(
        'POST',
        '/tournaments/${Uri.encodeComponent(tournamentId)}/waitlist',
        (_) {},
        body: details.toJson(),
      );

  Future<RegisterOutcome> postInvitationAccept(String invitationId, {required String idempotencyKey}) => _send(
        'POST',
        '/invitations/${Uri.encodeComponent(invitationId)}/accept',
        parseRegisterOutcome,
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> postInvitationDecline(String invitationId) =>
      _send('POST', '/invitations/${Uri.encodeComponent(invitationId)}/decline', (_) {});

  Future<PaymentStatus> getPaymentStatus(String reference) => _send(
        'GET',
        '/payments/${Uri.encodeComponent(reference)}',
        (d) => parsePaymentStatus((d! as Map<String, dynamic>)['status'] as String),
      );

  Future<void> patchMeProfile(ProfileEdit edit) => _send('PATCH', '/me/profile', (_) {}, body: edit.toJson());

  String _withQuery(String path, Map<String, Object?> query) {
    final q = <String, String>{
      for (final e in query.entries)
        if (e.value != null) e.key: e.value.toString(),
    };
    return q.isEmpty ? path : Uri(path: path, queryParameters: q).toString();
  }

  Future<RankingsPage> getRankings({
    String? game,
    String? region,
    int page = 1,
    String? metric,
    String? tabGame,
  }) => _send(
    'GET',
    _withQuery('/rankings', {
      'game': game,
      'region': region,
      'page': page > 1 ? page : null,
      'metric': metric,
      'tabGame': tabGame,
    }),
    (d) => RankingsPage.fromJson(d! as Map<String, dynamic>),
    publicRequest: true,
  );

  Future<RankingsMe> getRankingsMe({
    String? game,
    String? region,
    String? metric,
    String? tabGame,
  }) => _send(
    'GET',
    _withQuery('/rankings/me', {
      'game': game,
      'region': region,
      'metric': metric,
      'tabGame': tabGame,
    }),
    (d) => RankingsMe.fromJson(d! as Map<String, dynamic>),
  );

  Future<List<SeasonSummary>> getSeasons() => _send(
    'GET',
    '/seasons',
    (d) => ((d! as Map<String, dynamic>)['seasons'] as List<dynamic>)
        .map((e) => SeasonSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    publicRequest: true,
  );

  Future<SeasonDetail> getSeasonDetail(String slug) => _send(
    'GET',
    '/seasons/${Uri.encodeComponent(slug)}',
    (d) => SeasonDetail.fromJson(d! as Map<String, dynamic>),
    publicRequest: true,
  );

  Future<HallOfFame> getHallOfFame({String? game}) => _send(
    'GET',
    _withQuery('/hall-of-fame', {'game': game}),
    (d) => HallOfFame.fromJson(d! as Map<String, dynamic>),
    publicRequest: true,
  );

  static String _enc(String username) => Uri.encodeComponent(username);

  Future<List<PlayerListItem>> searchPlayers({String q = ''}) => _send(
        'GET',
        _withQuery('/players', {'q': q.isEmpty ? null : q}),
        (d) => (d! as List<dynamic>).map((e) => PlayerListItem.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Future<PlayerProfile> getPlayerProfile(String username) =>
      _send('GET', '/players/${_enc(username)}', (d) => PlayerProfile.fromJson(d! as Map<String, dynamic>));

  Future<List<FollowEntry>> getPlayerFollowers(String username) => _send(
        'GET',
        '/players/${_enc(username)}/followers',
        (d) => (d! as List<dynamic>).map((e) => FollowEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Future<List<FollowEntry>> getPlayerFollowing(String username) => _send(
        'GET',
        '/players/${_enc(username)}/following',
        (d) => (d! as List<dynamic>).map((e) => FollowEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Future<FollowSets> getMyFollows() => _send('GET', '/me/follows', (d) => FollowSets.fromJson(d! as Map<String, dynamic>));

  Future<FollowOutcome> followPlayer(String username, {required String idempotencyKey}) => _send(
        'PUT',
        '/players/${_enc(username)}/follow',
        (d) => FollowOutcome.fromJson(d! as Map<String, dynamic>),
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<FollowOutcome> unfollowPlayer(String username) =>
      _send('DELETE', '/players/${_enc(username)}/follow', (d) => FollowOutcome.fromJson(d! as Map<String, dynamic>));

  Future<MyProgress> getMyProgress() => _send('GET', '/me/progress', (d) => MyProgress.fromJson(d! as Map<String, dynamic>));

  Future<HistoryPage<XpEvent>> getMyXpEvents({String? cursor}) => _send(
        'GET',
        _withQuery('/me/xp-events', {'cursor': cursor}),
        (d) => HistoryPage.parse(d! as Map<String, dynamic>, XpEvent.fromJson),
      );

  Future<HistoryPage<SxScoreEvent>> getMySxScoreEvents({String? cursor}) => _send(
        'GET',
        _withQuery('/me/sx-score-events', {'cursor': cursor}),
        (d) => HistoryPage.parse(d! as Map<String, dynamic>, SxScoreEvent.fromJson),
      );

  Future<HistoryPage<CoinTransaction>> getMyCoinTransactions({String? cursor}) => _send(
        'GET',
        _withQuery('/me/coin-transactions', {'cursor': cursor}),
        (d) => HistoryPage.parse(d! as Map<String, dynamic>, CoinTransaction.fromJson),
      );

  // Phase 2b: bracket, match centre, results, squads, dashboard summary.
  Future<BracketView> getTournamentBracket(String tournamentId) => _send(
        'GET',
        '/tournaments/${Uri.encodeComponent(tournamentId)}/bracket',
        (d) => BracketView.fromJson(d! as Map<String, dynamic>),
      );

  Future<List<PointsStandingRow>> getTournamentStandings(String tournamentId, String stageId) => _send(
        'GET',
        _withQuery('/tournaments/${Uri.encodeComponent(tournamentId)}/standings', {'stage': stageId}),
        (d) => ((d! as Map<String, dynamic>)['rows'] as List<dynamic>)
            .map((e) => PointsStandingRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<TournamentResults> getTournamentResults(String tournamentId) => _send(
        'GET',
        '/tournaments/${Uri.encodeComponent(tournamentId)}/results',
        (d) => TournamentResults.fromJson(d! as Map<String, dynamic>),
      );

  Future<MatchCentre> getMatchCentre(String matchId) => _send(
        'GET',
        '/matches/${Uri.encodeComponent(matchId)}/centre',
        (d) => MatchCentre.fromJson(d! as Map<String, dynamic>),
      );

  Future<void> postMatchCheckIn(String matchId) =>
      _send('POST', '/matches/${Uri.encodeComponent(matchId)}/check-in', (_) {});

  Future<void> postMatchResult(
    String matchId, {
    required int scoreA,
    required int scoreB,
    String recordingUrl = '',
    required String screenshotPath,
    required String idempotencyKey,
  }) =>
      _send(
        'POST',
        '/matches/${Uri.encodeComponent(matchId)}/result',
        (_) {},
        body: {'scoreA': scoreA, 'scoreB': scoreB, 'recordingUrl': recordingUrl, 'screenshotPath': screenshotPath},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> postMatchRating(String matchId, {required int stars, required String idempotencyKey}) => _send(
        'POST',
        '/matches/${Uri.encodeComponent(matchId)}/rating',
        (_) {},
        body: {'stars': stars},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> postMatchWager(
    String matchId, {
    required String pickPlayerId,
    required int stakeCoins,
    required String idempotencyKey,
  }) =>
      _send(
        'POST',
        '/matches/${Uri.encodeComponent(matchId)}/wager',
        (_) {},
        body: {'pickPlayerId': pickPlayerId, 'stakeCoins': stakeCoins},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> postLobbyResult(
    String lobbyId, {
    required int placement,
    required int kills,
    required String screenshotPath,
    required String idempotencyKey,
  }) =>
      _send(
        'POST',
        '/lobbies/${Uri.encodeComponent(lobbyId)}/result',
        (_) {},
        body: {'placement': placement, 'kills': kills, 'screenshotPath': screenshotPath},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<CreatedSquad> postSquads({required String tournamentId, required String name, required String idempotencyKey}) => _send(
        'POST',
        '/squads',
        (d) => CreatedSquad.fromJson(d! as Map<String, dynamic>),
        body: {'tournamentId': tournamentId, 'name': name},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<SquadPreview> getSquadLookup({required String tournamentId, required String code}) => _send(
        'GET',
        _withQuery('/squads/lookup', {'tournamentId': tournamentId, 'code': code}),
        (d) => SquadPreview.fromJson((d! as Map<String, dynamic>)['squad'] as Map<String, dynamic>),
      );

  Future<MeSummary> getMeSummary() => _send('GET', '/me/summary', (d) => MeSummary.fromJson(d! as Map<String, dynamic>));

  // Phase 4: Community feed, posts, reactions, comments, statuses, challenges, best-play,
  // top members, upcoming events, gallery, stats. The reads whose handlers fill caller-specific fields
  // (feed, post, comments, statuses, best-play: myReaction, canDelete/canBoost, isSelf/hasUnseen,
  // myVoteNominationId) send the bearer token like any authenticated call; the web handlers treat it
  // as optional. Only the caller-independent reads (top members, events, gallery, stats) are
  // publicRequest: true. Every idempotent write takes an Idempotency-Key header.
  Future<CommunityFeedPage> getCommunityFeed({int offset = 0, int limit = 20}) => _send(
        'GET',
        offset == 0 && limit == 20
            ? '/community/feed'
            : _withQuery('/community/feed', {'offset': offset, 'limit': limit}),
        (d) => CommunityFeedPage.fromJson(d! as Map<String, dynamic>),
      );

  Future<CommunityPostDetail> getCommunityPost(String id) => _send(
        'GET',
        '/community/posts/${Uri.encodeComponent(id)}',
        (d) => CommunityPostDetail.fromJson(d! as Map<String, dynamic>),
      );

  Future<List<CommentView>> getCommunityPostComments(String id) => _send(
        'GET',
        '/community/posts/${Uri.encodeComponent(id)}/comments',
        (d) => ((d! as Map<String, dynamic>)['comments'] as List<dynamic>)
            .map((e) => CommentView.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<ChallengesWidget?> getCommunityChallenges() => _send(
        'GET',
        '/community/challenges',
        (d) => d == null ? null : ChallengesWidget.fromJson(d as Map<String, dynamic>),
      );

  Future<BestPlayBanner?> getCommunityBestPlay() => _send(
        'GET',
        '/community/best-play',
        (d) => d == null ? null : BestPlayBanner.fromJson(d as Map<String, dynamic>),
      );

  Future<List<StatusRing>> getCommunityStatuses() => _send(
        'GET',
        '/community/statuses',
        (d) => ((d! as Map<String, dynamic>)['rings'] as List<dynamic>)
            .map((e) => StatusRing.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<List<StatusViewer>> getCommunityStatusViewers(String id) => _send(
        'GET',
        '/community/statuses/${Uri.encodeComponent(id)}/viewers',
        (d) => ((d! as Map<String, dynamic>)['viewers'] as List<dynamic>)
            .map((e) => StatusViewer.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<List<TopMember>> getCommunityTopMembers() => _send(
        'GET',
        '/community/top-members',
        (d) => ((d! as Map<String, dynamic>)['members'] as List<dynamic>)
            .map((e) => TopMember.fromJson(e as Map<String, dynamic>))
            .toList(),
        publicRequest: true,
      );

  Future<List<UpcomingEvent>> getCommunityUpcomingEvents() => _send(
        'GET',
        '/community/upcoming-events',
        (d) => ((d! as Map<String, dynamic>)['events'] as List<dynamic>)
            .map((e) => UpcomingEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        publicRequest: true,
      );

  Future<CommunityGalleryPage> getCommunityGallery({int offset = 0, int limit = 8}) => _send(
        'GET',
        offset == 0 && limit == 8
            ? '/community/gallery'
            : _withQuery('/community/gallery', {'offset': offset, 'limit': limit}),
        (d) => CommunityGalleryPage.fromJson(d! as Map<String, dynamic>),
        publicRequest: true,
      );

  Future<CommunityStats> getCommunityStats() => _send(
        'GET',
        '/community/stats',
        (d) => CommunityStats.fromJson(d! as Map<String, dynamic>),
        publicRequest: true,
      );

  Future<String> postCommunityPost({required String content, required List<String> imageUrls, required String idempotencyKey}) => _send(
        'POST',
        '/community/posts',
        (d) => (d! as Map<String, dynamic>)['id'] as String,
        body: {'content': content, 'imageUrls': imageUrls},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> deleteCommunityPost(String id) => _send('DELETE', '/community/posts/${Uri.encodeComponent(id)}', (_) {});

  Future<void> postCommunityPostBoost(String id, {required String idempotencyKey}) => _send(
        'POST',
        '/community/posts/${Uri.encodeComponent(id)}/boost',
        (_) {},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<ReactionType> putCommunityPostReaction(String id, {required ReactionType reaction, required String idempotencyKey}) => _send(
        'PUT',
        '/community/posts/${Uri.encodeComponent(id)}/reaction',
        (d) => reactionTypeFromJson((d! as Map<String, dynamic>)['reaction'] as String),
        body: {'reaction': reaction.wireName},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> deleteCommunityPostReaction(String id) =>
      _send('DELETE', '/community/posts/${Uri.encodeComponent(id)}/reaction', (_) {});

  Future<String> postCommunityComment(String postId, {required String content, required String idempotencyKey}) => _send(
        'POST',
        '/community/posts/${Uri.encodeComponent(postId)}/comments',
        (d) => (d! as Map<String, dynamic>)['id'] as String,
        body: {'content': content},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> deleteCommunityComment(String id) => _send('DELETE', '/community/comments/${Uri.encodeComponent(id)}', (_) {});

  Future<String> postCommunityStatus({String? imageUrl, String? caption, required String idempotencyKey}) => _send(
        'POST',
        '/community/statuses',
        (d) => (d! as Map<String, dynamic>)['id'] as String,
        body: {'imageUrl': ?imageUrl, 'caption': ?caption},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> deleteCommunityStatus(String id) => _send('DELETE', '/community/statuses/${Uri.encodeComponent(id)}', (_) {});

  Future<void> postCommunityStatusView(String id) =>
      _send('POST', '/community/statuses/${Uri.encodeComponent(id)}/view', (_) {});

  Future<void> postCommunityBestPlayVote(String nominationId, {required String idempotencyKey}) => _send(
        'POST',
        '/community/best-play/${Uri.encodeComponent(nominationId)}/vote',
        (_) {},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> postCommunityPostReport(String id, {required ReportReasonCode reasonCode, String? note, required String idempotencyKey}) => _send(
        'POST',
        '/community/posts/${Uri.encodeComponent(id)}/report',
        (_) {},
        body: {'reasonCode': reasonCode.wireName, 'note': ?note},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> postCommunityCommentReport(String id, {required ReportReasonCode reasonCode, String? note, required String idempotencyKey}) => _send(
        'POST',
        '/community/comments/${Uri.encodeComponent(id)}/report',
        (_) {},
        body: {'reasonCode': reasonCode.wireName, 'note': ?note},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  // --- Phase 5a notifications. All auth: 'user' (never publicRequest), none idempotent. ---

  Future<NotificationPrefs> getNotificationPrefs() =>
      _send('GET', '/notifications/prefs', (d) => NotificationPrefs.fromJson(d! as Map<String, dynamic>));

  Future<NotificationPrefs> patchNotificationPrefs(PrefSection section, Map<String, bool> values) => _send(
        'PATCH',
        '/notifications/prefs',
        (d) => NotificationPrefs.fromJson(d! as Map<String, dynamic>),
        body: {section.wire: values},
      );

  Future<NotificationMutes> getNotificationMutes() =>
      _send('GET', '/notifications/mutes', (d) => NotificationMutes.fromJson(d! as Map<String, dynamic>));

  Future<void> muteNotificationType(String type, MuteDuration duration) =>
      _send('POST', '/notifications/mutes', (_) {}, body: {'scope': 'type', 'type': type, 'duration': duration.wire});

  Future<void> muteNotificationPost(String postId, MuteDuration duration) =>
      _send('POST', '/notifications/mutes', (_) {}, body: {'scope': 'post', 'postId': postId, 'duration': duration.wire});

  Future<void> unmuteNotificationType(String type) =>
      _send('DELETE', '/notifications/mutes', (_) {}, body: {'scope': 'type', 'type': type});

  Future<void> unmuteNotificationPost(String postId) =>
      _send('DELETE', '/notifications/mutes', (_) {}, body: {'scope': 'post', 'postId': postId});

  Future<void> markNotificationRead(String id) =>
      _send('POST', '/notifications/${Uri.encodeComponent(id)}/read', (_) {});

  Future<int> markAllNotificationsRead() => _send(
        'POST',
        '/notifications/read-all',
        (d) => ((d! as Map<String, dynamic>)['updated'] as num).toInt(),
      );

  Future<void> sendTestPush() => _send('POST', '/notifications/test-push', (_) {});

  // --- Phase 5b direct messages. All auth: 'user' (never publicRequest). Only send and forward are idempotent. ---

  Future<ThreadsPage> getMessageThreads({String? cursor, String box = 'inbox'}) => _send(
        'GET',
        _withQuery('/messages/threads', {'box': box, 'cursor': cursor}),
        (d) => ThreadsPage.fromJson(d! as Map<String, dynamic>),
      );

  Future<ThreadHeader> getMessageThread(String threadId) => _send(
        'GET',
        '/messages/threads/${Uri.encodeComponent(threadId)}',
        (d) => ThreadHeader.fromJson(d! as Map<String, dynamic>),
      );

  Future<MessagesPage> getThreadMessages(String threadId, {String? before}) => _send(
        'GET',
        _withQuery('/messages/threads/${Uri.encodeComponent(threadId)}/messages', {'before': before}),
        (d) => MessagesPage.fromJson(d! as Map<String, dynamic>),
      );

  Future<({String threadId, RequestState requestState})> startMessageThread(String recipientId) => _send(
        'POST',
        '/messages/threads',
        (d) {
          final m = d! as Map<String, dynamic>;
          return (threadId: m['threadId'] as String, requestState: parseRequestState(m['requestState']));
        },
        body: {'recipientId': recipientId},
      );

  Future<({String messageId, DateTime createdAt})> sendMessage(
    String threadId, {
    String? body,
    String? imagePath,
    String? stickerId,
    String? audioPath,
    int? audioDurationSeconds,
    String? replyToId,
    required String idempotencyKey,
  }) =>
      _send(
        'POST',
        '/messages/threads/${Uri.encodeComponent(threadId)}/messages',
        (d) {
          final m = d! as Map<String, dynamic>;
          return (messageId: m['messageId'] as String, createdAt: DateTime.parse(m['createdAt'] as String));
        },
        body: {
          'body': ?body,
          'imagePath': ?imagePath,
          'stickerId': ?stickerId,
          'audioPath': ?audioPath,
          'audioDurationSeconds': ?audioDurationSeconds,
          'replyToId': ?replyToId,
        },
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> editMessage(String messageId, String body) =>
      _send('PATCH', '/messages/${Uri.encodeComponent(messageId)}', (_) {}, body: {'body': body});

  Future<void> unsendMessage(String messageId) => _send('DELETE', '/messages/${Uri.encodeComponent(messageId)}', (_) {});

  Future<String> forwardMessage(String messageId, {required String toThreadId, required String idempotencyKey}) => _send(
        'POST',
        '/messages/${Uri.encodeComponent(messageId)}/forward',
        (d) => (d! as Map<String, dynamic>)['messageId'] as String,
        body: {'toThreadId': toThreadId},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> markThreadRead(String threadId) =>
      _send('POST', '/messages/threads/${Uri.encodeComponent(threadId)}/read', (_) {});

  Future<void> markAllDelivered() => _send('POST', '/messages/delivered', (_) {});

  Future<void> blockPlayer(String playerId) => _send('PUT', '/messages/blocks/${Uri.encodeComponent(playerId)}', (_) {});

  Future<void> unblockPlayer(String playerId) =>
      _send('DELETE', '/messages/blocks/${Uri.encodeComponent(playerId)}', (_) {});

  Future<void> reportThread(String threadId, {String? messageId, required String reason}) => _send(
        'POST',
        '/messages/threads/${Uri.encodeComponent(threadId)}/report',
        (_) {},
        body: {'reason': reason, 'messageId': ?messageId},
      );

  Future<void> acceptMessageRequest(String threadId) =>
      _send('POST', '/messages/threads/${Uri.encodeComponent(threadId)}/accept', (_) {});

  Future<void> declineMessageRequest(String threadId) =>
      _send('POST', '/messages/threads/${Uri.encodeComponent(threadId)}/decline', (_) {});

  Future<GuideQuests> getGuideQuests() => _send('GET', '/guide/quests', (d) => GuideQuests.fromJson(d! as Map<String, dynamic>));

  Future<BadgeClaim> postGuideBadge() =>
      _send('POST', '/guide/badge', (d) => BadgeClaim.fromJson(d! as Map<String, dynamic>), body: {'quest': 'battle_ready'});

  Future<ChatHistoryPage> getChatHistory({String? before, int? limit}) => _send(
        'GET',
        _withQuery('/chat/history', {'before': before, 'limit': limit}),
        (d) => ChatHistoryPage.fromJson(d! as Map<String, dynamic>),
      );

  Future<void> deleteChatHistory() => _send('DELETE', '/chat/history', (_) {});

  /// Streams NDJSON events. Pre-stream failures (rate limit, unavailable, 401) throw [ApiException]; once the
  /// stream has started a dropped connection simply ends it, and the caller treats "ended without a terminal
  /// event" as an interrupted turn. Signed-out callers get no bearer (the interceptor sends one only when a
  /// session exists) and should pass [deviceId].
  Stream<ChatEvent> postChatMessage({
    required List<ChatTurnMessage> messages,
    required String clientTurnId,
    required String locale,
    String? deviceId,
  }) async* {
    final Response<ResponseBody> res;
    try {
      res = await _dio.request<ResponseBody>(
        '$_base/chat/messages',
        data: {'messages': messages.map((m) => m.toJson()).toList(), 'clientTurnId': clientTurnId, 'locale': locale},
        options: Options(
          method: 'POST',
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 60),
          headers: {'X-Device-Id': ?deviceId},
        ),
      );
    } on DioException catch (e) {
      throw ApiException(status: 0, code: 'network', message: e.message ?? 'Network error');
    }
    final status = res.statusCode ?? 0;
    final body = res.data;
    if (body == null) throw ApiException(status: status, code: 'bad_response', message: 'Unexpected response ($status).');
    if (status != 200) {
      String text = '';
      try {
        text = await body.stream.cast<List<int>>().transform(utf8.decoder).join();
      } catch (_) {}
      Object? json;
      try {
        json = jsonDecode(text);
      } catch (_) {}
      if (json is Map<String, dynamic> && json['error'] is Map<String, dynamic>) {
        final err = json['error'] as Map<String, dynamic>;
        throw ApiException(
          status: status,
          code: err['code'] as String? ?? 'unknown',
          message: err['message'] as String? ?? 'Request failed',
          fields: (err['fields'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? const <String, String>{},
        );
      }
      throw ApiException(status: status, code: 'bad_response', message: 'Unexpected response ($status).');
    }
    try {
      await for (final line in body.stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter())) {
        final e = parseChatLine(line);
        if (e != null) yield e;
      }
    } catch (_) {
      return; // dropped mid-stream: end without a terminal event
    }
  }
}
