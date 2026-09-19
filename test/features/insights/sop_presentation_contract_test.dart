import 'package:biocycle_proto/features/insights/domain/insight_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setiap alert kind v6 memiliki SOP presentasi', () {
    const kinds = [
      'thermalAttention',
      'thermalCritical',
      'substrateWet',
      'substrateDry',
      'deviceOffline',
      'sensorError',
    ];

    for (final kind in kinds) {
      expect(sopSteps[kind], isNotEmpty, reason: 'SOP kosong untuk $kind');
    }
  });
}
