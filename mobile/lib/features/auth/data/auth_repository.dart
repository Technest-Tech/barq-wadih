import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_user.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio:     ref.watch(dioProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

// ── Repository ────────────────────────────────────────────────────────────────

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  const AuthRepository({required Dio dio, required FlutterSecureStorage storage})
      : _dio = dio,
        _storage = storage;

  // ── Register ──────────────────────────────────────────────────────────────

  Future<({AuthUser user, String token})> register({
    required String name,
    required String phone,
    String? email,
    String? password,
    String locale = 'ar',
  }) async {
    final res = await _post('/auth/register', {
      'name':     name,
      'phone':    phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (password != null) 'password': password,
      if (password != null) 'password_confirmation': password,
      'locale':   locale,
    });
    return _parseAuthResponse(res);
  }

  // ── Email + Password Login ────────────────────────────────────────────────

  Future<({AuthUser user, String token})> login({
    required String email,
    required String password,
  }) async {
    final res = await _post('/auth/login', {'email': email, 'password': password});
    return _parseAuthResponse(res);
  }

  // ── Firebase Token Login ──────────────────────────────────────────────────

  Future<({AuthUser user, String token, bool isNew})> loginWithFirebase({
    required String idToken,
    String? name,
    String locale = 'ar',
  }) async {
    final res = await _post('/auth/firebase', {
      'firebase_id_token': idToken,
      if (name != null) 'name': name,
      'locale': locale,
    });
    final data = res.data as Map<String, dynamic>;
    return (
      user:  AuthUser.fromJson(data['user'] as Map<String, dynamic>),
      token: data['token'] as String,
      isNew: data['is_new'] as bool? ?? false,
    );
  }

  // ── Get Current User ──────────────────────────────────────────────────────

  Future<AuthUser> me() async {
    try {
      final response = await _dio.get('/auth/me');
      final body = response.data as Map<String, dynamic>;
      return AuthUser.fromJson(body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ── Update Profile ─────────────────────────────────────────────────────────

  Future<AuthUser> updateProfile({
    required String name,
    String? bio,
    String? email,
    int? regionId,
    int? cityId,
  }) async {
    final data = <String, dynamic>{'name': name};
    if (bio != null)      data['bio']       = bio;
    if (email != null)    data['email']     = email;
    if (regionId != null) data['region_id'] = regionId;
    if (cityId != null)   data['city_id']   = cityId;
    final res  = await _put('/auth/me', data);
    final body = res.data as Map<String, dynamic>;
    return AuthUser.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── Upload Avatar ──────────────────────────────────────────────────────────

  Future<void> uploadAvatar(XFile file) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          file.path, filename: file.name),
      });
      await _dio.post('/auth/me/avatar', data: formData);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // Best-effort — clear token regardless
    } finally {
      await _storage.delete(key: 'auth_token');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<Response> _post(String path, Map<String, dynamic> body) async {
    try {
      return await _dio.post(path, data: body);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> _put(String path, Map<String, dynamic> body) async {
    try {
      return await _dio.put(path, data: body);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ({AuthUser user, String token}) _parseAuthResponse(Response res) {
    final body = res.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return (
      user:  AuthUser.fromJson(data['user'] as Map<String, dynamic>),
      token: data['token'] as String,
    );
  }

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    final message = data is Map ? (data['message'] as String?) ?? e.message ?? 'خطأ في الشبكة' : e.message ?? 'خطأ في الشبكة';
    return ApiException(message: message, statusCode: e.response?.statusCode);
  }
}
