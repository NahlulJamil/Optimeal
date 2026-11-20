/// Aturan validasi form autentikasi.
///
/// Dipisah dari widget supaya bisa diuji tanpa Firebase (DevelopmentPlan
/// prinsip "contract-first"): aturan yang sama dipakai Login dan Registrasi.
library;

final RegExp _emailPattern = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$",
);

/// Minimal 8 karakter, mengandung huruf dan angka.
const int kMinPasswordLength = 8;

/// Mengembalikan pesan error (English, sesuai keputusan UI English-only) atau
/// `null` bila valid.
String? validateEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return 'Enter your email address.';
  if (!_emailPattern.hasMatch(email)) return 'That email address is not valid.';
  return null;
}

String? validatePassword(String? value, {bool requireStrength = true}) {
  final password = value ?? '';
  if (password.isEmpty) return 'Enter your password.';
  if (!requireStrength) return null;
  if (password.length < kMinPasswordLength) {
    return 'Use at least $kMinPasswordLength characters.';
  }
  if (!password.contains(RegExp(r'[A-Za-z]'))) {
    return 'Include at least one letter.';
  }
  if (!password.contains(RegExp(r'[0-9]'))) {
    return 'Include at least one number.';
  }
  return null;
}

String? validateName(String? value) {
  final name = (value ?? '').trim();
  if (name.isEmpty) return 'Enter your name.';
  if (name.length < 2) return 'Name is too short.';
  if (name.length > 60) return 'Name is too long.';
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if ((value ?? '').isEmpty) return 'Repeat your password.';
  if (value != password) return 'Passwords do not match.';
  return null;
}
