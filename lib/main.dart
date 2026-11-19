import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_colors.dart';
import 'core/widgets/app_bottom_nav.dart';
import 'features/notification/application/notification_providers.dart';
import 'features/notification/domain/notification_planner.dart';
import 'features/pantry/presentation/food_detail_screen.dart';
import 'features/pantry/presentation/pantry_screen.dart';
import 'features/scanner/presentation/scanner_screen.dart';

void main() {
  runApp(const ProviderScope(child: OptimealApp()));
}

class OptimealApp extends StatelessWidget {
  const OptimealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Optimeal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const DevShell(),
    );
  }
}

/// Temporary navigation shell so Developer 2's features can run on their own.
///
/// Routing (go_router), Home, Recipes, Profile, auth and the global theme are
/// owned by Developers 1 and 3 (DevelopmentPlan.md); replace this shell when
/// their work lands. Each tab keeps its own navigator so the bottom bar stays
/// visible on pushed screens, as in Figma.
class DevShell extends ConsumerStatefulWidget {
  const DevShell({super.key});

  @override
  ConsumerState<DevShell> createState() => _DevShellState();
}

class _DevShellState extends ConsumerState<DevShell> {
  AppTab _tab = AppTab.pantry;
  final _pantryNavigator = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    final service = ref.read(notificationServiceProvider);
    _taps = service.taps.listen(_openFromNotification);
    unawaited(() async {
      await service.requestPermissions();
      final payload = await service.launchPayload();
      if (payload != null) _openFromNotification(payload);
    }());
  }

  @override
  void dispose() {
    unawaited(_taps?.cancel());
    super.dispose();
  }

  /// Deep link from a reminder to the food's detail page (PRD §3.6); the
  /// summary reminder opens the Pantry list.
  void _openFromNotification(String payload) {
    if (!mounted) return;
    setState(() => _tab = AppTab.pantry);
    final nav = _pantryNavigator.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
    if (payload != summaryPayload) {
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => FoodDetailScreen(foodId: payload),
        ),
      );
    }
  }

  /// The center Add button opens the Food Scanner (full screen, as in Figma).
  void _openAdd() {
    setState(() => _tab = AppTab.pantry);
    openScanner(context);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps local reminders in sync with the pantry and preferences.
    ref.watch(notificationSyncProvider);
    return Scaffold(
      body: IndexedStack(
        index: _tab == AppTab.pantry ? 0 : 1,
        children: [
          Navigator(
            key: _pantryNavigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => PantryScreen(
                onBack: () => setState(() => _tab = AppTab.home),
              ),
            ),
          ),
          _OwnedElsewhere(tab: _tab),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        current: _tab,
        onTabSelected: (t) => setState(() => _tab = t),
        onAddPressed: _openAdd,
      ),
    );
  }
}

class _OwnedElsewhere extends StatelessWidget {
  const _OwnedElsewhere({required this.tab});

  final AppTab tab;

  @override
  Widget build(BuildContext context) {
    final owner = tab == AppTab.recipes ? 'Developer 3' : 'Developer 1';
    return Center(
      child: Text(
        '${tab.name[0].toUpperCase()}${tab.name.substring(1)} is built by $owner.',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
