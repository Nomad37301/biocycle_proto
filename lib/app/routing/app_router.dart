import 'package:go_router/go_router.dart';

import '../../features/insights/presentation/insight_detail_screen.dart';
import '../../features/monitoring/presentation/unit_detail_v2.dart';
import '../../features/monitoring/presentation/unit_summary_screen.dart';
import '../../features/partners/presentation/listing_detail_screen.dart';
import '../../features/partners/presentation/listing_form_screen.dart';
import '../../features/partners/presentation/partner_detail_screen.dart';
import '../../features/partners/presentation/request_detail_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import 'app_shell.dart';

GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/', builder: (_, _) => const AppShell()),
    GoRoute(
      path: '/units/:id/summary',
      builder: (_, state) =>
          UnitSummaryScreen(unitId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/units/:id',
      builder: (_, state) =>
          UnitDetailScreen(unitId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/insights/:id',
      builder: (_, state) => InsightDetailScreen(
        insightId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/listings/new',
      builder: (_, _) => const ListingFormScreen(),
    ),
    GoRoute(
      path: '/listings/:id/edit',
      builder: (_, state) =>
          ListingEditScreen(listingId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/listings/:id',
      builder: (_, state) => ListingDetailScreen(
        listingId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/partners/:id',
      builder: (_, state) => PartnerDetailScreen(
        partnerId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/requests/:id',
      builder: (_, state) => RequestDetailScreen(
        requestId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  ],
);
