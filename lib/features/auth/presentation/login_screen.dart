import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../application/auth_providers.dart';
import '../domain/auth_validation.dart';
import 'register_screen.dart';
import 'widgets/auth_scaffold.dart';

/// Layar Login (PRD §3.1). Light theme, English only.
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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
    // Sukses ditangani gate di main.dart (authState berubah).
  }

  void _openRegister() {
    ref.read(authControllerProvider.notifier).clearError();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth.isLoading;
    final error = ref.read(authControllerProvider.notifier).errorMessage;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to keep track of your pantry.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) AuthErrorBanner(message: error),
                AuthTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  validator: validateEmail,
                  enabled: !busy,
                  onChanged: (_) =>
                      ref.read(authControllerProvider.notifier).clearError(),
                ),
                AuthPasswordField(
                  label: 'Password',
                  controller: _password,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) =>
                      validatePassword(value, requireStrength: false),
                  enabled: !busy,
                ),
                const SizedBox(height: 4),
                AuthSubmitButton(
                  label: 'Sign in',
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
