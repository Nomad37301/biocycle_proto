import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/notifications/notification_service.dart';
import '../features/demo_session/application/demo_session_controller.dart';
import '../features/demo_session/domain/demo_session.dart';
import '../features/insights/data/local_insight_repository.dart';
import '../features/insights/domain/insight_models.dart';
import '../features/insights/domain/insight_repository.dart';
import '../features/monitoring/data/local_telemetry_repository.dart';
import '../features/monitoring/domain/telemetry_models.dart';
import '../features/monitoring/domain/telemetry_repository.dart';
import '../features/partners/data/local_partner_repository.dart';
import '../features/partners/domain/partner_models.dart';
import '../features/partners/domain/partner_repository.dart';

final databaseProvider = Provider<AppDatabase>(
  (_) => throw UnimplementedError(),
);
final notificationProvider = Provider<NotificationService>(
  (_) => throw UnimplementedError(),
);
final initialNotificationProvider = Provider<String?>((_) => null);

final telemetryRepositoryProvider = Provider<TelemetryRepository>(
  (ref) => LocalTelemetryRepository(ref.watch(databaseProvider)),
);
final insightRepositoryProvider = Provider<InsightRepository>(
  (ref) => LocalInsightRepository(ref.watch(databaseProvider)),
);
final partnerRepositoryProvider = Provider<PartnerRepository>(
  (ref) => LocalPartnerRepository(ref.watch(databaseProvider)),
);

final demoSessionProvider =
    StateNotifierProvider<DemoSessionController, DemoSessionState>((ref) {
      return DemoSessionController(
        ref.watch(databaseProvider),
        ref.watch(telemetryRepositoryProvider),
        ref.watch(insightRepositoryProvider),
        ref.watch(notificationProvider),
      );
    });

final unitsProvider = FutureProvider<List<BsfUnit>>((ref) {
  ref.watch(demoSessionProvider.select((state) => state.revision));
  return ref.watch(telemetryRepositoryProvider).getUnits();
});

final unitProvider = FutureProvider.family<BsfUnit?, int>((ref, id) {
  ref.watch(demoSessionProvider.select((state) => state.revision));
  return ref.watch(telemetryRepositoryProvider).getUnit(id);
});

final historyProvider = FutureProvider.family<List<SensorReading>, (int, int)>((
  ref,
  args,
) {
  ref.watch(demoSessionProvider.select((state) => state.revision));
  return ref
      .watch(telemetryRepositoryProvider)
      .getHistory(args.$1, Duration(hours: args.$2));
});

final insightsProvider = FutureProvider<List<InsightEvent>>((ref) {
  ref.watch(demoSessionProvider.select((state) => state.revision));
  return ref.watch(insightRepositoryProvider).getInsights();
});

final insightProvider = FutureProvider.family<InsightEvent?, int>((ref, id) {
  ref.watch(demoSessionProvider.select((state) => state.revision));
  return ref.watch(insightRepositoryProvider).getInsight(id);
});

final partnersProvider = FutureProvider<List<PartnerProfile>>(
  (ref) => ref.watch(partnerRepositoryProvider).getPartners(),
);

final listingsProvider = FutureProvider<List<PartnerListing>>((ref) {
  ref.watch(demoSessionProvider.select((state) => state.revision));
  return ref.watch(partnerRepositoryProvider).getListings();
});

final requestsProvider = FutureProvider<List<CooperationRequest>>((ref) {
  final state = ref.watch(demoSessionProvider);
  return ref.watch(partnerRepositoryProvider).getRequests(state.role);
});
