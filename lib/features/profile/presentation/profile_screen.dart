import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/connectivity/offline_error.dart';
import '../../../core/connectivity/online_status.dart';
import '../../../core/connectivity/sync_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../notification/application/notification_providers.dart';
import '../application/logout.dart';
import '../application/profile_providers.dart';
import 'about_screen.dart';
import 'change_password_screen.dart';
import 'profile_details_screen.dart';
import 'support_screen.dart';
import 'widgets/profile_widgets.dart';

/// Figma frame "profile" (433:838).
///
/// Dark Mode and Language were removed from the product (PRD v1.11).
/// Notifications toggles reminders on/off inline; the other four rows push
/// their sub-screens inside the Profile tab navigator.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loggingOut = false;
  bool _togglingNotifications = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await ref.read(logoutProvider)();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _toggleNotifications(bool nextValue) async {
    if (_togglingNotifications) return;
    final blocked = ref.read(writeBlockedProvider);
    if (blocked) {
      _showMessage(offlineActionMessage);
      return;
    }
    setState(() => _togglingNotifications = true);
    try {
      await ref
          .read(profileControllerProvider.notifier)
          .setNotificationsEnabled(nextValue);
    } catch (error) {
      _showMessage(
        isOfflineError(error)
            ? offlineActionMessage
            : 'Could not update notification settings. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _togglingNotifications = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileUserProvider);
    final notificationsEnabled = ref
        .watch(notificationSettingsProvider)
        .enabled;
    final canWrite = !ref.watch(writeBlockedProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status-bar icons over the green header.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(child: ProfileAvatar(user: user)),
                const SizedBox(height: 13),
                Text(
                  user?.name ?? 'Optimeal user',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user?.email ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 23),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 21,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _MenuRow(
                          icon: Icons.person_outline,
                          label: 'Profile Details',
                          onTap: () => _push(const ProfileDetailsScreen()),
                        ),
                        const SizedBox(height: 10),
                        _MenuRow(
                          icon: Icons.lock_outline,
                          label: 'Password',
                          onTap: () => _push(const ChangePasswordScreen()),
                        ),
                        const SizedBox(height: 10),
                        _NotificationToggleRow(
                          enabled: notificationsEnabled,
                          interactive: canWrite && !_togglingNotifications,
                          onTap: () =>
                              _toggleNotifications(!notificationsEnabled),
                        ),
                        if (!canWrite)
                          const OfflineHint(
                            'Changing notification settings needs an internet '
                            'connection.',
                          ),
                        const SizedBox(height: 10),
                        _MenuRow(
                          icon: Icons.support_agent,
                          label: 'Support',
                          onTap: () => _push(const SupportScreen()),
                        ),
                        const SizedBox(height: 10),
                        _MenuRow(
                          icon: Icons.info_outline,
                          label: 'About',
                          onTap: () => _push(const AboutScreen()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: LogoutRowButton(onTap: _loggingOut ? null : _logout),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.menuRow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: menuRowShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppColors.textPrimary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  const _NotificationToggleRow({
    required this.enabled,
    required this.interactive,
    required this.onTap,
  });

  final bool enabled;
  final bool interactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: enabled,
      button: true,
      label: 'Notifications',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.menuRow,
          borderRadius: BorderRadius.circular(16),
          boxShadow: menuRowShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_none,
                    size: 22,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: interactive ? 1 : 0.45,
                    child: _PillToggle(
                      key: const Key('profile-notifications-switch'),
                      value: enabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact pill switch matching the Figma "profile" Notifications row.
class _PillToggle extends StatelessWidget {
  const _PillToggle({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 34,
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: value ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: value ? AppColors.primary : AppColors.textPrimary,
          width: 1.6,
        ),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: value ? AppColors.surface : AppColors.textPrimary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
