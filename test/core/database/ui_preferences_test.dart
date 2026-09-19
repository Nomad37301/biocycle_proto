import 'dart:io';

import 'package:biocycle_proto/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Mode Terik, role, dan coach mark bertahan setelah restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'biocycle_ui_pref_',
    );
    final path = p.join(directory.path, 'preferences.db');
    var database = await AppDatabase.open(dbPath: path);
    await database.setSetting('mode_terik', 'true');
    await database.setSetting('active_role', 'buyer');
    await database.setSetting('coach_mark_buyer_dismissed', 'true');
    await database.database.close();

    database = await AppDatabase.open(dbPath: path);
    expect(await database.getSetting('mode_terik'), 'true');
    expect(await database.getSetting('active_role'), 'buyer');
    expect(await database.getSetting('coach_mark_buyer_dismissed'), 'true');
    await database.database.close();
    await directory.delete(recursive: true);
  });

  test(
    'reset menaikkan session generation dan mengembalikan onboarding',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'biocycle_reset_',
      );
      final path = p.join(directory.path, 'reset.db');
      final database = await AppDatabase.open(dbPath: path);
      final before = int.parse(
        (await database.getSetting('session_generation'))!,
      );
      await database.setSetting('onboarding_complete', 'true');

      await database.reset();

      expect(
        int.parse((await database.getSetting('session_generation'))!),
        before + 1,
      );
      expect(await database.getSetting('onboarding_complete'), 'false');
      await database.database.close();
      await directory.delete(recursive: true);
    },
  );
}
