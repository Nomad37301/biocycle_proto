import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_initializer.dart';
import '../../core/notifications/notification_service.dart';
import '../app.dart';
import '../app_providers.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDatabasePlatform();
  final database = await AppDatabase.open();
  final notifications = NotificationService();
  notifications.sessionGeneration =
      int.tryParse(await database.getSetting('session_generation') ?? '') ?? 1;
  final initialNotification = await notifications.initialize();
  final showOnboarding =
      await database.getSetting('onboarding_complete') != 'true';
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        notificationProvider.overrideWithValue(notifications),
        initialNotificationProvider.overrideWithValue(initialNotification),
      ],
      child: BioCycleApp(
        initialNotification: initialNotification,
        showOnboarding: showOnboarding,
      ),
    ),
  );
}
