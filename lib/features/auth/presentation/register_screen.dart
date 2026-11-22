import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/auth_providers.dart';
import '../domain/auth_validation.dart';
import 'legal_sheet.dart';
import 'widgets/auth_scaffold.dart';

/// Layar Registrasi sesuai Figma frame `305:736`.
///
/// Termasuk checkbox persetujuan Syarat & Ketentuan (PRD §3.1, v1.10):
/// tombol Daftar tidak memproses form sebelum pengguna menyetujuinya.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _acceptedTerms = false;
  bool _showTermsError = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  AuthController get _controller => ref.read(authControllerProvider.notifier);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState?.validate() ?? false;

    if (!_acceptedTerms) {
      setState(() => _showTermsError = true);
    }
    if (!formValid || !_acceptedTerms) return;

    final ok = await _controller.register(
      name: _name.text,
      email: _email.text,
      password: _password.text,
    );

    if (!ok || !mounted) return;
    // Gate menampilkan layar verifikasi; buang rute Registrasi supaya tombol
    // back tidak kembali ke form yang sudah terkirim.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth.isLoading;
    final error = _controller.errorMessage;

    return AuthScaffold(
      title: 'Create your account',
      subtitle:
          'Manage your ingredients, waste less. '
          'Start a good habit with Optimeal.',
      headerGap: 24,
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) AuthErrorBanner(message: error),
                AuthTextField(
                  label: 'Full name',
                  hint: 'Sarah Putri',
                  controller: _name,
                  icon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: validateName,
                  enabled: !busy,
                  onChanged: (_) => _controller.clearError(),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Email',
                  hint: 'sarah.putri@gmail.com',
                  controller: _email,
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: validateEmail,
                  enabled: !busy,
                  onChanged: (_) => _controller.clearError(),
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  label: 'Password',
                  controller: _password,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validatePassword,
                  enabled: !busy,
                  helperText:
                      'Use at least $kMinPasswordLength characters, '
                      'including a letter and a number.',
                  onChanged: (_) => _controller.clearError(),
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  label: 'Confirm password',
                  controller: _confirm,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) =>
                      validatePasswordConfirmation(value, _password.text),
                  enabled: !busy,
                ),
                const SizedBox(height: 24),
                _TermsAgreement(
                  accepted: _acceptedTerms,
                  enabled: !busy,
                  showError: _showTermsError,
                  onChanged: (value) => setState(() {
                    _acceptedTerms = value;
                    if (value) _showTermsError = false;
                  }),
                  onOpenTerms: () => showLegalSheet(
                    context,
                    title: 'Terms & Conditions',
                    body: kTermsBody,
                  ),
                  onOpenPrivacy: () => showLegalSheet(
                    context,
                    title: 'Privacy Policy',
                    body: kPrivacyBody,
                  ),
                ),
                const SizedBox(height: 24),
                AuthSubmitButton(
                  label: 'Create account',
                  busy: busy,
                  onPressed: _submit,
                ),
                AuthSwitchLink(
                  question: 'Already have an account?',
                  action: 'Sign in',
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Checkbox 20 px + teks persetujuan dua warna (Figma "Terms agreement").
class _TermsAgreement extends StatefulWidget {
  const _TermsAgreement({
    required this.accepted,
    required this.enabled,
    required this.showError,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool accepted;
  final bool enabled;
  final bool showError;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  State<_TermsAgreement> createState() => _TermsAgreementState();
}

class _TermsAgreementState extends State<_TermsAgreement> {
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = widget.onOpenTerms;
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = widget.onOpenPrivacy;

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.helper.copyWith(height: 1.6);
    final link = base.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              checked: widget.accepted,
              label: 'I agree to the Terms & Conditions and Privacy Policy',
              child: InkWell(
                onTap: widget.enabled
                    ? () => widget.onChanged(!widget.accepted)
                    : null,
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 2, bottom: 2),
                  child: AnimatedContainer(
                    key: const Key('terms-checkbox'),
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: widget.accepted
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: widget.accepted
                            ? AppColors.primary
                            : (widget.showError
                                  ? AppColors.danger
                                  : AppColors.border),
                      ),
                    ),
                    child: widget.accepted
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: AppColors.surface,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'I agree to Optimeal\'s ', style: base),
                    TextSpan(
                      text: 'Terms & Conditions',
                      style: link,
                      recognizer: _termsTap,
                    ),
                    TextSpan(text: ' and ', style: base),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: link,
                      recognizer: _privacyTap,
                    ),
                    TextSpan(text: '.', style: base),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (widget.showError) ...[
          const SizedBox(height: 8),
          Text(
            'Please accept the Terms & Conditions to continue.',
            style: AppTextStyles.helper.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}
