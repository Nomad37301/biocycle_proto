import 'package:biocycle_proto/core/notifications/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payload hanya membuka route pada session generation aktif', () {
    final service = NotificationService()..sessionGeneration = 4;

    expect(service.safeRoute('/insights/7?session=4'), '/insights/7?session=4');
    expect(service.safeRoute('/insights/7?session=3'), isNull);
    expect(service.safeRoute('/insights/7'), isNull);
    expect(service.safeRoute('/settings?session=4'), isNull);
    expect(service.safeRoute('https://example.com?session=4'), isNull);
    service.dispose();
  });
}
