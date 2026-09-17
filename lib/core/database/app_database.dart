import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.database);
  final Database database;

  static Future<AppDatabase> open() async {
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, 'biocycle_demo.db'),
      version: 2,
      onCreate: (db, _) async {
        await _createSchema(db);
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await _createSettingsTable(db);
          await _seedSettings(db);
        }
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
    await db.execute('''CREATE TABLE partners(
      id INTEGER PRIMARY KEY, name TEXT NOT NULL, role TEXT NOT NULL,
      region TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE listings(
      id INTEGER PRIMARY KEY AUTOINCREMENT, owner_role TEXT NOT NULL,
      owner_name TEXT NOT NULL, kind TEXT NOT NULL, material TEXT NOT NULL,
      quantity_kg REAL NOT NULL, available_date TEXT NOT NULL,
      region TEXT NOT NULL, note TEXT NOT NULL, is_active INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE requests(
      id INTEGER PRIMARY KEY AUTOINCREMENT, listing_id INTEGER NOT NULL UNIQUE,
      sender_role TEXT NOT NULL, receiver_role TEXT NOT NULL,
      completion_role TEXT NOT NULL,
      sender_name TEXT NOT NULL, receiver_name TEXT NOT NULL,
      summary TEXT NOT NULL, quantity_kg REAL NOT NULL, status TEXT NOT NULL,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    await _createSettingsTable(db);
  }

  static Future<void> _createSettingsTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE settings(
      key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
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
        final timestamp = now.subtract(Duration(hours: index));
        await db.insert('readings', {
          'unit_id': unit[0],
          'temperature': (unit[3] as double) + ((index % 5) - 2) * 0.25,
          'humidity': (unit[4] as double) + ((index % 4) - 1) * 0.8,
          'medium': unit[5],
          'recorded_at': timestamp.toIso8601String(),
        });
      }
    }
    final partners = [
      [1, 'Pasar Organik Jimbaran', 'supplier', 'Badung'],
      [2, 'Hotel Pesisir Bali', 'supplier', 'Denpasar'],
      [3, 'Unit BSF Taman Sari', 'operator', 'Badung'],
      [4, 'Ternak Sejahtera Bali', 'buyer', 'Tabanan'],
      [5, 'Kebun Subur Bersama', 'buyer', 'Gianyar'],
    ];
    for (final partner in partners) {
      await db.insert('partners', {
        'id': partner[0],
        'name': partner[1],
        'role': partner[2],
        'region': partner[3],
      });
    }
    await _seedListings(db, now);
    await _seedSettings(db);
  }

  static Future<void> _seedSettings(DatabaseExecutor db) async {
    await db.insert('settings', {
      'key': 'active_role',
      'value': 'operator',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('settings', {
      'key': 'notifications_enabled',
      'value': 'false',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> _seedListings(DatabaseExecutor db, DateTime now) async {
    final values = [
      [
        'supplier',
        'Pasar Organik Jimbaran',
        'wasteOffer',
        'Sisa sayur',
        120.0,
        'Badung',
        'Tersortir, pengambilan pagi.',
      ],
      [
        'supplier',
        'Hotel Pesisir Bali',
        'wasteOffer',
        'Sisa dapur nabati',
        80.0,
        'Denpasar',
        'Tidak tercampur minyak.',
      ],
      [
        'operator',
        'Unit BSF Taman Sari',
        'outputOffer',
        'Larva BSF',
        45.0,
        'Badung',
        'Siap untuk pakan ternak.',
      ],
      [
        'buyer',
        'Kebun Subur Bersama',
        'outputNeed',
        'Frass',
        60.0,
        'Gianyar',
        'Kebutuhan pupuk kebun.',
      ],
    ];
    for (final item in values) {
      await db.insert('listings', {
        'owner_role': item[0],
        'owner_name': item[1],
        'kind': item[2],
        'material': item[3],
        'quantity_kg': item[4],
        'available_date': now.add(const Duration(days: 2)).toIso8601String(),
        'region': item[5],
        'note': item[6],
        'is_active': 1,
      });
    }
  }

  Future<void> reset() async {
    await database.transaction((txn) async {
      for (final table in [
        'requests',
        'listings',
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
