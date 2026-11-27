import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/connectivity/sync_status.dart';
import '../../auth/application/auth_providers.dart';
import '../../notification/application/notification_providers.dart';
import '../../notification/data/notification_service.dart';
import '../../pantry/application/pantry_providers.dart';
import '../../pantry/data/photo_store.dart';
import '../../recipes/application/recipe_providers.dart';
import '../../recipes/data/recipe_image_store.dart';
import '../../recipes/data/recipe_store.dart';
import 'profile_providers.dart';

/// Signs the user out and clears the device data that must not outlive the
/// session (PRD §6.7, §12.3 note 12): scheduled reminders, food photos,
/// recipe images, favourites and the recipe quota, and the last-sync timestamp.
final logoutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await clearLocalSessionData(
      notifications: ref.read(notificationServiceProvider),
      photos: ref.read(photoStoreProvider),
      recipeImages: ref.read(recipeImageStoreProvider),
      sync: ref.read(syncStatusProvider.notifier),
      userId: ref.read(profileUserProvider)?.uid,
    );
    await ref.read(authControllerProvider.notifier).signOut();
  };
});

/// Best effort: a failed cleanup must never keep the user signed in, so each
/// step is isolated and only logged.
Future<void> clearLocalSessionData({
  required NotificationService notifications,
  required PhotoStore photos,
  required RecipeImageStore recipeImages,
  required SyncStatusController sync,
  required String? userId,
}) async {
  await _step('reminders', notifications.cancelAll);
  await _step('photos', photos.clear);
  await _step('recipe images', recipeImages.clear);
  if (userId != null) {
    await _step('recipes', () async {
      final prefs = await SharedPreferences.getInstance();
      await LocalRecipeStore(prefs, userId: userId).clear();
    });
  }
  await _step('sync status', sync.clear);
}

Future<void> _step(String label, Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    debugPrint('Logout cleanup ($label) failed: $error');
  }
}
