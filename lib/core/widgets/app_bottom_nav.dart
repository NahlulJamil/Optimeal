import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

enum AppTab { home, pantry, recipes, profile }

/// Bottom navigation from Figma: Home, Pantry, center Add (+), Recipes,
/// Profile (PRD §3.2). Routing is owned by Developer 1; this widget only
/// reports taps.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    required this.onTabSelected,
    required this.onAddPressed,
  });

  final AppTab current;
  final ValueChanged<AppTab> onTabSelected;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    Widget tab(AppTab tab, IconData icon, IconData activeIcon, String label) {
      final active = tab == current;
      final color = active ? AppColors.primary : AppColors.navInactive;
      return Expanded(
        child: InkResponse(
          onTap: () => onTabSelected(tab),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              tab(AppTab.home, Icons.home_outlined, Icons.home, 'Home'),
              tab(
                AppTab.pantry,
                Icons.kitchen_outlined,
                Icons.kitchen,
                'Pantry',
              ),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'Add food',
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onAddPressed,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.add_circle_outline,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              tab(
                AppTab.recipes,
                Icons.menu_book_outlined,
                Icons.menu_book,
                'Recipes',
              ),
              tab(
                AppTab.profile,
                Icons.person_outline,
                Icons.person,
                'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
