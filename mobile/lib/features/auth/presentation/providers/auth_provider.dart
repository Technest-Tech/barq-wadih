import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../notifications/data/notification_providers.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_user.dart';

// Secure-storage keys.
const _kAuthToken = 'auth_token';
// Credentials saved (encrypted) so fingerprint login can re-authenticate after
// the active token is gone — e.g. after logout, which revokes it server-side.
const _kBioEmail = 'biometric_email';
const _kBioPassword = 'biometric_password';

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
    final token = await _storage.read(key: _kAuthToken);
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
      await _storage.delete(key: _kAuthToken);
      state = const AuthUnauthenticated();
    }
  }

  // ── Biometric (fingerprint / Face ID) Login ───────────────────────────────

  /// Prompt the OS biometric sheet and, on success, re-authenticate with the
  /// saved credentials to mint a fresh token. Works even after logout, since
  /// the credentials persist while the server token does not.
  Future<void> loginWithBiometrics() async {
    final email = await _storage.read(key: _kBioEmail);
    final password = await _storage.read(key: _kBioPassword);
    if (email == null || password == null) {
      // No saved credentials yet — the user must sign in with email once so
      // fingerprint login has something to unlock.
      state = const AuthError(
        'سجّل الدخول بالبريد الإلكتروني أولاً لتفعيل الدخول بالبصمة',
      );
      return;
    }
    final ok = await BiometricService.instance.authenticate();
    if (!ok) {
      state = const AuthUnauthenticated();
      return;
    }
    state = const AuthLoading();
    try {
      final result = await _repo.login(email: email, password: password);
      await _storage.write(key: _kAuthToken, value: result.token);
      state = AuthAuthenticated(result.user);
      FCMService.instance.registerToken(
        ref.read(notificationRepositoryProvider),
      );
    } on ApiException catch (e) {
      // Stored credentials no longer valid (e.g. password changed) — clear them
      // so the user falls back to the email form.
      await _clearBiometricCredentials();
      state = AuthError(e.message);
    } catch (_) {
      state = const AuthError('تعذّر الدخول بالبصمة');
    }
  }

  /// Save credentials (encrypted) so fingerprint login can re-authenticate
  /// later. Only when the device supports biometrics and we have both fields.
  Future<void> _saveBiometricCredentials(
    String? email,
    String? password,
  ) async {
    if (email == null || email.isEmpty || password == null) return;
    if (!await BiometricService.instance.isAvailable()) return;
    await _storage.write(key: _kBioEmail, value: email);
    await _storage.write(key: _kBioPassword, value: password);
  }

  Future<void> _clearBiometricCredentials() async {
    await _storage.delete(key: _kBioEmail);
    await _storage.delete(key: _kBioPassword);
  }

  /// Turn off fingerprint login and forget the saved credentials.
  Future<void> disableBiometrics() => _clearBiometricCredentials();

  /// Whether fingerprint login is currently set up (credentials saved).
  Future<bool> isBiometricEnabled() async {
    return await _storage.read(key: _kBioEmail) != null;
  }

  /// Confirm the user's fingerprint and, on success, save their credentials so
  /// they can sign in with a fingerprint later. Returns `true` when enabled.
  Future<bool> setupBiometrics({
    required String email,
    required String password,
  }) async {
    if (!await BiometricService.instance.isAvailable()) return false;
    final ok = await BiometricService.instance.authenticate(
      reason: 'أكّد بصمتك لتفعيل الدخول السريع لاحقًا',
    );
    if (!ok) return false;
    await _storage.write(key: _kBioEmail, value: email);
    await _storage.write(key: _kBioPassword, value: password);
    return true;
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
      await _storage.write(key: _kAuthToken, value: result.token);
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
      await _storage.write(key: _kAuthToken, value: result.token);
      // Save credentials so fingerprint login works on subsequent sign-ins.
      await _saveBiometricCredentials(email, password);
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
      await _storage.write(key: _kAuthToken, value: result.token);
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
    // Keep the saved biometric credentials so the user can sign back in with a
    // fingerprint. Only the active session token is cleared (by _repo.logout).
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

/// Whether the current device has biometrics enrolled and usable. Drives
/// whether the login screen shows the fingerprint button at all.
final biometricSupportedProvider = FutureProvider<bool>((ref) {
  return BiometricService.instance.isAvailable();
});
