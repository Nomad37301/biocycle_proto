import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _taps = StreamController.broadcast();

  Stream<String> get taps => _taps.stream;
  int sessionGeneration = 1;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<String?> initialize() async {
    if (!_isMobile) return null;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = safeRoute(response.payload);
        if (route != null) _taps.add(route);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? safeRoute(launch?.notificationResponse?.payload)
        : null;
  }

  Future<bool> requestPermission() async {
    if (!_isMobile) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<void> showInsight({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isMobile) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'biocycle_alerts',
          'Peringatan kondisi',
          channelDescription: 'Perubahan kondisi pada unit budidaya BSF',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: _withGeneration('/insights/$id'),
    );
  }

  Future<void> showPartner({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_isMobile) return;
    await _plugin.show(
      id: 100000 + id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'biocycle_partners',
          'Aktivitas kemitraan',
          channelDescription: 'Perubahan pengajuan kerja sama lokal',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: _withGeneration(payload),
    );
  }

  Future<void> cancelAll() async {
    if (!_isMobile) return;
    await _plugin.cancelAll();
  }

  String? safeRoute(String? payload) {
    if (payload == null) return null;
    final uri = Uri.tryParse(payload);
    if (uri == null || !uri.path.startsWith('/')) return null;
    final generation = int.tryParse(uri.queryParameters['session'] ?? '');
    if (generation != sessionGeneration) return null;
    const allowedPrefixes = [
      '/insights/',
      '/requests/',
      '/units/',
      '/listings/',
      '/partners/',
    ];
    return allowedPrefixes.any(uri.path.startsWith) ? uri.toString() : null;
  }

  String _withGeneration(String payload) {
    final uri = Uri.parse(payload);
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'session': '$sessionGeneration',
          },
        )
        .toString();
  }

  void dispose() => _taps.close();
}
