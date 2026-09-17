import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_providers.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/demo_session/domain/demo_session.dart';
import '../../features/demo_session/presentation/demo_controls.dart';
import '../../features/insights/presentation/insights_screen.dart';
import '../../features/monitoring/presentation/units_screen.dart';
import '../../features/partners/presentation/listings_screen.dart';
import '../../features/partners/presentation/partner_hub_screen.dart';
import '../../features/partners/presentation/partners_screen.dart';
import '../../features/partners/presentation/requests_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int index = 0;
  DemoRole? previousRole;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoSessionProvider);
    if (previousRole != state.role) {
      previousRole = state.role;
      index = 0;
    }
    final destinations = _destinations(state.role);
    final pages = _pages(state.role);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Image.asset(
              'asset/ChatGPT Image Aug 30, 2026, 10_03_50 PM.png',
              width: 38,
              height: 38,
              semanticLabel: 'BioCycle',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.role.organization,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Simulasi peran · ${state.role.label}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Kontrol skenario sensor',
            onPressed: () => DemoControls.show(context),
            icon: Icon(
              state.running
                  ? Icons.science_outlined
                  : Icons.pause_circle_outline,
            ),
          ),
          PopupMenuButton<Object>(
            tooltip: 'Akun demo dan pengaturan',
            onSelected: (value) {
              if (value is DemoRole) {
                ref.read(demoSessionProvider.notifier).setRole(value);
              }
              if (value == 'settings') context.push('/settings');
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('Beralih workspace demo'),
              ),
              ...DemoRole.values.map(
                (role) => PopupMenuItem(
                  value: role,
                  child: Row(
                    children: [
                      Icon(
                        role == state.role ? Icons.check : Icons.person_outline,
                      ),
                      const SizedBox(width: 10),
                      Text(role.label),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 10),
                    Text('Pengaturan demo'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: destinations,
      ),
    );
  }

  List<Widget> _pages(DemoRole role) => switch (role) {
    DemoRole.operator => const [
      DashboardScreen(),
      UnitsScreen(),
      InsightsScreen(),
      PartnerHubScreen(),
    ],
    DemoRole.supplier => const [
      DashboardScreen(),
      ListingsScreen(ownedOnly: true),
      RequestsScreen(),
      PartnersScreen(),
    ],
    DemoRole.buyer => const [
      DashboardScreen(),
      ListingsScreen(ownedOnly: true),
      RequestsScreen(),
      PartnerHubScreen(),
    ],
  };

  List<NavigationDestination> _destinations(DemoRole role) => switch (role) {
    DemoRole.operator => const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Beranda',
      ),
      NavigationDestination(
        icon: Icon(Icons.sensors_outlined),
        selectedIcon: Icon(Icons.sensors),
        label: 'Unit',
      ),
      NavigationDestination(
        icon: Icon(Icons.notification_important_outlined),
        selectedIcon: Icon(Icons.notification_important),
        label: 'Insight',
      ),
      NavigationDestination(
        icon: Icon(Icons.handshake_outlined),
        selectedIcon: Icon(Icons.handshake),
        label: 'Mitra',
      ),
    ],
    DemoRole.supplier => const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Beranda',
      ),
      NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: 'Penawaran',
      ),
      NavigationDestination(
        icon: Icon(Icons.assignment_outlined),
        selectedIcon: Icon(Icons.assignment),
        label: 'Pengajuan',
      ),
      NavigationDestination(
        icon: Icon(Icons.groups_outlined),
        selectedIcon: Icon(Icons.groups),
        label: 'Mitra',
      ),
    ],
    DemoRole.buyer => const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Beranda',
      ),
      NavigationDestination(
        icon: Icon(Icons.shopping_basket_outlined),
        selectedIcon: Icon(Icons.shopping_basket),
        label: 'Kebutuhan',
      ),
      NavigationDestination(
        icon: Icon(Icons.assignment_outlined),
        selectedIcon: Icon(Icons.assignment),
        label: 'Pengajuan',
      ),
      NavigationDestination(
        icon: Icon(Icons.groups_outlined),
        selectedIcon: Icon(Icons.groups),
        label: 'Mitra',
      ),
    ],
  };
}
