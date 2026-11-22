import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../application/auth_providers.dart';
import '../domain/auth_validation.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'widgets/auth_scaffold.dart';

/// Layar Login sesuai Figma frame `305:787` dan varian error `305:879`.
///
/// Light theme, English only. Error kredensial tampil inline di bawah field
/// sandi (border merah + kartu `#FFF0ED`); error lain tetap memakai banner.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  AuthController get _controller => ref.read(authControllerProvider.notifier);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _controller.signIn(email: _email.text, password: _password.text);
    // Sukses ditangani gate di main.dart (authState berubah).
  }

  void _openRegister() {
    _controller.clearError();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
  }

  void _openForgotPassword() {
    _controller.clearError();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth.isLoading;
    final failure = _controller.failure;
    final credentialError = _controller.hasCredentialError;
    final generalError = credentialError ? null : _controller.errorMessage;

    return AuthScaffold(
      showBrand: true,
      contentTopPadding: 4,
      title: 'Welcome back!',
      subtitle:
          'Ingredients saved, cooking ideas ready. '
          'Sign in and keep up the good work.',
      headerGap: 35,
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (generalError != null)
                  AuthErrorBanner(message: generalError),
                AuthTextField(
                  label: 'Email',
                  hint: 'sarah.putri@gmail.com',
                  controller: _email,
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  validator: validateEmail,
                  enabled: !busy,
                  onChanged: (_) => _controller.clearError(),
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  label: 'Password',
                  controller: _password,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) =>
                      validatePassword(value, requireStrength: false),
                  enabled: !busy,
                  hasError: credentialError,
                  onChanged: (_) => _controller.clearError(),
                ),
                if (credentialError && failure != null) ...[
                  const SizedBox(height: 10),
                  AuthErrorBanner(
                    message: failure.message,
                    margin: EdgeInsets.zero,
                  ),
                ],
                const SizedBox(height: 10),
                AuthTextLink(
                  label: 'Forgot password?',
                  onPressed: busy ? null : _openForgotPassword,
                ),
                const SizedBox(height: 22),
                AuthSubmitButton(
                  label: credentialError ? 'Try again' : 'Sign in',
                  busy: busy,
                  onPressed: _submit,
                ),
                AuthSwitchLink(
                  question: 'New to Optimeal?',
                  action: 'Create account',
                  onPressed: busy ? null : _openRegister,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
