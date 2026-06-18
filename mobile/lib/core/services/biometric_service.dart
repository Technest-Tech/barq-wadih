import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper around [LocalAuthentication] for fingerprint / Face ID login.
///
/// Biometrics are a *local device gate* — they do not authenticate against the
/// backend on their own. The flow is: the user signs in once with
/// email/password (which yields a server token stored in secure storage), opts
/// into biometric login, and on subsequent app starts a successful fingerprint
/// scan unlocks that stored token instead of re-typing credentials.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Whether the device has biometric hardware that the OS can use *and* the
  /// user has enrolled at least one fingerprint / face.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Prompt the OS biometric sheet. Returns `true` only on a successful scan.
  /// Any failure, cancellation, or unavailable hardware returns `false`.
  Future<bool> authenticate({
    String reason = 'استخدم بصمتك للدخول إلى حسابك',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
