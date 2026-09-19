import 'package:biocycle_proto/core/time/app_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppClock', () {
    test('FakeAppClock allows advancing time deterministically', () {
      final initial = DateTime.utc(2026, 9, 19, 10, 0, 0);
      final clock = FakeAppClock(initial);

      expect(clock.now, initial);
      clock.advance(const Duration(minutes: 15));
      expect(clock.now, DateTime.utc(2026, 9, 19, 10, 15, 0));
    });

    test('OffsetAppClock shifts base time correctly', () {
      final fakeBase = FakeAppClock(DateTime.utc(2026, 9, 19, 12, 0, 0));
      final offsetClock = OffsetAppClock(baseClock: fakeBase);

      expect(offsetClock.now, DateTime.utc(2026, 9, 19, 12, 0, 0));
      offsetClock.advance(const Duration(hours: 1));
      expect(offsetClock.now, DateTime.utc(2026, 9, 19, 13, 0, 0));
      offsetClock.reset();
      expect(offsetClock.now, DateTime.utc(2026, 9, 19, 12, 0, 0));
    });
  });
}
