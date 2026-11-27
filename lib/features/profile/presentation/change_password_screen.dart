import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/connectivity/offline_error.dart';
import '../../../core/connectivity/online_status.dart';
import '../../../core/connectivity/sync_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_validation.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';

/// Profile → Password (Figma "Change Your Password").
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _save({String? currentPassword}) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (ref.read(writeBlockedProvider)) {
      setState(() => _error = offlineActionMessage);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            newPassword: _newPassword.text,
            currentPassword: currentPassword,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Password updated.')));
      Navigator.of(context).maybePop();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      if (error.code == 'requires-recent-login' && currentPassword == null) {
        setState(() => _saving = false);
        final entered = await _askCurrentPassword();
        if (entered != null && mounted) {
          await _save(currentPassword: entered);
        }
        return;
      }
      setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = isOfflineError(error)
              ? offlineActionMessage
              : 'Could not update your password. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _askCurrentPassword() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _CurrentPasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = !ref.watch(writeBlockedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CircleIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  32 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            size: 38,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Change Your Password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTextStyles.uiFont,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 26),
                      if (_error != null) AuthErrorBanner(message: _error!),
                      AuthPasswordField(
                        label: 'New Password',
                        hint: '••••••••••',
                        controller: _newPassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: validateNewPassword,
                        enabled: canWrite && !_saving,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: 16),
                      AuthPasswordField(
                        label: 'Confirm New Password',
                        hint: '••••••••••',
                        controller: _confirmPassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (v) => validatePasswordConfirmation(
                          v,
                          _newPassword.text,
                        ),
                        enabled: canWrite && !_saving,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: 18),
                      const _RuleBullet('Minimum 8 characters'),
                      const SizedBox(height: 4),
                      const _RuleBullet(
                        'Include at least one uppercase letter (A-Z)',
                      ),
                      const SizedBox(height: 4),
                      const _RuleBullet('Include at least one number (0-9)'),
                      const SizedBox(height: 24),
                      AuthSubmitButton(
                        label: 'Save',
                        busy: _saving,
                        onPressed: canWrite ? _save : null,
                      ),
                      if (!canWrite)
                        const OfflineHint(
                          'Changing your password needs an internet connection.',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleBullet extends StatelessWidget {
  const _RuleBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 6, right: 8),
          child: Text('•', style: AppTextStyles.helper),
        ),
        Expanded(child: Text(text, style: AppTextStyles.helper)),
      ],
    );
  }
}

class _CurrentPasswordDialog extends StatefulWidget {
  const _CurrentPasswordDialog();

  @override
  State<_CurrentPasswordDialog> createState() => _CurrentPasswordDialogState();
}

class _CurrentPasswordDialogState extends State<_CurrentPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm current password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'For your security, enter your current password before '
                'setting a new one.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _controller,
                obscureText: true,
                autofocus: true,
                validator: (v) => validatePassword(v, requireStrength: false),
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text);
            }
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
