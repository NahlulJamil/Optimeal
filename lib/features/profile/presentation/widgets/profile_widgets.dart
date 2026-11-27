import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/profile_repository.dart';

/// Shared circular avatar for Profile Hub and Profile Details.
///
/// Uses `photoURL` from Firebase when present (e.g. Google sign-in) and falls
/// back to the user's initials for email/password accounts (PRD §3.7).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.user, this.size = 97});

  final ProfileUser? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoUrl;
    return Container(
      width: size,
      height: size,
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

/// Logout action button on Profile Hub, styled with the same soft-danger
/// palette (`AppColors.dangerSoft` + `AppColors.danger`) as `ExpiringBanner`
/// on Home.
class LogoutRowButton extends StatelessWidget {
  const LogoutRowButton({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
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
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
