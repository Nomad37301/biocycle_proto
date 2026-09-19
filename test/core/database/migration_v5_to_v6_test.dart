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

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'biocycle_mig_v5_v6_',
    );
    dbPath = p.join(tempDir.path, 'test_mig.db');
  });

  tearDown(() async {
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  Future<void> createV5Database(String path) async {
    final db = await openDatabase(
      path,
      version: 5,
      onCreate: (db, _) async {
        // Create baseline v5 tables
        await db.execute('''CREATE TABLE units(
          id INTEGER PRIMARY KEY, name TEXT NOT NULL, kit_code TEXT NOT NULL,
          temperature REAL NOT NULL, humidity REAL NOT NULL, medium TEXT NOT NULL,
          is_connected INTEGER NOT NULL, updated_at TEXT NOT NULL,
          last_synced_at TEXT, firmware TEXT NOT NULL DEFAULT 'demo-1.0.0',
          temperature_attention REAL NOT NULL DEFAULT 35,
          temperature_critical REAL NOT NULL DEFAULT 38,
          humidity_attention REAL NOT NULL DEFAULT 80,
          humidity_critical REAL NOT NULL DEFAULT 90)''');

        await db.execute('''CREATE TABLE readings(
          id INTEGER PRIMARY KEY AUTOINCREMENT, unit_id INTEGER NOT NULL,
          temperature REAL NOT NULL, humidity REAL NOT NULL, medium TEXT NOT NULL,
          recorded_at TEXT NOT NULL)''');

        await db.execute(
          '''CREATE TABLE insights(
          id INTEGER PRIMARY KEY AUTOINCREMENT, unit_id INTEGER NOT NULL,
          unit_name TEXT NOT NULL, kind TEXT NOT NULL, severity TEXT NOT NULL,
          cause TEXT NOT NULL, recommendation TEXT NOT NULL,
          started_at TEXT NOT NULL, updated_at TEXT NOT NULL, resolved_at TEXT,
          note TEXT NOT NULL DEFAULT '', completed_steps TEXT NOT NULL DEFAULT '')''',
        );

        await db.execute(
          '''CREATE TABLE insight_actions(
          id INTEGER PRIMARY KEY AUTOINCREMENT, insight_id INTEGER NOT NULL,
          completed_steps TEXT NOT NULL, note TEXT NOT NULL, created_at TEXT NOT NULL,
          before_temperature REAL, before_humidity REAL, before_recorded_at TEXT,
          after_temperature REAL, after_humidity REAL, after_recorded_at TEXT,
          FOREIGN KEY(insight_id) REFERENCES insights(id) ON DELETE CASCADE)''',
        );

        await db.execute('''CREATE TABLE partners(
          id INTEGER PRIMARY KEY, name TEXT NOT NULL, role TEXT NOT NULL,
          region TEXT NOT NULL)''');

        await db.execute('''CREATE TABLE listings(
          id INTEGER PRIMARY KEY AUTOINCREMENT, owner_id INTEGER NOT NULL,
          owner_role TEXT NOT NULL, owner_name TEXT NOT NULL, kind TEXT NOT NULL,
          material TEXT NOT NULL, quantity_kg REAL NOT NULL,
          available_date TEXT NOT NULL, region TEXT NOT NULL, note TEXT NOT NULL,
          is_active INTEGER NOT NULL, created_at TEXT NOT NULL DEFAULT '')''');

        await db.execute('''CREATE TABLE settings(
          key TEXT PRIMARY KEY, value TEXT NOT NULL)''');

        // Insert legacy sample data
        await db.insert('units', {
          'id': 1,
          'name': 'Unit Baseline V5',
          'kit_code': 'BCK-001',
          'temperature': 31.0,
          'humidity': 65.0,
          'medium': 'Biomassa',
          'is_connected': 1,
          'updated_at': '2026-09-18T10:00:00.000Z',
        });

        await db.insert('insights', {
          'id': 1,
          'unit_id': 1,
          'unit_name': 'Unit Baseline V5',
          'kind': 'thermalAttention',
          'severity': 'attention',
          'cause': 'Suhu naik',
          'recommendation': 'Buka jendela',
          'started_at': '2026-09-18T10:00:00.000Z',
          'updated_at': '2026-09-18T10:00:00.000Z',
        });

        await db.insert('settings', {'key': 'seed_version', 'value': '5'});
      },
    );
    await db.close();
  }

  test('Migration from v5 to v6 upgrades schema atomically, preserves data, and adds constraint indexes', () async {
    // 1. Setup v5 baseline database
    await createV5Database(dbPath);

    // 2. Open via AppDatabase (triggers onUpgrade to v6)
    final appDb = await AppDatabase.open(dbPath: dbPath);

    // 3. Verify target version is 6
    final verResult = await appDb.database.rawQuery('PRAGMA user_version');
    expect(verResult.first['user_version'], equals(6));

    // 4. Verify legacy data is preserved
    final unitRows = await appDb.database.query(
      'units',
      where: 'id = ?',
      whereArgs: [1],
    );
    expect(unitRows.length, equals(1));
    expect(unitRows.first['name'], equals('Unit Baseline V5'));

    final insightRows = await appDb.database.query(
      'insights',
      where: 'id = ?',
      whereArgs: [1],
    );
    expect(insightRows.length, equals(1));
    expect(insightRows.first['kind'], equals('thermalAttention'));

    // 5. Verify v6 tables exist
    final tables = await appDb.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final tableNames = tables.map((t) => t['name'] as String).toSet();
    expect(
      tableNames,
      containsAll([
        'devices',
        'sensor_parameters',
        'telemetry_measurements',
        'demo_configurations',
      ]),
    );

    // 6. Verify devices and sensor_parameters mapped from unit
    final deviceRows = await appDb.database.query(
      'devices',
      where: 'unit_id = ?',
      whereArgs: [1],
    );
    expect(deviceRows.length, equals(1));
    expect(deviceRows.first['id'], equals('demo-kit-001'));

    final paramRows = await appDb.database.query(
      'sensor_parameters',
      where: 'device_id = ?',
      whereArgs: ['demo-kit-001'],
    );
    expect(paramRows.length, equals(4));

    // 7. Verify unique indexes exist on migrated database
    final indexes = await appDb.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index'",
    );
    final indexNames = indexes.map((i) => i['name'] as String).toSet();
    expect(indexNames, contains('idx_actions_idempotency'));
    expect(indexNames, contains('idx_active_insight_episode'));

    // 8. Verify idempotency unique constraint works
    await appDb.database.insert('insight_actions', {
      'insight_id': 1,
      'completed_steps': 'Step 1',
      'note': 'Test 1',
      'created_at': '2026-09-19T10:00:00.000Z',
      'idempotency_key': 'unique-key-1',
    });

    // Inserting same idempotency key must violate unique constraint
    expect(
      () => appDb.database.insert('insight_actions', {
        'insight_id': 1,
        'completed_steps': 'Step 2',
        'note': 'Test 2',
        'created_at': '2026-09-19T10:01:00.000Z',
        'idempotency_key': 'unique-key-1',
      }, conflictAlgorithm: ConflictAlgorithm.fail),
      throwsA(isA<DatabaseException>()),
    );

    await appDb.database.close();
  });
}
