import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _taps = StreamController.broadcast();

  Stream<String> get taps => _taps.stream;

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
        final payload = response.payload;
        if (payload != null) _taps.add(payload);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? launch?.notificationResponse?.payload
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
      payload: '/insights/$id',
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
      payload: payload,
    );
  }

  Future<void> cancelAll() async {
    if (!_isMobile) return;
    await _plugin.cancelAll();
  }
  void dispose() => _taps.close();
}
