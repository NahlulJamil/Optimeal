import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

/// Sesi aktif. Gate di `main.dart` memakai ini untuk memilih layar.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Aksi autentikasi beserta status loading/error untuk form.
final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Pesan error siap tampil, atau `null` bila tidak ada.
  String? get errorMessage {
    if (!state.hasError) return null;
    final error = state.error;
    return error is AuthFailure
        ? error.message
        : 'Something went wrong. Please try again.';
  }

  /// Kesalahan terakhir, atau `null`. Dipakai Login untuk membedakan error
  /// kredensial (inline di bawah field sandi) dari error umum (banner).
  AuthFailure? get failure {
    if (!state.hasError) return null;
    final error = state.error;
    return error is AuthFailure ? error : null;
  }

  bool get hasCredentialError => failure?.isCredential ?? false;

  void clearError() {
    if (state.hasError) state = const AsyncData(null);
  }

  Future<bool> signIn({required String email, required String password}) async {
    return _run(() => _repo.signIn(email: email, password: password));
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return _run(
      () => _repo.register(name: name, email: email, password: password),
    );
  }

  Future<bool> sendVerificationEmail() {
    return _run(_repo.sendVerificationEmail);
  }

  /// Mengirim tautan reset sandi. `true` bila permintaan berhasil dikirim.
  Future<bool> sendPasswordReset(String email) {
    return _run(() => _repo.sendPasswordReset(email));
  }

  Future<bool> changePassword({
    required String newPassword,
    String? currentPassword,
  }) {
    return _run(
      () => _repo.changePassword(
        newPassword: newPassword,
        currentPassword: currentPassword,
      ),
    );
  }

  /// `true` bila email sudah terverifikasi.
  Future<bool> checkEmailVerified() async {
    try {
      final verified = await _repo.refreshEmailVerified();
      if (verified) {
        // Membuat stream auth membaca ulang user yang sudah di-reload,
        // sehingga gate langsung berpindah ke Home.
        ref.invalidate(authStateProvider);
      }
      return verified;
    } on AuthFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _repo.signOut();
      state = const AsyncData(null);
    } on FirebaseAuthException catch (error) {
      state = AsyncError(AuthFailure.fromCode(error.code), StackTrace.current);
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } on AuthFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    } catch (error, stackTrace) {
      state = AsyncError(
        const AuthFailure('Something went wrong. Please try again.'),
        stackTrace,
      );
      return false;
    }
  }
}
