import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_providers.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

class BioCycleApp extends ConsumerStatefulWidget {
  const BioCycleApp({super.key, this.initialNotification});
  final String? initialNotification;
  @override
  ConsumerState<BioCycleApp> createState() => _BioCycleAppState();
}

class _BioCycleAppState extends ConsumerState<BioCycleApp>
    with WidgetsBindingObserver {
  late final GoRouter router;
  StreamSubscription<String>? tapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    router = buildRouter(initialLocation: widget.initialNotification ?? '/');
    tapSubscription = ref.read(notificationProvider).taps.listen(router.go);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(demoSessionProvider.notifier).start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(demoSessionProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      controller.resumeForLifecycle();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.pauseForLifecycle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tapSubscription?.cancel();
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'BioCycle',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    routerConfig: router,
  );
}
