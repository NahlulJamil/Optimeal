import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/auth_providers.dart';
import 'widgets/auth_scaffold.dart';

/// Verifikasi akun memakai link email Firebase (PRD §3.1, keputusan v1.8).
///
/// Tata letak mengikuti Figma frame `305:829` ("Verifikasi registrasi"):
/// badge 88 px, judul rata tengah, tombol pill, hitungan kirim ulang mm:ss,
/// dan kartu bantuan. Kotak OTP 6 digit tidak dipakai karena alur yang
/// disetujui adalah link email.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _cooldownSeconds = 60;

  Timer? _timer;
  int _cooldown = 0;
  bool _checking = false;
  bool _resending = false;
  String? _hint;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  AuthController get _controller => ref.read(authControllerProvider.notifier);

  String get _countdown {
    final minutes = (_cooldown ~/ 60).toString().padLeft(2, '0');
    final seconds = (_cooldown % 60).toString().padLeft(2, '0');
    return 'Resend in $minutes:$seconds';
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _hint = null;
    });
    final verified = await _controller.checkEmailVerified();
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (!verified) {
        _hint = 'Not verified yet. Open the link in your inbox, then try again.';
      }
    });
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _resending) return;
    setState(() {
      _resending = true;
      _hint = null;
    });
    final sent = await _controller.sendVerificationEmail();
    if (!mounted) return;
    setState(() {
      _resending = false;
      if (sent) {
        _hint = 'Verification email sent. Check your inbox.';
        _startCooldown();
      }
    });
  }

  Future<void> _changeEmail() async {
    await _controller.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final error = _controller.errorMessage;
    final busy = _checking || auth.isLoading;

    return AuthScaffold(
      title: 'Check your inbox!',
      subtitleWidget: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Open the verification link we sent to\n'),
            TextSpan(
              text: widget.email,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
        style: AppTextStyles.body,
      ),
      headerIcon: const Icon(
        Icons.mark_email_read_outlined,
        size: 40,
        color: AppColors.primary,
      ),
      alignment: AuthHeaderAlignment.center,
      contentTopPadding: 36,
      headerGap: 32,
      headerTrailing: AuthTextLink(
        label: 'Change email',
        icon: Icons.edit_outlined,
        align: MainAxisAlignment.center,
        onPressed: auth.isLoading ? null : _changeEmail,
      ),
      children: [
        if (error != null) ...[
          AuthErrorBanner(message: error),
        ],
        if (_hint != null) ...[
          AuthInfoCard(text: _hint!),
          const SizedBox(height: 20),
        ],
        AuthSubmitButton(
          label: "I've verified my email",
          busy: busy,
          onPressed: _check,
        ),
        const SizedBox(height: 20),
        Text(
          "Didn't get the email?",
          textAlign: TextAlign.center,
          style: AppTextStyles.linkHint,
        ),
        AuthTextLink(
          label: _cooldown > 0 ? _countdown : 'Send it again',
          align: MainAxisAlignment.center,
          onPressed: _cooldown > 0 || _resending ? null : _resend,
        ),
        const SizedBox(height: 32),
        const AuthInfoCard(
          text:
              'Check your spam or promotions folder and make sure the email '
              'address is correct. The link works only once.',
        ),
      ],
    );
  }
}
