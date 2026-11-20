import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/notification/application/notification_providers.dart';
import 'package:optimeal/features/notification/data/notification_service.dart';
import 'package:optimeal/features/notification/domain/notification_planner.dart';
import 'package:optimeal/features/pantry/application/pantry_providers.dart';
import 'package:optimeal/features/pantry/data/pantry_repository.dart';
import 'package:optimeal/features/pantry/domain/shelf_life.dart';

import '../helpers/fakes.dart';

class FakeNotificationService implements NotificationService {
  final plans = <List<PlannedNotification>>[];

  @override
  Stream<String> get taps => const Stream.empty();

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<void> replaceAll(
    List<PlannedNotification> plan,
    NotificationSettings settings,
  ) async => plans.add(plan);
}

void main() {
  late ProviderContainer container;
  late FakeNotificationService service;

  setUp(() {
    service = FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        pantryRepositoryProvider.overrideWithValue(fixtureRepository()),
        photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        notificationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    container.listen(notificationSyncProvider, (_, _) {});
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('reschedules on pantry changes and drops deleted food', () async {
    await container.read(pantryControllerProvider.future);
    await settle();
    final controller = container.read(pantryControllerProvider.notifier);

    final today = dateOnly(DateTime.now());
    final added = await controller.add(
      FoodDraft(
        name: 'Spinach',
        category: 'Vegetables',
        storageLocation: StorageLocation.fridge,
        purchaseDate: today,
        shelfLifeDays: 5,
      ),
    );
    await settle();
    expect(service.plans.last.map((p) => p.foodId), contains(added.foodId));

    await controller.remove(added.foodId);
    await settle();
    expect(
      service.plans.last.map((p) => p.foodId),
      isNot(contains(added.foodId)),
    );
  });

  test('turning notifications off clears the schedule', () async {
    await container.read(pantryControllerProvider.future);
    await container
        .read(pantryControllerProvider.notifier)
        .add(
          FoodDraft(
            name: 'Tomato',
            category: 'Vegetables',
            storageLocation: StorageLocation.fridge,
            purchaseDate: dateOnly(DateTime.now()),
            shelfLifeDays: 4,
          ),
        );
    await settle();
    expect(service.plans.last, isNotEmpty);

    container.read(notificationSettingsProvider.notifier).setEnabled(false);
    await settle();
    container.read(notificationSyncProvider);
    expect(service.plans.last, isEmpty);
  });

  test('expiringSoonProvider uses the threshold', () async {
    await container.read(pantryControllerProvider.future);
    final controller = container.read(pantryControllerProvider.notifier);
    final today = dateOnly(DateTime.now());
    await controller.add(
      FoodDraft(
        name: 'Soon',
        category: 'Fruits',
        storageLocation: StorageLocation.fridge,
        purchaseDate: today,
        shelfLifeDays: 1,
      ),
    );
    await controller.add(
      FoodDraft(
        name: 'Later',
        category: 'Fruits',
        storageLocation: StorageLocation.fridge,
        purchaseDate: today,
        shelfLifeDays: 3,
      ),
    );
    expect(
      container.read(expiringSoonProvider).map((i) => i.name),
      contains('Soon'),
    );
    expect(
      container.read(expiringSoonProvider).map((i) => i.name),
      isNot(contains('Later')),
    );
    container.read(notificationSettingsProvider.notifier).setThresholdDays(3);
    expect(
      container.read(expiringSoonProvider).map((i) => i.name),
      contains('Later'),
    );
  });
}
