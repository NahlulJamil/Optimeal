import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/connectivity/connectivity_watcher.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_bottom_nav.dart';
import 'core/widgets/app_widgets.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/verify_email_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/notification/application/notification_providers.dart';
import 'features/notification/domain/notification_planner.dart';
import 'features/pantry/presentation/food_detail_screen.dart';
import 'features/pantry/presentation/pantry_screen.dart';
import 'features/recipes/presentation/recipe_detail_screen.dart';
import 'features/recipes/presentation/recipes_screen.dart';
import 'features/scanner/presentation/scanner_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: OptimealApp()));
}

class OptimealApp extends StatelessWidget {
  const OptimealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Optimeal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Dark status-bar icons on the light screens; dark screens (scanner,
      // Food Details photo header) override this with their own region.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: child!,
      ),
      home: const ConnectivityWatcher(child: AuthGate()),
    );
  }
}

/// Memilih layar berdasarkan sesi Firebase (PRD §3.1):
/// belum login → Login, email belum diverifikasi → Verifikasi, selain itu →
/// aplikasi utama. Sesi dipertahankan otomatis oleh FirebaseAuth.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const _AuthSplash(),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: StateMessage(
          icon: Icons.cloud_off,
          title: 'Could not start your session',
          message: 'Check your connection and try again.',
          action: FilledButton(
            onPressed: () => ref.invalidate(authStateProvider),
            child: const Text('Try again'),
          ),
        ),
      ),
      data: (user) {
        if (user == null) return const LoginScreen();
        if (!user.emailVerified) {
          return VerifyEmailScreen(email: user.email ?? '');
        }
        return const AppShell();
      },
    );
  }
}

class _AuthSplash extends StatelessWidget {
  const _AuthSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Navigation shell for the signed-in app: Home, Pantry, Add, Recipes and
/// Profile, with the bottom bar from Figma (PRD §3.2). Each tab keeps its own
/// navigator so the bar stays visible on pushed screens, as in Figma.
///
/// Home is Developer 1's screen; Pantry and Recipe Finder come from Developers
/// 2 and 3. The Profile tab is still the temporary placeholder.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  AppTab _tab = AppTab.home;
  final _homeNavigator = GlobalKey<NavigatorState>();
  final _pantryNavigator = GlobalKey<NavigatorState>();
  final _recipesNavigator = GlobalKey<NavigatorState>();
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
    unawaited(markNotificationRead(ref, payload));
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

  /// Pushes a detail screen inside the Home tab so the bottom bar stays
  /// visible, matching the Figma flow.
  void _pushOnHome(WidgetBuilder builder) {
    _homeNavigator.currentState?.push(
      MaterialPageRoute<void>(builder: builder),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keeps local reminders in sync with the pantry and preferences.
    ref.watch(notificationSyncProvider);
    return Scaffold(
      body: IndexedStack(
        index: switch (_tab) {
          AppTab.home => 0,
          AppTab.pantry => 1,
          AppTab.recipes => 2,
          AppTab.profile => 3,
        },
        children: [
          Navigator(
            key: _homeNavigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => HomeScreen(
                onOpenPantry: () => setState(() => _tab = AppTab.pantry),
                onOpenRecipes: () => setState(() => _tab = AppTab.recipes),
                onOpenFood: (foodId) =>
                    _pushOnHome((_) => FoodDetailScreen(foodId: foodId)),
                onOpenRecipe: (recipeId) =>
                    _pushOnHome((_) => RecipeDetailScreen(recipeId: recipeId)),
              ),
            ),
          ),
          Navigator(
            key: _pantryNavigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => PantryScreen(
                onBack: () => setState(() => _tab = AppTab.home),
              ),
            ),
          ),
          Navigator(
            key: _recipesNavigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => RecipesScreen(
                onBack: () => setState(() => _tab = AppTab.home),
              ),
            ),
          ),
          const _OwnedElsewhere(tab: AppTab.profile),
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
    const owner = 'Developer 1';
    return Center(
      child: Text(
        '${tab.name[0].toUpperCase()}${tab.name.substring(1)} is built by $owner.',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
