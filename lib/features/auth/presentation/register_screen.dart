import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../application/auth_providers.dart';
import '../domain/auth_validation.dart';
import 'widgets/auth_scaffold.dart';

/// Layar Registrasi (PRD §3.1). Setelah berhasil, gate menampilkan layar
/// verifikasi email.
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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref
        .read(authControllerProvider.notifier)
        .register(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );

    if (!ok || !mounted) return;
    // Gate akan menampilkan layar verifikasi; buang rute Registrasi supaya
    // tombol back tidak kembali ke form yang sudah terkirim.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth.isLoading;
    final error = ref.read(authControllerProvider.notifier).errorMessage;

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Start tracking your pantry in one place.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) AuthErrorBanner(message: error),
                AuthTextField(
                  label: 'Name',
                  hint: 'Your name',
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: validateName,
                  enabled: !busy,
                  onChanged: (_) =>
                      ref.read(authControllerProvider.notifier).clearError(),
                ),
                AuthTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: validateEmail,
                  enabled: !busy,
                  onChanged: (_) =>
                      ref.read(authControllerProvider.notifier).clearError(),
                ),
                AuthPasswordField(
                  label: 'Password',
                  hint: 'At least 8 characters',
                  controller: _password,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validatePassword,
                  enabled: !busy,
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Use at least 8 characters, including a letter and a number.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                AuthPasswordField(
                  label: 'Confirm password',
                  controller: _confirm,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) =>
                      validatePasswordConfirmation(value, _password.text),
                  enabled: !busy,
                ),
                const SizedBox(height: 4),
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
