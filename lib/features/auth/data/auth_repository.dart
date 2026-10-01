import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/app_error_reporter.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Stream<Session?> authStateChanges() =>
      _client.auth.onAuthStateChange.map((event) => event.session);

  Future<void> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const AuthFailure('Email and password are required.');
    }

    try {
      await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
    } on AuthApiException catch (error) {
      AppErrorReporter.report(
        error,
        feature: 'auth',
        operation: 'signIn',
        context: <String, Object?>{
          'code': error.code,
          'email': normalizedEmail,
        },
      );
      if (error.code == 'invalid_credentials') {
        throw const AuthFailure('Invalid email or password.');
      }
      if (error.code == 'email_not_confirmed') {
        throw const AuthFailure('Please verify your email address first.');
      }
      throw AuthFailure(error.message);
    } on AuthException catch (error) {
      AppErrorReporter.report(
        error,
        feature: 'auth',
        operation: 'signIn',
        context: <String, Object?>{'email': normalizedEmail},
      );
      throw AuthFailure(error.message);
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const AuthFailure('Email and password are required.');
    }

    try {
      await _client.auth.signUp(email: normalizedEmail, password: password);
    } on AuthApiException catch (error) {
      AppErrorReporter.report(
        error,
        feature: 'auth',
        operation: 'signUp',
        context: <String, Object?>{
          'code': error.code,
          'email': normalizedEmail,
        },
      );
      if (error.code == 'user_already_exists') {
        throw const AuthFailure('An account with this email already exists.');
      }
      throw AuthFailure(error.message);
    } on AuthException catch (error) {
      AppErrorReporter.report(
        error,
        feature: 'auth',
        operation: 'signUp',
        context: <String, Object?>{'email': normalizedEmail},
      );
      throw AuthFailure(error.message);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: null,
      );
    } on AuthException catch (error) {
      AppErrorReporter.report(
        error,
        feature: 'auth',
        operation: 'signInWithGoogle',
      );
      throw AuthFailure(error.message);
    }
  }

  Future<void> requestPhoneOtp({required String phone}) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) {
      throw const AuthFailure('Phone number is required.');
    }

    try {
      await _client.auth.signInWithOtp(phone: normalizedPhone);
    } on AuthException catch (error) {
      AppErrorReporter.report(
        error,
        feature: 'auth',
        operation: 'requestPhoneOtp',
        context: <String, Object?>{'phone': normalizedPhone},
      );
      throw AuthFailure(error.message);
    }
  }

  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    final normalizedPhone = phone.trim();
    final normalizedToken = token.trim();

    if (normalizedPhone.isEmpty || normalizedToken.isEmpty) {
      throw const AuthFailure('Phone number and OTP code are required.');
    }

    try {
      await _client.auth.verifyOTP(
        phone: normalizedPhone,
        token: normalizedToken,
        type: OtpType.sms,
      );
    } on AuthException catch (error) {
      AppErrorReporter.report(
        error,
        feature: 'auth',
        operation: 'verifyPhoneOtp',
        context: <String, Object?>{'phone': normalizedPhone},
      );
      throw AuthFailure(error.message);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
