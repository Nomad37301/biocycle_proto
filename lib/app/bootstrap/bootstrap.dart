import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../app.dart';
import '../app_providers.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final notifications = NotificationService();
  final initialNotification = await notifications.initialize();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        notificationProvider.overrideWithValue(notifications),
        initialNotificationProvider.overrideWithValue(initialNotification),
      ],
      child: BioCycleApp(initialNotification: initialNotification),
    ),
  );
}
