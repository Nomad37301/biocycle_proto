import 'package:go_router/go_router.dart';

import '../../features/insights/presentation/insight_detail_screen.dart';
import '../../features/monitoring/presentation/unit_detail_screen.dart';
import '../../features/partners/domain/partner_models.dart';
import '../../features/partners/presentation/listing_form_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_shell.dart';

GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', builder: (_, _) => const AppShell()),
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
          ListingFormScreen(initial: state.extra! as PartnerListing),
    ),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  ],
);
