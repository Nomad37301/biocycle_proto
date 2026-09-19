import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../config/demo_configuration.dart';

class AppDatabase {
  AppDatabase._(this.database);
  final Database database;

  static Future<AppDatabase> open({String? dbPath}) async {
    final String path;
    if (dbPath != null) {
      path = dbPath;
    } else if (kIsWeb) {
      path = 'biocycle_demo.db';
    } else {
      final root = await getDatabasesPath();
      path = p.join(root, 'biocycle_demo.db');
    }
    final database = await openDatabase(
      path,
      version: 6,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await _createSchema(db);
        await _createV6Tables(db);
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await _createSettingsTable(db);
          await _seedSettings(db);
        }
        if (oldVersion < 3) await _migrateToV3(db);
        if (oldVersion < 4) await _migrateToV4(db);
        if (oldVersion < 5) await _migrateToV5(db);
        if (oldVersion < 6) await _migrateToV6(db);
      },
      onDowngrade: (db, oldVersion, newVersion) {
        throw StateError(
          'Database downgrade dari versi $oldVersion ke $newVersion tidak diizinkan.',
        );
      },
    );
    return AppDatabase._(database);
  }

  static Future<void> _createSchema(Database db) async {
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
      note TEXT NOT NULL DEFAULT '', completed_steps TEXT NOT NULL DEFAULT '',
      episode_id TEXT, parameter_key TEXT, rule_id TEXT, config_version TEXT,
      trigger_value REAL, trigger_measured_at TEXT,
      acknowledged_at TEXT, acknowledged_by TEXT, recovered_at TEXT, sop_version TEXT)''',
    );
    await db.execute('''CREATE TABLE insight_actions(
      id INTEGER PRIMARY KEY AUTOINCREMENT, insight_id INTEGER NOT NULL,
      completed_steps TEXT NOT NULL, note TEXT NOT NULL, created_at TEXT NOT NULL,
      before_temperature REAL, before_humidity REAL, before_recorded_at TEXT,
      after_temperature REAL, after_humidity REAL, after_recorded_at TEXT,
      idempotency_key TEXT, actor_id INTEGER, actor_name TEXT,
      response_type TEXT, checklist TEXT, before_measurement_id INTEGER,
      after_measurement_id INTEGER, before_value REAL, after_value REAL,
      evaluation_due_at TEXT, evaluation_status TEXT,
      FOREIGN KEY(insight_id) REFERENCES insights(id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE partners(
      id INTEGER PRIMARY KEY, name TEXT NOT NULL, role TEXT NOT NULL,
      region TEXT NOT NULL)''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_actions_idempotency ON insight_actions(idempotency_key)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_active_insight_episode ON insights(unit_id, parameter_key) WHERE resolved_at IS NULL',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_readings_unit_time ON readings(unit_id, recorded_at)',
    );
    await _createPartnerTables(db);
    await _createSettingsTable(db);
  }

  static Future<void> _createV6Tables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS devices(
      id TEXT PRIMARY KEY, unit_id INTEGER NOT NULL, code TEXT NOT NULL UNIQUE,
      firmware TEXT NOT NULL DEFAULT 'demo-1.0.0',
      is_connected INTEGER NOT NULL DEFAULT 1,
      last_seen_at TEXT,
      FOREIGN KEY(unit_id) REFERENCES units(id) ON DELETE CASCADE)''');

    await db.execute('''CREATE TABLE IF NOT EXISTS sensor_parameters(
      id INTEGER PRIMARY KEY AUTOINCREMENT, device_id TEXT NOT NULL,
      parameter_key TEXT NOT NULL, label TEXT NOT NULL, unit TEXT NOT NULL,
      profile TEXT NOT NULL, config_version TEXT NOT NULL DEFAULT 'demo-v1',
      UNIQUE(device_id, parameter_key),
      FOREIGN KEY(device_id) REFERENCES devices(id) ON DELETE CASCADE)''');

    await db.execute('''CREATE TABLE IF NOT EXISTS telemetry_measurements(
      id INTEGER PRIMARY KEY AUTOINCREMENT, unit_id INTEGER NOT NULL,
      device_id TEXT NOT NULL, parameter_key TEXT NOT NULL, value REAL,
      measured_at TEXT NOT NULL, received_at TEXT NOT NULL,
      quality TEXT NOT NULL DEFAULT 'valid',
      source TEXT NOT NULL DEFAULT 'simulated',
      config_version TEXT NOT NULL DEFAULT 'demo-v1',
      sample_id TEXT NOT NULL,
      UNIQUE(device_id, parameter_key, sample_id),
      FOREIGN KEY(unit_id) REFERENCES units(id) ON DELETE CASCADE,
      FOREIGN KEY(device_id) REFERENCES devices(id) ON DELETE CASCADE)''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_telemetry_query ON telemetry_measurements(unit_id, parameter_key, measured_at, id)',
    );

    await db.execute('''CREATE TABLE IF NOT EXISTS demo_configurations(
      version TEXT PRIMARY KEY, payload TEXT NOT NULL,
      created_at TEXT NOT NULL, provenance TEXT NOT NULL)''');
  }

  static Future<void> _createPartnerTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE listings(
      id INTEGER PRIMARY KEY AUTOINCREMENT, owner_id INTEGER NOT NULL,
      owner_role TEXT NOT NULL, owner_name TEXT NOT NULL, kind TEXT NOT NULL,
      material TEXT NOT NULL, quantity_kg REAL NOT NULL,
      available_date TEXT NOT NULL, region TEXT NOT NULL, note TEXT NOT NULL,
      is_active INTEGER NOT NULL, created_at TEXT NOT NULL DEFAULT '')''');
    await db.execute(
      '''CREATE TABLE requests(
      id INTEGER PRIMARY KEY AUTOINCREMENT, listing_id INTEGER NOT NULL,
      sender_id INTEGER NOT NULL, receiver_id INTEGER NOT NULL,
      completion_id INTEGER NOT NULL, sender_role TEXT NOT NULL,
      receiver_role TEXT NOT NULL, sender_name TEXT NOT NULL,
      receiver_name TEXT NOT NULL, summary TEXT NOT NULL,
      quantity_kg REAL NOT NULL, initial_quantity_kg REAL NOT NULL DEFAULT 0,
      accepted_quantity_kg REAL, history_limited INTEGER NOT NULL DEFAULT 0,
      note TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
    );
    await db.execute('''CREATE TABLE request_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT, request_id INTEGER NOT NULL,
      actor_id INTEGER NOT NULL, actor_name TEXT NOT NULL, status TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL,
      FOREIGN KEY(request_id) REFERENCES requests(id) ON DELETE CASCADE)''');
    await db.execute(
      'CREATE INDEX request_listing_status ON requests(listing_id, status)',
    );
    await db.execute('''CREATE TABLE app_notifications(
      id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL,
      request_id INTEGER, kind TEXT NOT NULL, title TEXT NOT NULL,
      body TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL,
      delivered_at TEXT)''');
    await db.execute('''CREATE TABLE condition_events(
      id INTEGER PRIMARY KEY AUTOINCREMENT, unit_id INTEGER NOT NULL,
      condition TEXT NOT NULL, occurred_at TEXT NOT NULL)''');
  }

  static Future<void> _createSettingsTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE settings(
      key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
  }

  static Future<void> _migrateToV3(Database db) async {
    await db.execute('ALTER TABLE listings RENAME TO listings_v2');
    await db.execute('ALTER TABLE requests RENAME TO requests_v2');
    await _createPartnerTables(db);
    await db.execute('''INSERT INTO listings(
      id, owner_id, owner_role, owner_name, kind, material, quantity_kg,
      available_date, region, note, is_active)
      SELECT id,
        CASE owner_role WHEN 'supplier' THEN 1 WHEN 'operator' THEN 3 ELSE 4 END,
        owner_role,
        CASE owner_role WHEN 'supplier' THEN 'Pasar Organik Jimbaran'
          WHEN 'operator' THEN 'Unit BSF Taman Sari'
          ELSE 'Ternak Sejahtera Bali' END,
        kind, material, quantity_kg, available_date, region, note, is_active
      FROM listings_v2''');
    await db.execute('''INSERT INTO requests(
      id, listing_id, sender_id, receiver_id, completion_id,
      sender_role, receiver_role, sender_name, receiver_name, summary,
      quantity_kg, note, status, created_at, updated_at)
      SELECT id, listing_id,
        CASE sender_role WHEN 'supplier' THEN 1 WHEN 'operator' THEN 3 ELSE 4 END,
        CASE receiver_role WHEN 'supplier' THEN 1 WHEN 'operator' THEN 3 ELSE 4 END,
        CASE completion_role WHEN 'supplier' THEN 1 WHEN 'operator' THEN 3 ELSE 4 END,
        sender_role, receiver_role,
        CASE sender_role WHEN 'supplier' THEN 'Pasar Organik Jimbaran'
          WHEN 'operator' THEN 'Unit BSF Taman Sari'
          ELSE 'Ternak Sejahtera Bali' END,
        CASE receiver_role WHEN 'supplier' THEN 'Pasar Organik Jimbaran'
          WHEN 'operator' THEN 'Unit BSF Taman Sari'
          ELSE 'Ternak Sejahtera Bali' END,
        summary, quantity_kg, '', status, created_at, updated_at
      FROM requests_v2''');
    await db.execute('''INSERT INTO request_history(
      request_id, actor_id, actor_name, status, note, created_at)
      SELECT id,
        CASE
          WHEN status IN ('accepted', 'rejected') THEN receiver_id
          WHEN status = 'completed' THEN completion_id
          ELSE sender_id END,
        CASE
          WHEN status IN ('accepted', 'rejected') THEN receiver_name
          WHEN status = 'completed' AND completion_id = sender_id THEN sender_name
          WHEN status = 'completed' THEN receiver_name
          ELSE sender_name END,
        status, 'Status terakhir dari data versi sebelumnya.', updated_at
      FROM requests''');
    await db.execute('''CREATE TABLE insight_actions(
      id INTEGER PRIMARY KEY AUTOINCREMENT, insight_id INTEGER NOT NULL,
      completed_steps TEXT NOT NULL, note TEXT NOT NULL, created_at TEXT NOT NULL,
      FOREIGN KEY(insight_id) REFERENCES insights(id) ON DELETE CASCADE)''');
    await db.execute('''INSERT INTO insight_actions(
      insight_id, completed_steps, note, created_at)
      SELECT id, completed_steps, note, updated_at FROM insights
      WHERE length(note) > 0 OR length(completed_steps) > 0''');
    await db.execute('DROP TABLE requests_v2');
    await db.execute('DROP TABLE listings_v2');
    await db.delete('partners');
    await _seedPartners(db);
    await _seedSettings(db);
  }

  static Future<void> _migrateToV4(Database db) async {
    await _addColumnIfMissing(db, 'units', 'last_synced_at', 'TEXT');
    await _addColumnIfMissing(
      db,
      'units',
      'firmware',
      "TEXT NOT NULL DEFAULT 'demo-1.0.0'",
    );
    await _addColumnIfMissing(
      db,
      'units',
      'temperature_attention',
      'REAL NOT NULL DEFAULT 35',
    );
    await _addColumnIfMissing(
      db,
      'units',
      'temperature_critical',
      'REAL NOT NULL DEFAULT 38',
    );
    await _addColumnIfMissing(
      db,
      'units',
      'humidity_attention',
      'REAL NOT NULL DEFAULT 80',
    );
    await _addColumnIfMissing(
      db,
      'units',
      'humidity_critical',
      'REAL NOT NULL DEFAULT 90',
    );
    await _addColumnIfMissing(db, 'requests', 'initial_quantity_kg', 'REAL');
    await _addColumnIfMissing(db, 'requests', 'accepted_quantity_kg', 'REAL');
    await _addColumnIfMissing(
      db,
      'requests',
      'history_limited',
      'INTEGER NOT NULL DEFAULT 0',
    );
    for (final column in const [
      'before_temperature',
      'before_humidity',
      'after_temperature',
      'after_humidity',
    ]) {
      await _addColumnIfMissing(db, 'insight_actions', column, 'REAL');
    }
    for (final column in const ['before_recorded_at', 'after_recorded_at']) {
      await _addColumnIfMissing(db, 'insight_actions', column, 'TEXT');
    }
    await db.execute(
      'UPDATE units SET last_synced_at = updated_at WHERE last_synced_at IS NULL',
    );
    await db.execute(
      'UPDATE requests SET initial_quantity_kg = quantity_kg '
      'WHERE initial_quantity_kg IS NULL OR initial_quantity_kg <= 0',
    );
    await db.execute(
      "UPDATE requests SET accepted_quantity_kg = quantity_kg "
      "WHERE accepted_quantity_kg IS NULL AND status IN ('accepted', 'completed')",
    );
    await db.execute('UPDATE requests SET history_limited = 1');
    await db.execute('''CREATE TABLE IF NOT EXISTS app_notifications(
      id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL,
      request_id INTEGER, kind TEXT NOT NULL, title TEXT NOT NULL,
      body TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL,
      delivered_at TEXT)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS condition_events(
      id INTEGER PRIMARY KEY AUTOINCREMENT, unit_id INTEGER NOT NULL,
      condition TEXT NOT NULL, occurred_at TEXT NOT NULL)''');
    await _seedNewSettings(db);
  }

  static Future<void> _migrateToV5(Database db) async {
    await _addColumnIfMissing(
      db,
      'listings',
      'created_at',
      "TEXT NOT NULL DEFAULT ''",
    );
    await db.execute(
      'UPDATE listings SET created_at = ? WHERE created_at IS NULL OR created_at = ?',
      [DateTime.now().toIso8601String(), ''],
    );
  }

  static Future<void> _migrateToV6(Database db) async {
    await db.transaction((txn) async {
      await _createV6Tables(txn);
      for (final column in const [
        'episode_id TEXT',
        'parameter_key TEXT',
        'rule_id TEXT',
        'config_version TEXT',
        'trigger_value REAL',
        'trigger_measured_at TEXT',
        'acknowledged_at TEXT',
        'acknowledged_by TEXT',
        'recovered_at TEXT',
        'sop_version TEXT',
      ]) {
        final parts = column.split(' ');
        await _addColumnIfMissing(
          txn,
          'insights',
          parts[0],
          parts.sublist(1).join(' '),
        );
      }

      for (final column in const [
        'idempotency_key TEXT',
        'actor_id INTEGER',
        'actor_name TEXT',
        'response_type TEXT',
        'checklist TEXT',
        'before_measurement_id INTEGER',
        'after_measurement_id INTEGER',
        'before_value REAL',
        'after_value REAL',
        'evaluation_due_at TEXT',
        'evaluation_status TEXT',
      ]) {
        final parts = column.split(' ');
        await _addColumnIfMissing(
          txn,
          'insight_actions',
          parts[0],
          parts.sublist(1).join(' '),
        );
      }

      await txn.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_actions_idempotency ON insight_actions(idempotency_key)',
      );
      await txn.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_active_insight_episode ON insights(unit_id, parameter_key) WHERE resolved_at IS NULL',
      );
      await txn.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_readings_unit_time ON readings(unit_id, recorded_at)',
      );

      // Map existing units into devices
      final unitRows = await txn.query('units');
      for (final row in unitRows) {
        final unitId = row['id'] as int;
        final kitCode = row['kit_code'] as String;
        final deviceId = 'demo-kit-00$unitId';
        await txn.insert('devices', {
          'id': deviceId,
          'unit_id': unitId,
          'code': kitCode,
          'firmware': 'demo-1.0.0',
          'is_connected': row['is_connected'],
          'last_seen_at': row['updated_at'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        for (final param in _standardParameters) {
          await txn.insert('sensor_parameters', {
            'device_id': deviceId,
            'parameter_key': param['key'],
            'label': param['label'],
            'unit': param['unit'],
            'profile': param['profile'],
            'config_version': 'demo-v1',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // Save default DemoConfiguration
      const config = DemoConfiguration();
      await txn.insert('demo_configurations', {
        'version': config.version,
        'payload': config.toJson(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'provenance': 'migrated-v6',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await txn.insert('settings', {
        'key': 'seed_version',
        'value': '6',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  static Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String declaration,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((item) => item['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $declaration');
  }

  static const _standardParameters = [
    {
      'key': 'ambientTemperature',
      'label': 'Suhu udara',
      'unit': '°C',
      'profile': 'DHT22',
    },
    {
      'key': 'ambientHumidity',
      'label': 'Kelembapan udara',
      'unit': '% RH',
      'profile': 'DHT22',
    },
    {
      'key': 'substrateTemperature',
      'label': 'Suhu substrat',
      'unit': '°C',
      'profile': 'DS18B20',
    },
    {
      'key': 'substrateMoisture',
      'label': 'Kelembapan substrat (indeks demo)',
      'unit': '%',
      'profile': 'Capacitive Sensor',
    },
  ];

  static Future<void> _seed(DatabaseExecutor db) async {
    final existingSeed = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['seed_version'],
    );
    if (existingSeed.isNotEmpty && existingSeed.first['value'] == '6') {
      return;
    }

    final now = DateTime.now().toUtc();
    final units = [
      [
        1,
        'Unit BSF 01 - Rak A',
        'BCK-001',
        30.0,
        65.0,
        'Biomassa Bungkil Sawit',
      ],
      [
        2,
        'Unit BSF 02 - Rak B',
        'BCK-002',
        30.0,
        65.0,
        'Biomassa Limbah Sayur',
      ],
      [3, 'Unit BSF 03 - Nursery', 'BCK-003', 30.0, 65.0, 'Dedak & Buah'],
    ];

    for (final unit in units) {
      final unitId = unit[0] as int;
      final unitName = unit[1] as String;
      final kitCode = unit[2] as String;
      final substrateTemp = unit[3] as double;
      final substrateMoist = unit[4] as double;
      final medium = unit[5] as String;
      final deviceId = 'demo-kit-00$unitId';

      await db.insert('units', {
        'id': unitId,
        'name': unitName,
        'kit_code': kitCode,
        'temperature': substrateTemp,
        'humidity': substrateMoist,
        'medium': medium,
        'is_connected': 1,
        'updated_at': now.toIso8601String(),
        'last_synced_at': now.toIso8601String(),
        'firmware': 'demo-1.0.0',
        'temperature_attention': 35,
        'temperature_critical': 38,
        'humidity_attention': 80,
        'humidity_critical': 90,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await db.insert('devices', {
        'id': deviceId,
        'unit_id': unitId,
        'code': kitCode,
        'firmware': 'demo-1.0.0',
        'is_connected': 1,
        'last_seen_at': now.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      for (final param in _standardParameters) {
        await db.insert('sensor_parameters', {
          'device_id': deviceId,
          'parameter_key': param['key'],
          'label': param['label'],
          'unit': param['unit'],
          'profile': param['profile'],
          'config_version': 'demo-v1',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // Seed 25 deterministic samples per parameter (from t0-24h to t0, step 1h)
      for (var step = 24; step >= 0; step--) {
        final sampleTime = now.subtract(Duration(hours: step));
        final variation = (((step + unitId * 3) % 7) - 3) * 0.15;
        final subTemp = substrateTemp + variation;
        final subMoist = substrateMoist + (((step + unitId) % 5) - 2) * 0.8;
        final ambTemp = 29.0 + (((step + unitId * 2) % 5) - 2) * 0.2;
        final ambHum = 65.0 + (((step + unitId) % 7) - 3) * 0.5;

        final parameterValues = {
          'ambientTemperature': ambTemp,
          'ambientHumidity': ambHum,
          'substrateTemperature': subTemp,
          'substrateMoisture': subMoist,
        };

        for (final entry in parameterValues.entries) {
          final sampleId = 'seed-$unitId-${entry.key}-$step';
          await db.insert('telemetry_measurements', {
            'unit_id': unitId,
            'device_id': deviceId,
            'parameter_key': entry.key,
            'value': entry.value,
            'measured_at': sampleTime.toIso8601String(),
            'received_at': sampleTime.toIso8601String(),
            'quality': 'valid',
            'source': 'simulated',
            'config_version': 'demo-v1',
            'sample_id': sampleId,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        // Also insert legacy readings record for backwards compatibility
        await db.insert('readings', {
          'unit_id': unitId,
          'temperature': subTemp,
          'humidity': subMoist,
          'medium': medium,
          'recorded_at': sampleTime.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    const config = DemoConfiguration();
    await db.insert('demo_configurations', {
      'version': config.version,
      'payload': config.toJson(),
      'created_at': now.toIso8601String(),
      'provenance': 'seeded-demo-v1',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await _seedPartners(db);
    await _seedListings(db, now);
    await _seedPitchRequests(db, now);
    await _seedSettings(db);

    await db.insert('settings', {
      'key': 'seed_version',
      'value': '6',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _seedPartners(DatabaseExecutor db) async {
    for (final partner in const [
      [1, 'Pasar Organik Jimbaran', 'supplier', 'Badung'],
      [3, 'Unit BSF Taman Sari', 'operator', 'Badung'],
      [4, 'Ternak Sejahtera Bali', 'buyer', 'Tabanan'],
    ]) {
      await db.insert('partners', {
        'id': partner[0],
        'name': partner[1],
        'role': partner[2],
        'region': partner[3],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> _seedSettings(DatabaseExecutor db) async {
    for (final entry in const {
      'active_role': 'operator',
      'notifications_enabled': 'false',
      'demo_scenario': 'normal',
      'simulator_paused': 'false',
      'selected_unit_id': '1',
      'onboarding_complete': 'false',
      'service_status': 'trial',
      'service_started_at': '',
      'service_ends_at': '',
      'session_generation': '1',
      'seed_version': '6',
    }.entries) {
      await db.insert('settings', {
        'key': entry.key,
        'value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> _seedNewSettings(DatabaseExecutor db) async {
    for (final entry in const {
      'selected_unit_id': '1',
      'onboarding_complete': 'false',
      'service_status': 'trial',
      'service_started_at': '',
      'service_ends_at': '',
      'session_generation': '1',
      'seed_version': '6',
    }.entries) {
      await db.insert('settings', {
        'key': entry.key,
        'value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> _seedListings(DatabaseExecutor db, DateTime now) async {
    final values = [
      [
        1,
        'supplier',
        'Pasar Organik Jimbaran',
        'wasteOffer',
        'Sisa sayur',
        500.0,
        'Badung',
        'Fixture demo untuk latihan penerimaan sebagian.',
      ],
      [
        1,
        'supplier',
        'Pasar Organik Jimbaran',
        'wasteOffer',
        'Limbah sayur completed',
        120.0,
        'Badung',
        'Transaksi selesai untuk agregasi demo.',
      ],
      [
        3,
        'operator',
        'Unit BSF Taman Sari',
        'outputOffer',
        'Larva BSF',
        20.0,
        'Badung',
        'Transaksi selesai untuk agregasi demo.',
      ],
      [
        3,
        'operator',
        'Unit BSF Taman Sari',
        'outputOffer',
        'Kasgot',
        40.0,
        'Badung',
        'Transaksi selesai untuk agregasi demo.',
      ],
    ];
    for (var index = 0; index < values.length; index++) {
      final item = values[index];
      await db.insert('listings', {
        'id': 101 + index,
        'owner_id': item[0],
        'owner_role': item[1],
        'owner_name': item[2],
        'kind': item[3],
        'material': item[4],
        'quantity_kg': item[5],
        'available_date': now.add(const Duration(days: 2)).toIso8601String(),
        'region': item[6],
        'note': item[7],
        'is_active': 1,
        'created_at': now.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> _seedPitchRequests(
    DatabaseExecutor db,
    DateTime now,
  ) async {
    final requests = [
      {
        'id': 1001,
        'listing_id': 101,
        'sender_id': 3,
        'receiver_id': 1,
        'completion_id': 3,
        'sender_role': 'operator',
        'receiver_role': 'supplier',
        'sender_name': 'Unit BSF Taman Sari',
        'receiver_name': 'Pasar Organik Jimbaran',
        'summary': 'Penawaran limbah: Sisa sayur',
        'quantity_kg': 500.0,
        'initial_quantity_kg': 500.0,
        'accepted_quantity_kg': null,
        'note': 'Fixture latihan penerimaan sebagian.',
        'status': 'pending',
      },
      {
        'id': 1002,
        'listing_id': 102,
        'sender_id': 3,
        'receiver_id': 1,
        'completion_id': 3,
        'sender_role': 'operator',
        'receiver_role': 'supplier',
        'sender_name': 'Unit BSF Taman Sari',
        'receiver_name': 'Pasar Organik Jimbaran',
        'summary': 'Penawaran limbah: Limbah sayur completed',
        'quantity_kg': 120.0,
        'initial_quantity_kg': 120.0,
        'accepted_quantity_kg': 120.0,
        'note': 'Fixture transaksi selesai.',
        'status': 'completed',
      },
      {
        'id': 1003,
        'listing_id': 103,
        'sender_id': 4,
        'receiver_id': 3,
        'completion_id': 4,
        'sender_role': 'buyer',
        'receiver_role': 'operator',
        'sender_name': 'Ternak Sejahtera Bali',
        'receiver_name': 'Unit BSF Taman Sari',
        'summary': 'Penawaran hasil: Larva BSF',
        'quantity_kg': 20.0,
        'initial_quantity_kg': 20.0,
        'accepted_quantity_kg': 20.0,
        'note': 'Fixture transaksi selesai.',
        'status': 'completed',
      },
      {
        'id': 1004,
        'listing_id': 104,
        'sender_id': 4,
        'receiver_id': 3,
        'completion_id': 4,
        'sender_role': 'buyer',
        'receiver_role': 'operator',
        'sender_name': 'Ternak Sejahtera Bali',
        'receiver_name': 'Unit BSF Taman Sari',
        'summary': 'Penawaran hasil: Kasgot',
        'quantity_kg': 40.0,
        'initial_quantity_kg': 40.0,
        'accepted_quantity_kg': 40.0,
        'note': 'Fixture transaksi selesai.',
        'status': 'completed',
      },
    ];
    for (final request in requests) {
      await db.insert('requests', {
        ...request,
        'history_limited': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('request_history', {
        'id': 2000 + (request['id']! as int),
        'request_id': request['id'],
        'actor_id': request['status'] == 'completed'
            ? request['completion_id']
            : request['sender_id'],
        'actor_name': request['status'] == 'completed'
            ? request['completion_id'] == request['sender_id']
                  ? request['sender_name']
                  : request['receiver_name']
            : request['sender_name'],
        'status': request['status'],
        'note': 'Fixture simulasi lokal.',
        'created_at': now.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> initialize({bool forceReseed = false}) async {
    final seedVer = await getSetting('seed_version');
    if (!forceReseed && seedVer == '6') {
      return;
    }
    await database.transaction((txn) async {
      await _seed(txn);
    });
  }

  Future<void> reset() async {
    await database.transaction((txn) async {
      final generationRows = await txn.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['session_generation'],
        limit: 1,
      );
      final previousGeneration = generationRows.isEmpty
          ? 1
          : int.tryParse(generationRows.first['value'] as String? ?? '') ?? 1;
      for (final table in [
        'telemetry_measurements',
        'sensor_parameters',
        'devices',
        'demo_configurations',
        'request_history',
        'app_notifications',
        'condition_events',
        'requests',
        'listings',
        'insight_actions',
        'insights',
        'readings',
        'units',
        'partners',
        'settings',
      ]) {
        await txn.delete(table);
      }
      await _seed(txn);
      await txn.insert('settings', {
        'key': 'session_generation',
        'value': '${previousGeneration + 1}',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<String?> getSetting(String key) async {
    final rows = await database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    await database.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
