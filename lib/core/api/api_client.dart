import 'package:dio/dio.dart';

import '../config/remote_config.dart';
import 'models.dart';
import 'progress_models.dart';

class ApiException implements Exception {
  const ApiException({required this.status, required this.code, required this.message, this.fields = const {}});

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
    'postAuthResendConfirmation': 'post /api/mobile/v1/auth/resend-confirmation',
    'postAuthRequestReset': 'post /api/mobile/v1/auth/request-reset',
    'postSessionStart': 'post /api/mobile/v1/session/start',
    'postOnboardingUsername': 'post /api/mobile/v1/onboarding/username',
    'getHome': 'get /api/mobile/v1/home',
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
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (_) => true, // every status is decoded by _send
      headers: {'X-App-Version': appVersion, 'X-Platform': platform},
    ));
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
    return ApiClient(dio: dio);
  }

  Future<T> _send<T>(String method, String path, T Function(Object? data) parse, {Object? body}) async {
    final Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        '$_base$path',
        data: body,
        options: Options(method: method, responseType: ResponseType.json),
      );
    } on DioException catch (e) {
      throw ApiException(status: 0, code: 'network', message: e.message ?? 'Network error');
    }

    final status = res.statusCode ?? 0;
    final json = res.data;
    if (status >= 200 && status < 300 && json is Map<String, dynamic> && json.containsKey('data')) {
      try {
        return parse(json['data']);
      } catch (_) {
        throw ApiException(status: status, code: 'bad_response', message: 'Could not read the server response.');
      }
    }
    if (json is Map<String, dynamic> && json['error'] is Map<String, dynamic>) {
      final err = json['error'] as Map<String, dynamic>;
      final fields = (err['fields'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? const <String, String>{};
      throw ApiException(
        status: status,
        code: err['code'] as String? ?? 'unknown',
        message: err['message'] as String? ?? 'Request failed',
        fields: fields,
      );
    }
    throw ApiException(status: status, code: 'bad_response', message: 'Unexpected response ($status).');
  }

  Future<RemoteConfig> getConfig() =>
      _send('GET', '/config', (d) => RemoteConfig.fromJson(d! as Map<String, dynamic>));

  Future<MeResponse> getMe() => _send('GET', '/me', (d) => MeResponse.fromJson(d! as Map<String, dynamic>));

  Future<void> postClientError({
    required String message,
    String? stack,
    String? route,
    required String platform,
    required String appVersion,
    String? locale,
  }) =>
      _send('POST', '/errors', (_) {}, body: {
        'message': message,
        'stack': ?stack,
        'route': ?route,
        'platform': platform,
        'appVersion': appVersion,
        'locale': ?locale,
      });

  Future<void> registerDevice({required String token, required String platform, required String appVersion}) =>
      _send('POST', '/devices', (_) {}, body: {'token': token, 'platform': platform, 'appVersion': appVersion});

  Future<void> unregisterDevice(String token) => _send('DELETE', '/devices', (_) {}, body: {'token': token});

  Future<void> postAuthSignup({
    required String username,
    required String email,
    required String password,
    String? ref,
    String? locale,
  }) =>
      _send('POST', '/auth/signup', (_) {}, body: {
        'username': username,
        'email': email,
        'password': password,
        'ref': ?ref,
        'locale': ?locale,
      });

  Future<void> postAuthResendConfirmation(String email) =>
      _send('POST', '/auth/resend-confirmation', (_) {}, body: {'email': email});

  Future<void> postAuthRequestReset(String email) =>
      _send('POST', '/auth/request-reset', (_) {}, body: {'email': email});

  Future<SessionStartResponse> postSessionStart() =>
      _send('POST', '/session/start', (d) => SessionStartResponse.fromJson(d! as Map<String, dynamic>));

  Future<String> postOnboardingUsername(String username) => _send(
        'POST',
        '/onboarding/username',
        (d) => (d! as Map<String, dynamic>)['username'] as String,
        body: {'username': username},
      );

  Future<HomeSummary> getHome() => _send('GET', '/home', (d) => HomeSummary.fromJson(d! as Map<String, dynamic>));

  String _withQuery(String path, Map<String, Object?> query) {
    final q = <String, String>{
      for (final e in query.entries)
        if (e.value != null) e.key: e.value.toString(),
    };
    return q.isEmpty ? path : Uri(path: path, queryParameters: q).toString();
  }

  Future<RankingsPage> getRankings({String? game, String? region, int page = 1}) => _send(
        'GET',
        _withQuery('/rankings', {'game': game, 'region': region, 'page': page > 1 ? page : null}),
        (d) => RankingsPage.fromJson(d! as Map<String, dynamic>),
      );

  Future<RankingsMe> getRankingsMe({String? game, String? region}) => _send(
        'GET',
        _withQuery('/rankings/me', {'game': game, 'region': region}),
        (d) => RankingsMe.fromJson(d! as Map<String, dynamic>),
      );

  Future<List<SeasonSummary>> getSeasons() => _send(
        'GET',
        '/seasons',
        (d) => ((d! as Map<String, dynamic>)['seasons'] as List<dynamic>)
            .map((e) => SeasonSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<SeasonDetail> getSeasonDetail(String slug) =>
      _send('GET', '/seasons/${Uri.encodeComponent(slug)}', (d) => SeasonDetail.fromJson(d! as Map<String, dynamic>));

  Future<HallOfFame> getHallOfFame({String? game}) => _send(
        'GET',
        _withQuery('/hall-of-fame', {'game': game}),
        (d) => HallOfFame.fromJson(d! as Map<String, dynamic>),
      );
}
