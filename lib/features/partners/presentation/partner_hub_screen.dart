import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../demo_session/domain/demo_session.dart';
import 'listings_screen.dart';
import 'partners_screen.dart';
import 'requests_screen.dart';

class PartnerHubScreen extends ConsumerWidget {
  const PartnerHubScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 3,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: 'Peluang'),
                    Tab(text: 'Pengajuan'),
                    Tab(text: 'Direktori'),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip:
                    ref.watch(demoSessionProvider).role == DemoRole.operator
                    ? 'Tawarkan hasil BSF'
                    : 'Buat kebutuhan',
                onPressed: () => context.push('/listings/new'),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        const Expanded(
          child: TabBarView(
            children: [
              ListingsScreen(ownedOnly: false),
              RequestsScreen(),
              PartnersScreen(),
            ],
          ),
        ),
      ],
    ),
  );
}
