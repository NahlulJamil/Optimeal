import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../application/auth_providers.dart';
import 'widgets/auth_scaffold.dart';

/// Verifikasi akun memakai link email Firebase (keputusan 2026-11-20).
///
/// Pengguna membuka link di inbox, lalu menekan "I've verified my email".
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
    final verified = await ref
        .read(authControllerProvider.notifier)
        .checkEmailVerified();
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (!verified) {
        _hint =
            'Not verified yet. Open the link in your inbox, then try again.';
      }
    });
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _resending) return;
    setState(() {
      _resending = true;
      _hint = null;
    });
    final sent = await ref
        .read(authControllerProvider.notifier)
        .sendVerificationEmail();
    if (!mounted) return;
    setState(() {
      _resending = false;
      if (sent) {
        _hint = 'Verification email sent. Check your inbox.';
        _startCooldown();
      }
    });
  }

  Future<void> _useAnotherAccount() async {
    await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final error = ref.read(authControllerProvider.notifier).errorMessage;
    final busy = _checking || auth.isLoading;

    return AuthScaffold(
      title: 'Verify your email',
      subtitle: 'We sent a verification link to ${widget.email}.',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Step(number: '1', text: 'Open the link in your email inbox.'),
              SizedBox(height: 10),
              _Step(
                number: '2',
                text: "Come back here and tap I've verified my email.",
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (error != null) AuthErrorBanner(message: error),
        if (_hint != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _hint!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
        AuthSubmitButton(
          label: "I've verified my email",
          busy: busy,
          onPressed: _check,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _cooldown > 0 || _resending ? null : _resend,
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: Text(
            _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend email',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: auth.isLoading ? null : _useAnotherAccount,
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text(
            'Use a different account',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
