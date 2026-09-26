import 'package:dio/dio.dart';

import '../config/remote_config.dart';
import 'compete_models.dart';
import 'match_models.dart';
import 'models.dart';
import 'players_models.dart';
import 'progress_models.dart';

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
          final token = await accessToken();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
    return ApiClient(dio: dio);
  }

  Future<T> _send<T>(String method, String path, T Function(Object? data) parse,
      {Object? body, Map<String, String>? headers}) async {
    final Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        '$_base$path',
        data: body,
        options: Options(method: method, responseType: ResponseType.json, headers: headers),
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
  );

  Future<SeasonDetail> getSeasonDetail(String slug) => _send(
    'GET',
    '/seasons/${Uri.encodeComponent(slug)}',
    (d) => SeasonDetail.fromJson(d! as Map<String, dynamic>),
  );

  Future<HallOfFame> getHallOfFame({String? game}) => _send(
    'GET',
    _withQuery('/hall-of-fame', {'game': game}),
    (d) => HallOfFame.fromJson(d! as Map<String, dynamic>),
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
}
