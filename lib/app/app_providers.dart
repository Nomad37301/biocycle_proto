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
final notificationsEnabledProvider = FutureProvider<bool>((ref) async {
  ref.watch(demoSessionProvider.select((state) => state.revision));
  return await ref
          .watch(databaseProvider)
          .getSetting('notifications_enabled') ==
      'true';
});

final telemetryRepositoryProvider = Provider<TelemetryRepository>(
  (ref) => LocalTelemetryRepository(ref.watch(databaseProvider)),
);
final insightRepositoryProvider = Provider<InsightRepository>(
  (ref) => LocalInsightRepository(ref.watch(databaseProvider)),
);
final partnerRepositoryProvider = Provider<PartnerRepository>(
  (ref) => LocalPartnerRepository(ref.watch(databaseProvider)),
);

final partnerRevisionProvider = StateProvider<int>((_) => 0);

final demoSessionProvider =
    StateNotifierProvider<DemoSessionController, DemoSessionState>((ref) {
      return DemoSessionController(
        ref.watch(databaseProvider),
        ref.watch(telemetryRepositoryProvider),
        ref.watch(insightRepositoryProvider),
        ref.watch(notificationProvider),
        ref.watch(partnerRepositoryProvider),
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

final insightActionsProvider = FutureProvider.family<List<InsightAction>, int>((
  ref,
  id,
) {
  ref.watch(demoSessionProvider.select((state) => state.revision));
  return ref.watch(insightRepositoryProvider).getActions(id);
});

final partnersProvider = FutureProvider<List<PartnerProfile>>((ref) {
  ref.watch(partnerRevisionProvider);
  return ref.watch(partnerRepositoryProvider).getPartners();
});

final partnerProvider = FutureProvider.family<PartnerProfile?, int>((ref, id) {
  ref.watch(partnerRevisionProvider);
  return ref.watch(partnerRepositoryProvider).getPartner(id);
});

final listingsProvider = FutureProvider<List<PartnerListing>>((ref) {
  ref.watch(partnerRevisionProvider);
  return ref.watch(partnerRepositoryProvider).getListings();
});

final listingProvider = FutureProvider.family<PartnerListing?, int>((ref, id) {
  ref.watch(partnerRevisionProvider);
  return ref.watch(partnerRepositoryProvider).getListing(id);
});

final requestsProvider = FutureProvider<List<CooperationRequest>>((ref) {
  final state = ref.watch(demoSessionProvider);
  ref.watch(partnerRevisionProvider);
  return ref
      .watch(partnerRepositoryProvider)
      .getRequests(state.role.organizationId);
});

final requestProvider = FutureProvider.family<CooperationRequest?, int>((
  ref,
  id,
) {
  ref.watch(partnerRevisionProvider);
  return ref.watch(partnerRepositoryProvider).getRequest(id);
});

final requestHistoryProvider = FutureProvider.family<List<RequestHistory>, int>(
  (ref, id) {
    ref.watch(partnerRevisionProvider);
    return ref.watch(partnerRepositoryProvider).getRequestHistory(id);
  },
);

final partnerActivityProvider =
    FutureProvider.family<PartnerActivitySummary, int>((ref, id) {
      ref.watch(partnerRevisionProvider);
      return ref.watch(partnerRepositoryProvider).getPartnerActivity(id);
    });

final networkFlowProvider = FutureProvider<NetworkFlowMetrics>((ref) {
  ref.watch(partnerRevisionProvider);
  ref.watch(demoSessionProvider.select((state) => state.revision));
  return ref.watch(partnerRepositoryProvider).getNetworkFlow();
});

final unitSummaryProvider = FutureProvider.family<UnitSummary?, (int, int)>((
  ref,
  args,
) {
  ref.watch(demoSessionProvider.select((state) => state.revision));
  return ref
      .watch(telemetryRepositoryProvider)
      .getSummary(args.$1, Duration(hours: args.$2));
});

class DashboardAttention {
  const DashboardAttention({
    required this.conditionEvents,
    required this.incompleteSop,
    required this.pendingRequests,
    this.firstInsightId,
    this.firstRequestId,
  });
  final int conditionEvents;
  final int incompleteSop;
  final int pendingRequests;
  final int? firstInsightId;
  final int? firstRequestId;
}

final dashboardAttentionProvider = FutureProvider<DashboardAttention>((
  ref,
) async {
  ref.watch(demoSessionProvider.select((state) => state.revision));
  ref.watch(partnerRevisionProvider);
  final db = ref.watch(databaseProvider).database;
  final since = DateTime.now()
      .subtract(const Duration(hours: 24))
      .toIso8601String();
  final eventRows = await db.rawQuery(
    "SELECT COUNT(*) AS total FROM condition_events WHERE occurred_at >= ? AND condition IN ('attention', 'critical')",
    [since],
  );
  final insightRows = await db.rawQuery('''
    SELECT id FROM insights
    WHERE resolved_at IS NULL AND length(completed_steps) < 5
    ORDER BY started_at LIMIT 100''');
  final requestRows = await db.query(
    'requests',
    columns: ['id'],
    where: "receiver_id = ? AND status = 'pending'",
    whereArgs: [DemoRole.operator.organizationId],
    orderBy: 'created_at',
  );
  return DashboardAttention(
    conditionEvents: (eventRows.first['total'] as num).toInt(),
    incompleteSop: insightRows.length,
    pendingRequests: requestRows.length,
    firstInsightId: insightRows.isEmpty ? null : insightRows.first['id'] as int,
    firstRequestId: requestRows.isEmpty ? null : requestRows.first['id'] as int,
  );
});

class DemoServicePlan {
  const DemoServicePlan({
    required this.status,
    required this.startedAt,
    required this.endsAt,
  });
  final String status;
  final DateTime startedAt;
  final DateTime endsAt;

  String get effectiveStatus => DateTime.now().isAfter(endsAt)
      ? 'kedaluwarsa'
      : status == 'active'
      ? 'aktif'
      : 'trial';
}

final demoServicePlanProvider = FutureProvider<DemoServicePlan>((ref) async {
  ref.watch(demoSessionProvider.select((state) => state.revision));
  final store = ref.watch(databaseProvider);
  final now = DateTime.now();
  final savedStart = await store.getSetting('service_started_at');
  final savedEnd = await store.getSetting('service_ends_at');
  final status = await store.getSetting('service_status') ?? 'trial';
  final startedAt = DateTime.tryParse(savedStart ?? '') ?? now;
  final endsAt =
      DateTime.tryParse(savedEnd ?? '') ?? now.add(const Duration(days: 14));
  if (savedStart == null ||
      savedStart.isEmpty ||
      savedEnd == null ||
      savedEnd.isEmpty) {
    await store.setSetting('service_started_at', startedAt.toIso8601String());
    await store.setSetting('service_ends_at', endsAt.toIso8601String());
  }
  return DemoServicePlan(status: status, startedAt: startedAt, endsAt: endsAt);
});
