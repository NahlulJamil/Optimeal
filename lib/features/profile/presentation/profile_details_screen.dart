import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/connectivity/offline_error.dart';
import '../../../core/connectivity/online_status.dart';
import '../../../core/connectivity/sync_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/domain/auth_validation.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';
import '../application/profile_providers.dart';
import 'widgets/profile_widgets.dart';

/// Profile → Profile Details (Figma "Profile Details").
class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  ConsumerState<ProfileDetailsScreen> createState() =>
      _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  static const List<String> _countryCodes = [
    '+62',
    '+1',
    '+44',
    '+65',
    '+60',
    '+81',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayName;
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late String _countryCode;

  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(profileUserProvider);
    _displayName = TextEditingController(text: user?.name ?? '');
    _fullName = TextEditingController(text: user?.fullName ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _phone = TextEditingController(text: user?.phoneNumber ?? '');
    final code = user?.phoneCountryCode ?? '+62';
    _countryCode = _countryCodes.contains(code) ? code : '+62';
  }

  void _syncFromProfile(ProfileUser? loaded) {
    if (loaded == null || _dirty) return;
    _displayName.text = loaded.name;
    _fullName.text = loaded.fullName ?? '';
    _email.text = loaded.email;
    _phone.text = loaded.phoneNumber ?? '';
    if (_countryCodes.contains(loaded.phoneCountryCode)) {
      _countryCode = loaded.phoneCountryCode;
    }
  }

  @override
  void dispose() {
    _displayName.dispose();
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
          .read(profileControllerProvider.notifier)
          .saveDetails(
            displayName: _displayName.text,
            fullName: _fullName.text,
            phoneCountryCode: _countryCode,
            phoneNumber: _phone.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile details saved.')));
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = isOfflineError(error)
              ? offlineActionMessage
              : 'Could not save your profile. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ProfileUser?>>(profileControllerProvider, (_, next) {
      if (mounted && next.hasValue) {
        setState(() => _syncFromProfile(next.value));
      }
    });
    final user = ref.watch(profileUserProvider);
    final canWrite = !ref.watch(writeBlockedProvider);
    final busy = _saving;

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
                      Center(child: ProfileAvatar(user: user)),
                      const SizedBox(height: 14),
                      Text(
                        user?.name ?? 'Optimeal user',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (_error != null) AuthErrorBanner(message: _error!),
                      AuthTextField(
                        label: 'Display Name',
                        hint: 'Sarah',
                        controller: _displayName,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        validator: validateName,
                        enabled: canWrite && !busy,
                        onChanged: (_) => _dirty = true,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'Full Name',
                        hint: 'Sarah Amalia',
                        controller: _fullName,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        enabled: canWrite && !busy,
                        onChanged: (_) => _dirty = true,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'Email',
                        controller: _email,
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      const AuthFieldLabel('Telephone'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 98,
                            child: DropdownButtonFormField<String>(
                              initialValue: _countryCode,
                              isExpanded: true,
                              onChanged: canWrite && !busy
                                  ? (v) {
                                      if (v != null) {
                                        setState(() {
                                          _dirty = true;
                                          _countryCode = v;
                                        });
                                      }
                                    }
                                  : null,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textPrimary,
                              ),
                              style: AppTextStyles.fieldValue,
                              decoration: _fieldDecoration(),
                              items: [
                                for (final code in _countryCodes)
                                  DropdownMenuItem(
                                    value: code,
                                    child: Text(code),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _phone,
                              enabled: canWrite && !busy,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => _dirty = true,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d\s-]'),
                                ),
                              ],
                              validator: validateOptionalPhoneNumber,
                              style: AppTextStyles.fieldValue,
                              decoration: _fieldDecoration(
                                hint: '81234567812',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      AuthSubmitButton(
                        label: 'Save',
                        busy: _saving,
                        onPressed: canWrite ? _save : null,
                      ),
                      if (!canWrite)
                        const OfflineHint(
                          'Saving profile details needs an internet connection.',
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

  static InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: AppTextStyles.fieldValue.copyWith(
        color: AppColors.textSecondary,
      ),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      constraints: const BoxConstraints(minHeight: 54),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kFieldRadius),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kFieldRadius),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kFieldRadius),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kFieldRadius),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kFieldRadius),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      errorStyle: AppTextStyles.helper.copyWith(color: AppColors.danger),
    );
  }
}
