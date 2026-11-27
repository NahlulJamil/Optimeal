import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Kesalahan autentikasi yang sudah diterjemahkan ke bahasa Inggris untuk UI.
///
/// Detail teknis Firebase tidak pernah ditampilkan ke pengguna; hanya pesan
/// ramah di [message] yang dipakai layar Login/Registrasi.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code = 'unknown', this.isCredential = false});

  final String message;
  final String code;

  /// `true` bila kesalahan berasal dari email/sandi yang salah. Dipakai layar
  /// Login untuk menampilkan pesan inline di bawah field sandi (Figma
  /// "Login — sandi salah"), bukan banner umum.
  final bool isCredential;

  /// Pemetaan kode `FirebaseAuthException` ke pesan sesuai PRD §3.1
  /// ("Sistem menampilkan pesan kesalahan apabila autentikasi gagal").
  factory AuthFailure.fromCode(String code) {
    final message = switch (code) {
      'invalid-email' => 'That email address is not valid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' => 'No account found with that email.',
      'wrong-password' ||
      'invalid-credential' => 'Incorrect email or password.',
      'email-already-in-use' => 'An account with that email already exists.',
      'weak-password' => 'Password is too weak. Use at least 8 characters.',
      'too-many-requests' =>
        'Too many attempts. Please wait a moment and try again.',
      'network-request-failed' =>
        'Could not reach the server. Check your connection and try again.',
      'operation-not-allowed' =>
        'Email sign-in is not enabled for this project.',
      'requires-recent-login' => 'Please sign in again to continue.',
      _ => 'Something went wrong. Please try again.',
    };
    return AuthFailure(
      message,
      code: code,
      isCredential: code == 'wrong-password' || code == 'invalid-credential',
    );
  }

  @override
  String toString() => 'AuthFailure($code): $message';
}

/// Satu-satunya pintu ke Firebase Authentication.
///
/// Login/Registrasi di aplikasi memakai email + password. Verifikasi akun
/// memakai link email bawaan Firebase (keputusan 2026-11-20), bukan OTP.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Sesi dipertahankan antar pembukaan aplikasi (PRD §3.1).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure.fromCode(error.code);
    }
  }

  /// Membuat akun, profil `users/{uid}` (Contracts §3.5), lalu mengirim link
  /// verifikasi email.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure.fromCode(error.code);
    }

    final user = credential.user;
    if (user == null) {
      throw const AuthFailure(
        'Account created, but the session could not start. Please sign in.',
      );
    }

    // Akun sudah ada; kegagalan di bawah tidak boleh membuat pengguna
    // kehilangan akunnya, jadi hanya dicatat dan bisa diulang dari Profile.
    final trimmedName = name.trim();
    try {
      await user.updateDisplayName(trimmedName);
    } catch (error) {
      debugPrint('updateDisplayName failed: $error');
    }
    try {
      await _createProfile(user, trimmedName);
    } catch (error) {
      debugPrint('createProfile failed: $error');
    }
    try {
      await user.sendEmailVerification();
    } catch (error) {
      // Layar verifikasi punya tombol Resend.
      debugPrint('sendEmailVerification failed: $error');
    }
  }

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        'Your session has expired. Please sign in again.',
      );
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure.fromCode(error.code);
    }
  }

  /// `true` bila email sudah diverifikasi setelah memuat ulang status user.
  Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure.fromCode(error.code);
    }
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Mengirim tautan reset sandi bawaan Firebase (PRD §3.1, v1.10).
  ///
  /// Firebase tidak mengungkap apakah email terdaftar, sehingga demi keamanan
  /// layar tetap menampilkan pesan sukses meski email tidak ditemukan.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') return;
      throw AuthFailure.fromCode(error.code);
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Updates the Firebase Auth display name for the active session.
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Your session has expired. Please sign in again.');
    }
    try {
      await user.updateDisplayName(name.trim());
      await user.reload();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure.fromCode(error.code);
    }
  }

  /// Updates the user's password. When [currentPassword] is supplied,
  /// re-authenticates first so Firebase accepts the change even after an old
  /// sign-in.
  Future<void> changePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Your session has expired. Please sign in again.');
    }
    try {
      if (currentPassword != null && currentPassword.isNotEmpty) {
        final email = user.email;
        if (email == null || email.isEmpty) {
          throw const AuthFailure('Please sign in again to continue.');
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: email,
            password: currentPassword,
          ),
        );
      }
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure.fromCode(error.code);
    }
  }

  Future<void> _createProfile(User user, String name) {
    return _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'email': user.email ?? '',
      'photoUrl': null,
      'themeMode': 'light',
      'language': 'en',
      'notificationsEnabled': true,
      'notificationThresholdDays': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
