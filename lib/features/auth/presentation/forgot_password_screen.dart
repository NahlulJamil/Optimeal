import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../application/auth_providers.dart';
import '../domain/auth_validation.dart';
import 'widgets/auth_scaffold.dart';

/// Layar Lupa sandi (PRD §3.1, v1.10).
///
/// Figma `305:787` menampilkan tautan "Lupa sandi?" tetapi tidak menyediakan
/// frame terpisah, sehingga layar ini memakai bahasa visual yang sama:
/// back button 40 px, judul Inter 28 ExtraBold, input radius 16, tombol pill.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  AuthController get _controller => ref.read(authControllerProvider.notifier);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await _controller.sendPasswordReset(_email.text);
    if (!mounted || !ok) return;
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth.isLoading;
    final error = _controller.errorMessage;

    if (_sent) {
      return AuthScaffold(
        title: 'Check your inbox',
        subtitle: 'We sent a password reset link to ${_email.text.trim()}.',
        headerIcon: const Icon(
          Icons.mark_email_read_outlined,
          size: 40,
          color: AppColors.primary,
        ),
        alignment: AuthHeaderAlignment.center,
        contentTopPadding: 36,
        headerGap: 32,
        children: [
          AuthInfoCard(
            text:
                'Open the link in your email and choose a new password. '
                'The link expires in one hour. If it does not arrive, check '
                'your spam or promotions folder.',
          ),
          const SizedBox(height: 32),
          AuthSubmitButton(
            label: 'Back to sign in',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
          AuthTextLink(
            label: 'Send again',
            align: MainAxisAlignment.center,
            onPressed: busy
                ? null
                : () {
                    setState(() => _sent = false);
                    _submit();
                  },
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'Reset your password',
      subtitle:
          "Enter the email you signed up with and we'll send you a link to "
          'set a new password.',
      headerGap: 32,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) AuthErrorBanner(message: error),
              AuthTextField(
                label: 'Email',
                hint: 'sarah.putri@gmail.com',
                controller: _email,
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                validator: validateEmail,
                enabled: !busy,
                onChanged: (_) => _controller.clearError(),
              ),
              const SizedBox(height: 24),
              AuthSubmitButton(
                label: 'Send reset link',
                busy: busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              AuthTextLink(
                label: 'Back to sign in',
                align: MainAxisAlignment.center,
                onPressed: busy ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
