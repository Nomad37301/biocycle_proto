import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:biocycle_proto/core/database/app_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String dbPath;
  late AppDatabase database;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('biocycle_seed_');
    dbPath = p.join(tempDir.path, 'test_seed.db');
    database = await AppDatabase.open(dbPath: dbPath);
  });

  tearDown(() async {
    await database.database.close();
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  Future<Map<String, int>> getTableCounts() async {
    final tables = [
      'units',
      'devices',
      'sensor_parameters',
      'telemetry_measurements',
      'readings',
      'demo_configurations',
      'partners',
      'listings',
      'settings',
    ];
    final counts = <String, int>{};
    for (final table in tables) {
      final res = await database.database.rawQuery(
        'SELECT COUNT(*) as c FROM $table',
      );
      counts[table] = res.first['c'] as int;
    }
    return counts;
  }

  test('Repeated initialize calls are strictly idempotent and do not duplicate or overwrite data', () async {
    // Initial count after open (open calls initialize/seed)
    final initialCounts = await getTableCounts();

    // Verify baseline counts exist
    expect(initialCounts['units'], equals(3));
    expect(initialCounts['devices'], equals(3));
    expect(
      initialCounts['sensor_parameters'],
      equals(12),
    ); // 3 units * 4 params
    expect(
      initialCounts['telemetry_measurements'],
      equals(300),
    ); // 3 units * 4 params * 25 samples
    expect(
      initialCounts['readings'],
      equals(75),
    ); // 3 units * 25 legacy samples

    // User makes a runtime modification
    await database.database.update(
      'units',
      {'name': 'Unit Dimodifikasi Pengguna'},
      where: 'id = ?',
      whereArgs: [1],
    );
    await database.setSetting('active_role', 'supplier');

    // Snapshot of telemetry before second initialize
    final sampleBefore = (await database.database.query(
      'telemetry_measurements',
      where: 'sample_id = ?',
      whereArgs: ['seed-1-substrateTemperature-0'],
    )).first;

    // Call initialize() 2nd time
    await database.initialize();

    // Call initialize() 3rd time
    await database.initialize();

    // Verify table counts remain IDENTICAL
    final countsAfter = await getTableCounts();
    for (final entry in initialCounts.entries) {
      expect(
        countsAfter[entry.key],
        equals(entry.value),
        reason: 'Table ${entry.key} count changed after repeated initialize!',
      );
    }

    // Verify user runtime changes were NOT overwritten by re-seed
    final unit1 = (await database.database.query(
      'units',
      where: 'id = ?',
      whereArgs: [1],
    )).first;
    expect(unit1['name'], equals('Unit Dimodifikasi Pengguna'));

    final userRole = await database.getSetting('active_role');
    expect(userRole, equals('supplier'));

    // Verify seed timestamps and stable IDs did not change
    final sampleAfter = (await database.database.query(
      'telemetry_measurements',
      where: 'sample_id = ?',
      whereArgs: ['seed-1-substrateTemperature-0'],
    )).first;
    expect(sampleAfter['measured_at'], equals(sampleBefore['measured_at']));
    expect(sampleAfter['id'], equals(sampleBefore['id']));
  });
}
