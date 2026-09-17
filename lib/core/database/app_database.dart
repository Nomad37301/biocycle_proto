import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.database);
  final Database database;

  static Future<AppDatabase> open() async {
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, 'biocycle_demo.db'),
      version: 3,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await _createSchema(db);
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await _createSettingsTable(db);
          await _seedSettings(db);
        }
        if (oldVersion < 3) await _migrateToV3(db);
      },
    );
    return AppDatabase._(database);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''CREATE TABLE units(
      id INTEGER PRIMARY KEY, name TEXT NOT NULL, kit_code TEXT NOT NULL,
      temperature REAL NOT NULL, humidity REAL NOT NULL, medium TEXT NOT NULL,
      is_connected INTEGER NOT NULL, updated_at TEXT NOT NULL)''');
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
    await db.execute('''CREATE TABLE insight_actions(
      id INTEGER PRIMARY KEY AUTOINCREMENT, insight_id INTEGER NOT NULL,
      completed_steps TEXT NOT NULL, note TEXT NOT NULL, created_at TEXT NOT NULL,
      FOREIGN KEY(insight_id) REFERENCES insights(id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE partners(
      id INTEGER PRIMARY KEY, name TEXT NOT NULL, role TEXT NOT NULL,
      region TEXT NOT NULL)''');
    await _createPartnerTables(db);
    await _createSettingsTable(db);
  }

  static Future<void> _createPartnerTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE listings(
      id INTEGER PRIMARY KEY AUTOINCREMENT, owner_id INTEGER NOT NULL,
      owner_role TEXT NOT NULL, owner_name TEXT NOT NULL, kind TEXT NOT NULL,
      material TEXT NOT NULL, quantity_kg REAL NOT NULL,
      available_date TEXT NOT NULL, region TEXT NOT NULL, note TEXT NOT NULL,
      is_active INTEGER NOT NULL)''');
    await db.execute(
      '''CREATE TABLE requests(
      id INTEGER PRIMARY KEY AUTOINCREMENT, listing_id INTEGER NOT NULL,
      sender_id INTEGER NOT NULL, receiver_id INTEGER NOT NULL,
      completion_id INTEGER NOT NULL, sender_role TEXT NOT NULL,
      receiver_role TEXT NOT NULL, sender_name TEXT NOT NULL,
      receiver_name TEXT NOT NULL, summary TEXT NOT NULL,
      quantity_kg REAL NOT NULL, note TEXT NOT NULL DEFAULT '',
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

  static Future<void> _seed(DatabaseExecutor db) async {
    final now = DateTime.now();
    final units = [
      [1, 'Unit Demo Utama', 'BCK-001', 32.4, 65.0, 'Stabil'],
      [2, 'Unit Demo Pembesaran', 'BCK-002', 33.1, 72.0, 'Cukup lembap'],
      [3, 'Unit Demo Panen', 'BCK-003', 31.8, 62.0, 'Stabil'],
    ];
    for (final unit in units) {
      await db.insert('units', {
        'id': unit[0],
        'name': unit[1],
        'kit_code': unit[2],
        'temperature': unit[3],
        'humidity': unit[4],
        'medium': unit[5],
        'is_connected': 1,
        'updated_at': now.toIso8601String(),
      });
      for (var index = 23; index >= 0; index--) {
        await db.insert('readings', {
          'unit_id': unit[0],
          'temperature': (unit[3] as double) + ((index % 5) - 2) * 0.25,
          'humidity': (unit[4] as double) + ((index % 4) - 1) * 0.8,
          'medium': unit[5],
          'recorded_at': now.subtract(Duration(hours: index)).toIso8601String(),
        });
      }
    }
    await _seedPartners(db);
    await _seedListings(db, now);
    await _seedSettings(db);
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
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _seedSettings(DatabaseExecutor db) async {
    for (final entry in const {
      'active_role': 'operator',
      'notifications_enabled': 'false',
      'demo_scenario': 'normal',
      'simulator_paused': 'false',
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
        120.0,
        'Badung',
        'Tersortir, pengambilan pagi.',
      ],
      [
        1,
        'supplier',
        'Pasar Organik Jimbaran',
        'wasteOffer',
        'Sisa dapur nabati',
        80.0,
        'Badung',
        'Tidak tercampur minyak.',
      ],
      [
        3,
        'operator',
        'Unit BSF Taman Sari',
        'outputOffer',
        'Larva BSF',
        45.0,
        'Badung',
        'Siap untuk pakan ternak.',
      ],
      [
        4,
        'buyer',
        'Ternak Sejahtera Bali',
        'outputNeed',
        'Frass',
        60.0,
        'Tabanan',
        'Kebutuhan pupuk ternak.',
      ],
    ];
    for (final item in values) {
      await db.insert('listings', {
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
      });
    }
  }

  Future<void> reset() async {
    await database.transaction((txn) async {
      for (final table in [
        'request_history',
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
