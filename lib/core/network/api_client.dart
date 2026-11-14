import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../app_config.dart';
import '../telemetry/logger.dart';

abstract interface class TokenStorage {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> deleteToken();
}

class SecureTokenStorage implements TokenStorage {
  static const String _tokenKey = 'auth_token';
  final FlutterSecureStorage _storage;

  const SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  @override
  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
  }

  @override
  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }
}

class InMemoryTokenStorage implements TokenStorage {
  String? _token;

  InMemoryTokenStorage([this._token]);

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }

  @override
  Future<void> deleteToken() async {
    _token = null;
  }
}

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  const ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class ApiClient {
  final Dio _dio;
  final TokenStorage _tokenStorage;
  String _apiBaseUrl;
  String _loginUrl;

  ApiClient({
    Dio? dio,
    TokenStorage? tokenStorage,
    String? apiBaseUrl,
    String? loginUrl,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 25),
                responseType: ResponseType.plain,
              ),
            ),
        _tokenStorage = tokenStorage ?? const SecureTokenStorage(),
        _apiBaseUrl = (apiBaseUrl ?? AppConfig.apiBaseUrl)
            .replaceAll(RegExp(r'/+$'), ''),
        _loginUrl = loginUrl ?? AppConfig.loginUrl;

  String get apiBaseUrl => _apiBaseUrl;
  String get loginUrl => _loginUrl;
  TokenStorage get tokenStorage => _tokenStorage;

  void updateEndpoints({required String apiBaseUrl, String? loginUrl}) {
    final cleanBase = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _apiBaseUrl = cleanBase.endsWith('/api') ? cleanBase : '$cleanBase/api';
    if (loginUrl != null && loginUrl.trim().isNotEmpty) {
      _loginUrl = loginUrl.trim();
    } else {
      final hostRoot = _apiBaseUrl.substring(0, _apiBaseUrl.length - 4);
      _loginUrl = '$hostRoot/login';
    }
  }

  /// Offloads JSON decoding to a background worker Isolate when payload > 10 KB
  static Future<Map<String, dynamic>> decodeJsonMap(String raw) async {
    if (raw.length > 10240) {
      return Isolate.run(() {
        final decoded = jsonDecode(raw);
        return decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{'data': decoded};
      });
    }
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
  }

  Future<Map<String, String>> _buildHeaders([
    Map<String, String>? extra,
  ]) async {
    final token = await _tokenStorage.readToken();
    return <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final headers = await _buildHeaders();
    final url = '$_apiBaseUrl$endpoint';
    Object? lastErr;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final res = await _dio.get<String>(
          url,
          queryParameters: queryParameters,
          options: Options(headers: headers),
        );
        return await decodeJsonMap(res.data ?? '{}');
      } on DioException catch (e) {
        lastErr = e;
        if (e.response?.statusCode == 401) {
          throw const ApiException('Unauthorized', statusCode: 401);
        }
        if (e.response != null) {
          throw _extractDioError(e);
        }
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: attempt * 250));
        }
      } catch (e) {
        lastErr = e;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: attempt * 250));
        }
      }
    }
    throw ApiException(lastErr?.toString() ?? 'Network request failed');
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _buildHeaders({'Content-Type': 'application/json'});
    final url = '$_apiBaseUrl$endpoint';
    try {
      final res = await _dio.post<String>(
        url,
        data: body != null ? jsonEncode(body) : null,
        options: Options(headers: headers),
      );
      return await decodeJsonMap(res.data ?? '{}');
    } on DioException catch (e) {
      throw _extractDioError(e);
    }
  }

  Future<Map<String, dynamic>> put(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    final headers = await _buildHeaders({'Content-Type': 'application/json'});
    final url = '$_apiBaseUrl$endpoint';
    try {
      final res = await _dio.put<String>(
        url,
        data: jsonEncode(body),
        options: Options(headers: headers),
      );
      return await decodeJsonMap(res.data ?? '{}');
    } on DioException catch (e) {
      throw _extractDioError(e);
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    final headers = await _buildHeaders();
    final url = '$_apiBaseUrl$endpoint';
    try {
      final res = await _dio.delete<String>(
        url,
        options: Options(headers: headers),
      );
      return await decodeJsonMap(res.data ?? '{}');
    } on DioException catch (e) {
      throw _extractDioError(e);
    }
  }

  /// Opens a real-time Server-Sent Events (SSE) stream to `/api/stream/{guildId}`.
  Stream<Map<String, dynamic>> connectQueueSse(String guildId) async* {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) return;

    final streamUrl =
        '$_apiBaseUrl/stream/$guildId?token=${Uri.encodeQueryComponent(token)}';
    try {
      final response = await _dio.get<ResponseBody>(
        streamUrl,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(hours: 2),
          headers: const {
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
        ),
      );

      final stream = response.data?.stream;
      if (stream == null) return;

      final lines = stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.startsWith('data:')) {
          final payload = line.substring(5).trim();
          if (payload.isNotEmpty) {
            try {
              final map = await decodeJsonMap(payload);
              yield map;
            } catch (err) {
              AppLogger.warning('SSE frame parse error', err);
            }
          }
        }
      }
    } catch (err) {
      AppLogger.warning('SSE stream closed or errored', err);
      rethrow;
    }
  }

  ApiException _extractDioError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) {
      return const ApiException('Unauthorized', statusCode: 401);
    }
    final rawData = e.response?.data?.toString() ?? '';
    if (rawData.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawData);
        if (parsed is Map && parsed['detail'] != null) {
          final detail = parsed['detail'];
          return ApiException(
            detail is String ? detail : jsonEncode(detail),
            statusCode: status,
          );
        }
      } catch (_) {
        return ApiException(rawData, statusCode: status);
      }
    }
    return ApiException(
      e.message ?? 'API error: ${status ?? "network"}',
      statusCode: status,
    );
  }
}
