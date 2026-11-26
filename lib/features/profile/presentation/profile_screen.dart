import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../application/logout.dart';
import '../application/profile_providers.dart';

/// Figma frame "profile" (433:838).
///
/// Dark Mode and Language were removed from the product (PRD v1.11). The menu
/// rows stay visual-only until each sub-screen is implemented; Logout is the
/// only action that is wired.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await ref.read(logoutProvider)();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileUserProvider);
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
                Center(child: _Avatar(user: user)),
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
                    child: const Column(
                      children: [
                        _MenuRow(
                          icon: Icons.person_outline,
                          label: 'Profile Details',
                        ),
                        SizedBox(height: 10),
                        _MenuRow(icon: Icons.lock_outline, label: 'Password'),
                        SizedBox(height: 10),
                        _MenuRow(
                          icon: Icons.notifications_none,
                          label: 'Notifications',
                        ),
                        SizedBox(height: 10),
                        _MenuRow(
                          icon: Icons.support_agent,
                          label: 'Support',
                        ),
                        SizedBox(height: 10),
                        _MenuRow(icon: Icons.info_outline, label: 'About'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _LogoutCard(onTap: _loggingOut ? null : _logout),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final ProfileUser? user;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoUrl;
    return Container(
      width: 97,
      height: 97,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: photoUrl == null
          ? _Initials(name: user?.name)
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _Initials(name: user?.name),
            ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _initials(name),
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  static String _initials(String? name) {
    final words = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'O';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    // No destination yet: the row is drawn exactly as in Figma without
    // promising a screen that does not exist.
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.menuRow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: menuRowShadow,
      ),
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
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
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
            decoration: BoxDecoration(
              color: AppColors.logoutRow,
              borderRadius: BorderRadius.circular(16),
              boxShadow: menuRowShadow,
            ),
            child: const Row(
              children: [
                Icon(Icons.logout, size: 23, color: AppColors.danger),
                SizedBox(width: 18),
                Expanded(
                  child: Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.danger,
                    ),
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
