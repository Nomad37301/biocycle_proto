import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../demo_session/domain/demo_session.dart';
import 'listings_screen.dart';
import 'partners_screen.dart';
import 'pitch_estimate_screen.dart';
import 'requests_screen.dart';

class PartnerHubScreen extends ConsumerWidget {
  const PartnerHubScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operator = ref.watch(demoSessionProvider).role == DemoRole.operator;
    return DefaultTabController(
      length: operator ? 5 : 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(text: 'Peluang'),
                if (operator) const Tab(text: 'Penawaran saya'),
                const Tab(text: 'Pengajuan'),
                const Tab(text: 'Direktori'),
                if (operator) const Tab(text: 'Estimasi'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const ListingsScreen(ownedOnly: false),
                if (operator) const ListingsScreen(ownedOnly: true),
                const RequestsScreen(),
                const PartnersScreen(),
                if (operator) const PitchEstimateScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
