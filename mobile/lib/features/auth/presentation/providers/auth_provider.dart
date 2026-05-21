import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../notifications/data/notification_providers.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_user.dart';

// ── State ─────────────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final AuthUser user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

// ── Notifier (Riverpod 3.x API) ───────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repo;
  late final FlutterSecureStorage _storage;

  @override
  AuthState build() {
    _repo = ref.read(authRepositoryProvider);
    _storage = ref.read(secureStorageProvider);
    _init();
    return const AuthInitial();
  }

  // ── Startup validation ────────────────────────────────────────────────────

  Future<void> _init() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      state = const AuthUnauthenticated();
      return;
    }
    try {
      state = const AuthLoading();
      final user = await _repo.me();
      state = AuthAuthenticated(user);
      // Re-register FCM token on each app start when already authenticated.
      FCMService.instance.registerToken(
        ref.read(notificationRepositoryProvider),
      );
    } catch (_) {
      await _storage.delete(key: 'auth_token');
      state = const AuthUnauthenticated();
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────

  Future<void> register({
    required String name,
    String? phone,
    String? email,
    String? password,
  }) async {
    state = const AuthLoading();
    try {
      final result = await _repo.register(
        name: name,
        phone: phone,
        email: email,
        password: password,
      );
      await _storage.write(key: 'auth_token', value: result.token);
      state = AuthAuthenticated(result.user);
      FCMService.instance.registerToken(
        ref.read(notificationRepositoryProvider),
      );
    } on ApiException catch (e) {
      state = AuthError(e.message);
    }
  }

  // ── Email Login ───────────────────────────────────────────────────────────

  Future<void> login({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      final result = await _repo.login(email: email, password: password);
      await _storage.write(key: 'auth_token', value: result.token);
      state = AuthAuthenticated(result.user);
      FCMService.instance.registerToken(
        ref.read(notificationRepositoryProvider),
      );
    } on ApiException catch (e) {
      state = AuthError(e.message);
    } catch (_) {
      state = const AuthError('بيانات الدخول غير صحيحة');
    }
  }

  // ── Firebase Token ────────────────────────────────────────────────────────

  Future<void> loginWithFirebase({
    required String idToken,
    String? name,
  }) async {
    state = const AuthLoading();
    try {
      final result = await _repo.loginWithFirebase(
        idToken: idToken,
        name: name,
      );
      await _storage.write(key: 'auth_token', value: result.token);
      state = AuthAuthenticated(result.user);
      FCMService.instance.registerToken(
        ref.read(notificationRepositoryProvider),
      );
    } on ApiException catch (e) {
      state = AuthError(e.message);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await FCMService.instance.deregisterToken(
      ref.read(notificationRepositoryProvider),
    );
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  void clearError() {
    if (state is AuthError) state = const AuthUnauthenticated();
  }

  void refreshUser(AuthUser user) {
    state = AuthAuthenticated(user);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

// ── Convenience selectors ─────────────────────────────────────────────────────

final currentUserProvider = Provider<AuthUser?>((ref) {
  final s = ref.watch(authProvider);
  return s is AuthAuthenticated ? s.user : null;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) is AuthAuthenticated;
});
